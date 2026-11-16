import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:get/get.dart';
import 'package:uuid/uuid.dart';

import '../data_access_layer/api_repository/checklists_api_repository.dart';
import '../data_access_layer/api_repository/files_api_repository.dart';
import '../data_access_layer/api_repository/jobs_api_repository.dart';
import '../data_access_layer/api_repository/voice_api_repository.dart';
import '../data_access_layer/networks/api_exception.dart';
import '../shared/app_logger.dart';

enum PendingState { waiting, sending, failed }

/// A proof photo kept on the phone until the server has it.
class PendingPhoto {
  PendingPhoto({
    required this.id,
    required this.jobId,
    required this.stage,
    required this.takenAt,
    required this.path,
    this.lat,
    this.lng,
    this.shotSlot,
    this.state = PendingState.waiting,
    this.tries = 0,
    this.error,
  });

  factory PendingPhoto.fromJson(Map<String, dynamic> j) => PendingPhoto(
        id: j['id'] as String,
        jobId: j['job_id'] as String,
        stage: j['stage'] as String,
        takenAt: DateTime.parse(j['taken_at'] as String),
        path: j['path'] as String,
        lat: (j['lat'] as num?)?.toDouble(),
        lng: (j['lng'] as num?)?.toDouble(),
        shotSlot: j['shot_slot'] as String?,
        state: PendingState.values.byName(j['state'] as String? ?? 'waiting'),
        tries: (j['tries'] as num?)?.toInt() ?? 0,
        error: j['error'] as String?,
      );

  /// Also the client_uuid sent to the server, so a repeated send never makes two photos.
  final String id;
  final String jobId;
  final String stage;
  final DateTime takenAt;
  final String path;
  final double? lat;
  final double? lng;
  final String? shotSlot;
  PendingState state;
  int tries;
  String? error;

  Map<String, dynamic> toJson() => {
        'id': id,
        'job_id': jobId,
        'stage': stage,
        'taken_at': takenAt.toIso8601String(),
        'path': path,
        'lat': lat,
        'lng': lng,
        'shot_slot': shotSlot,
        'state': state.name,
        'tries': tries,
        'error': error,
      };
}

/// A checklist answer kept on the phone until the server has it (D-59). An answer that needs a photo
/// points at the waiting photo ([photoRef]) and is sent after it.
class PendingAnswer {
  PendingAnswer({
    required this.id,
    required this.jobId,
    required this.checklistId,
    required this.questionId,
    required this.answeredAt,
    this.value,
    this.photoRef,
    this.state = PendingState.waiting,
    this.tries = 0,
    this.error,
  });

  factory PendingAnswer.fromJson(Map<String, dynamic> j) => PendingAnswer(
        id: j['id'] as String,
        jobId: j['job_id'] as String,
        checklistId: j['checklist_id'] as String,
        questionId: j['question_id'] as String,
        answeredAt: DateTime.parse(j['answered_at'] as String),
        value: j['value'],
        photoRef: j['photo_ref'] as String?,
        state: PendingState.values.byName(j['state'] as String? ?? 'waiting'),
        tries: (j['tries'] as num?)?.toInt() ?? 0,
        error: j['error'] as String?,
      );

  final String id;
  final String jobId;
  final String checklistId;
  final String questionId;
  final DateTime answeredAt;
  final Object? value;
  final String? photoRef;
  PendingState state;
  int tries;
  String? error;

  Map<String, dynamic> toJson() => {
        'id': id,
        'job_id': jobId,
        'checklist_id': checklistId,
        'question_id': questionId,
        'answered_at': answeredAt.toIso8601String(),
        'value': value,
        'photo_ref': photoRef,
        'state': state.name,
        'tries': tries,
        'error': error,
      };
}

/// A voice note (audio file) or typed note kept on the phone until the server has it (D-61).
class PendingNote {
  PendingNote({
    required this.id,
    required this.jobId,
    required this.recordedAt,
    this.path,
    this.durationS,
    this.languageHint,
    this.text,
    this.state = PendingState.waiting,
    this.tries = 0,
    this.error,
  });

  factory PendingNote.fromJson(Map<String, dynamic> j) => PendingNote(
        id: j['id'] as String,
        jobId: j['job_id'] as String,
        recordedAt: DateTime.parse(j['recorded_at'] as String),
        path: j['path'] as String?,
        durationS: (j['duration_s'] as num?)?.toDouble(),
        languageHint: j['language_hint'] as String?,
        text: j['text'] as String?,
        state: PendingState.values.byName(j['state'] as String? ?? 'waiting'),
        tries: (j['tries'] as num?)?.toInt() ?? 0,
        error: j['error'] as String?,
      );

  /// Also the client_uuid sent to the server.
  final String id;
  final String jobId;
  final DateTime recordedAt;

  /// The recording on the phone; null for a typed note.
  final String? path;
  final double? durationS;
  final String? languageHint;

  /// A typed note's text.
  final String? text;
  PendingState state;
  int tries;
  String? error;

  bool get typed => path == null;

  Map<String, dynamic> toJson() => {
        'id': id,
        'job_id': jobId,
        'recorded_at': recordedAt.toIso8601String(),
        'path': path,
        'duration_s': durationS,
        'language_hint': languageHint,
        'text': text,
        'state': state.name,
        'tries': tries,
        'error': error,
      };
}

/// Offline-first photos (D-56): every photo is first saved in the app's own folder with a small list
/// (queue.json), then sent one by one when there is internet. Nothing is lost if the app closes or the
/// phone has no signal; the list is read again at start and sending resumes.
class PhotoQueueService extends GetxService {
  PhotoQueueService({
    required this.files,
    required this.jobs,
    this.checklists,
    this.voice,
    required this.folder,
    this.online,
    this.retryEvery = const Duration(minutes: 2),
    this.startDelay,
  });

  final IFilesApiRepository files;
  final IJobsApiRepository jobs;

  /// Sends checklist answers (D-59); without it only photos are sent.
  final IChecklistsApiRepository? checklists;

  /// Sends voice and typed notes (D-61); without it notes stay on the phone.
  final IVoiceApiRepository? voice;

  /// Where waiting photos are kept (the app's own documents folder).
  final Future<Directory> Function() folder;

  /// true when the phone gets internet back.
  final Stream<bool>? online;
  final Duration retryEvery;

  /// Sends what was left from last time, shortly after the app opens (after login is restored).
  final Duration? startDelay;

  /// After this many failed tries the photo is shown as "Not sent" (it stays on the phone).
  static const maxTries = 6;

  final RxList<PendingPhoto> items = <PendingPhoto>[].obs;

  /// Checklist answers waiting to be sent, in the order they were given.
  final RxList<PendingAnswer> answers = <PendingAnswer>[].obs;

  /// Waiting photo id → its id on the server, kept until the answers that need it are sent.
  final Map<String, String> _sentPhotos = {};

  /// Goes up each time an answer reaches the server.
  final RxInt answersSent = 0.obs;

  /// Goes up each time a photo reaches the server, so screens can reload.
  final RxInt sent = 0.obs;

  /// Voice and typed notes waiting to be sent, oldest first.
  final RxList<PendingNote> notes = <PendingNote>[].obs;

  /// Goes up each time a note reaches the server.
  final RxInt notesSent = 0.obs;

  Directory? _dir;
  StreamSubscription<bool>? _onlineSub;
  Timer? _timer;
  Future<void>? _running;

  Future<Directory> get dir async {
    final d = _dir ??= await folder();
    if (!d.existsSync()) d.createSync(recursive: true);
    return d;
  }

  Future<File> get _list async => File('${(await dir).path}/queue.json');

  Future<PhotoQueueService> init() async {
    try {
      final f = await _list;
      if (f.existsSync()) {
        final raw = jsonDecode(await f.readAsString());
        // version 1 was a plain list of photos
        final photos = raw is List ? raw : (raw as Map)['photos'] as List? ?? const [];
        items.assignAll(photos.map((e) => PendingPhoto.fromJson(Map<String, dynamic>.from(e as Map))));
        for (final p in items) {
          if (p.state == PendingState.sending) p.state = PendingState.waiting; // the app closed mid-send
        }
        items.removeWhere((p) => !File(p.path).existsSync());
        if (raw is Map) {
          answers.assignAll(
            (raw['answers'] as List? ?? const []).map((e) => PendingAnswer.fromJson(Map<String, dynamic>.from(e as Map))),
          );
          for (final a in answers) {
            if (a.state == PendingState.sending) a.state = PendingState.waiting;
          }
          _sentPhotos.addAll(Map<String, String>.from(raw['sent_photos'] as Map? ?? const {}));
          notes.assignAll(
            (raw['notes'] as List? ?? const []).map((e) => PendingNote.fromJson(Map<String, dynamic>.from(e as Map))),
          );
          for (final n in notes) {
            if (n.state == PendingState.sending) n.state = PendingState.waiting;
          }
          notes.removeWhere((n) => n.path != null && !File(n.path!).existsSync());
        }
      }
    } catch (e) {
      AppLogger.error('Saved photo list could not be read', error: e);
    }
    _onlineSub = online?.listen((up) {
      if (up) process();
    });
    _timer = Timer.periodic(retryEvery, (_) => process());
    if (startDelay != null && (items.isNotEmpty || answers.isNotEmpty || notes.isNotEmpty)) Timer(startDelay!, process);
    return this;
  }

  List<PendingPhoto> forJob(String jobId) => items.where((p) => p.jobId == jobId).toList();

  int countFor(String jobId, String stage) => items.where((p) => p.jobId == jobId && p.stage == stage).length;

  /// Keeps the photo at [sourcePath] (moved into the app's folder) and starts sending.
  Future<PendingPhoto> add({
    required String jobId,
    required String stage,
    required String sourcePath,
    DateTime? takenAt,
    double? lat,
    double? lng,
    String? shotSlot,
  }) async {
    final id = const Uuid().v4();
    final target = '${(await dir).path}/$id.jpg';
    final source = File(sourcePath);
    try {
      await source.rename(target);
    } on FileSystemException {
      await source.copy(target); // a different disk: copy, then remove the camera's file
      await source.delete();
    }
    final photo = PendingPhoto(
      id: id,
      jobId: jobId,
      stage: stage,
      takenAt: takenAt ?? DateTime.now(),
      path: target,
      lat: lat,
      lng: lng,
      shotSlot: shotSlot,
    );
    items.add(photo);
    await _save();
    unawaited(process());
    return photo;
  }

  /// Tries a "Not sent" photo again.
  Future<void> retry(String id) async {
    final p = items.firstWhereOrNull((p) => p.id == id);
    if (p == null) return;
    p
      ..state = PendingState.waiting
      ..tries = 0
      ..error = null;
    items.refresh();
    await _save();
    await process();
  }

  /// Keeps a checklist answer and starts sending. A newer answer to the same question replaces a waiting one.
  /// [photoRef] is the id of a waiting photo (from [add]) the answer needs.
  Future<PendingAnswer> addAnswer({
    required String jobId,
    required String checklistId,
    required String questionId,
    Object? value,
    String? photoRef,
  }) async {
    final old = answers.firstWhereOrNull(
      (a) => a.checklistId == checklistId && a.questionId == questionId && a.state != PendingState.sending,
    );
    final answer = PendingAnswer(
      id: const Uuid().v4(),
      jobId: jobId,
      checklistId: checklistId,
      questionId: questionId,
      answeredAt: DateTime.now(),
      value: value,
      photoRef: photoRef ?? old?.photoRef,
    );
    if (old != null) answers.remove(old);
    answers.add(answer);
    await _save();
    unawaited(process());
    return answer;
  }

  /// Answers not yet on the server for this checklist, by question id.
  Map<String, PendingAnswer> answersFor(String checklistId) => {
        for (final a in answers.where((a) => a.checklistId == checklistId)) a.questionId: a,
      };

  /// Keeps a recording (moved into the app's folder) and starts sending. The server writes it out.
  Future<PendingNote> addVoice({
    required String jobId,
    required String sourcePath,
    required double durationS,
    DateTime? recordedAt,
    String? languageHint,
  }) async {
    final id = const Uuid().v4();
    final target = '${(await dir).path}/$id.m4a';
    final source = File(sourcePath);
    try {
      await source.rename(target);
    } on FileSystemException {
      await source.copy(target);
      await source.delete();
    }
    return _keep(PendingNote(
      id: id,
      jobId: jobId,
      recordedAt: recordedAt ?? DateTime.now(),
      path: target,
      durationS: durationS,
      languageHint: languageHint,
    ));
  }

  /// Keeps a typed note (microphone off) and starts sending.
  Future<PendingNote> addTyped({required String jobId, required String text}) =>
      _keep(PendingNote(id: const Uuid().v4(), jobId: jobId, recordedAt: DateTime.now(), text: text));

  Future<PendingNote> _keep(PendingNote note) async {
    notes.add(note);
    await _save();
    unawaited(process());
    return note;
  }

  List<PendingNote> notesFor(String jobId) => notes.where((n) => n.jobId == jobId).toList();

  /// Tries a "Not sent" note again.
  Future<void> retryNote(String id) async {
    final n = notes.firstWhereOrNull((n) => n.id == id);
    if (n == null) return;
    n
      ..state = PendingState.waiting
      ..tries = 0
      ..error = null;
    notes.refresh();
    await _save();
    await process();
  }

  /// Removes a note that was never sent (and its recording).
  Future<void> removeNote(String id) async {
    final n = notes.firstWhereOrNull((n) => n.id == id && n.state != PendingState.sending);
    if (n == null) return;
    notes.remove(n);
    if (n.path != null) {
      try {
        await File(n.path!).delete();
      } catch (_) {}
    }
    await _save();
  }

  /// Sends waiting photos one at a time. Calls while sending wait for the same run.
  Future<void> process() => _running ??= _send().whenComplete(() => _running = null);

  /// Goes again while photos or answers added during the run are still waiting,
  /// so a photo taken while another one is sending is not left for the next retry.
  Future<void> _send() async {
    final tried = <String>{};
    bool fresh() =>
        items.any((p) => p.state == PendingState.waiting && !tried.contains(p.id)) ||
        answers.any((a) => a.state == PendingState.waiting && !tried.contains(a.id)) ||
        notes.any((n) => n.state == PendingState.waiting && !tried.contains(n.id));
    while (fresh()) {
      if (!await _sendPhotos(tried)) return;
      if (!await _sendNotes(tried)) return;
      if (!await _sendAnswers(tried)) return;
    }
  }

  /// false when sending stopped for lack of internet.
  Future<bool> _sendPhotos(Set<String> tried) async {
    for (final p in items.where((p) => p.state == PendingState.waiting && tried.add(p.id)).toList()) {
      if (!items.contains(p)) continue;
      p.state = PendingState.sending;
      items.refresh();
      final (error, serverId) = await _sendOne(p);
      if (error == null) {
        // kept even with no answer yet: the answer may be added a moment after the photo
        if (serverId != null) _sentPhotos[p.id] = serverId;
        items.remove(p);
        try {
          await File(p.path).delete();
        } catch (_) {}
        await _save();
        sent.value++;
        continue;
      }
      p.state = PendingState.waiting;
      if (_waitForNetwork(error)) {
        items.refresh();
        await _save();
        return false; // no internet or not logged in: try again later
      }
      p
        ..tries += 1
        ..error = error.message;
      if (p.tries >= maxTries) p.state = PendingState.failed;
      items.refresh();
      await _save();
    }
    return true;
  }

  /// false when sending stopped for lack of internet.
  Future<bool> _sendAnswers(Set<String> tried) async {
    final api = checklists;
    if (api == null) {
      tried.addAll(answers.map((a) => a.id));
      return true;
    }
    for (final a in answers.where((a) => a.state == PendingState.waiting && tried.add(a.id)).toList()) {
      if (!answers.contains(a)) continue;
      String? photoId;
      if (a.photoRef != null) {
        photoId = _sentPhotos[a.photoRef];
        if (photoId == null) continue; // its photo is not on the server yet
      }
      a.state = PendingState.sending;
      answers.refresh();
      final result = await api.answer(
        checklistId: a.checklistId,
        questionId: a.questionId,
        clientUuid: a.id,
        value: a.value,
        photoId: photoId,
      );
      final error = result.errorOrNull;
      if (error == null) {
        answers.remove(a);
        if (a.photoRef != null && !answers.any((x) => x.photoRef == a.photoRef)) _sentPhotos.remove(a.photoRef);
        await _save();
        answersSent.value++;
        continue;
      }
      a.state = PendingState.waiting;
      if (_waitForNetwork(error)) {
        answers.refresh();
        await _save();
        return false;
      }
      a
        ..tries += 1
        ..error = error.message;
      if (a.tries >= maxTries) a.state = PendingState.failed;
      answers.refresh();
      await _save();
    }
    return true;
  }

  /// false when sending stopped for lack of internet.
  Future<bool> _sendNotes(Set<String> tried) async {
    final api = voice;
    if (api == null) {
      tried.addAll(notes.map((n) => n.id));
      return true;
    }
    for (final n in notes.where((n) => n.state == PendingState.waiting && tried.add(n.id)).toList()) {
      if (!notes.contains(n)) continue;
      n.state = PendingState.sending;
      notes.refresh();
      final error = await _sendNote(api, n);
      if (error == null) {
        notes.remove(n);
        if (n.path != null) {
          try {
            await File(n.path!).delete();
          } catch (_) {}
        }
        await _save();
        notesSent.value++;
        continue;
      }
      n.state = PendingState.waiting;
      if (_waitForNetwork(error)) {
        notes.refresh();
        await _save();
        return false;
      }
      n
        ..tries += 1
        ..error = error.message;
      if (n.tries >= maxTries) n.state = PendingState.failed;
      notes.refresh();
      await _save();
    }
    return true;
  }

  Future<ApiException?> _sendNote(IVoiceApiRepository api, PendingNote n) async {
    if (n.typed) return (await api.addTyped(jobId: n.jobId, text: n.text ?? '', clientUuid: n.id)).errorOrNull;
    final file = File(n.path!);
    if (!file.existsSync()) return const ApiException(code: 'file_missing', message: 'The recording is missing.');
    final upload = await files.upload(kind: UploadKind.audio, bytes: await file.readAsBytes(), contentType: 'audio/mp4');
    final uploadId = upload.dataOrNull;
    if (uploadId == null) return upload.errorOrNull;
    final added = await api.addVoice(
      jobId: n.jobId,
      uploadId: uploadId,
      durationS: n.durationS ?? 0,
      recordedAt: n.recordedAt,
      clientUuid: n.id,
      languageHint: n.languageHint,
    );
    return added.errorOrNull;
  }

  bool _waitForNetwork(ApiException e) =>
      e.isNetwork || e.statusCode == 401 || e.code == 'session_expired' || (e.statusCode ?? 0) >= 500;

  /// (error, the photo's id on the server)
  Future<(ApiException?, String?)> _sendOne(PendingPhoto p) async {
    final file = File(p.path);
    if (!file.existsSync()) {
      return (const ApiException(code: 'file_missing', message: 'The photo file is missing.'), null);
    }
    final upload = await files.upload(kind: UploadKind.photo, bytes: await file.readAsBytes(), contentType: 'image/jpeg');
    final uploadId = upload.dataOrNull;
    if (uploadId == null) return (upload.errorOrNull, null);
    final added = await jobs.addPhoto(
      jobId: p.jobId,
      uploadId: uploadId,
      stage: p.stage,
      takenAt: p.takenAt,
      clientUuid: p.id,
      lat: p.lat,
      lng: p.lng,
      shotSlot: p.shotSlot,
    );
    return (added.errorOrNull, added.dataOrNull);
  }

  Future<void> _save() async {
    if (_sentPhotos.length > 100) {
      _sentPhotos.removeWhere((photo, _) => !answers.any((a) => a.photoRef == photo));
    }
    try {
      final f = await _list;
      final tmp = File('${f.path}.tmp');
      await tmp.writeAsString(
        jsonEncode({
          'version': 3,
          'photos': items.map((p) => p.toJson()).toList(),
          'answers': answers.map((a) => a.toJson()).toList(),
          'notes': notes.map((n) => n.toJson()).toList(),
          'sent_photos': _sentPhotos,
        }),
        flush: true,
      );
      await tmp.rename(f.path); // replace in one step, so a crash never leaves half a list
    } catch (e) {
      AppLogger.error('Saving the photo list failed', error: e);
    }
  }

  @override
  void onClose() {
    _onlineSub?.cancel();
    _timer?.cancel();
    super.onClose();
  }
}
