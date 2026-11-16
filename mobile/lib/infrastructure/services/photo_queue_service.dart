import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:get/get.dart';
import 'package:uuid/uuid.dart';

import '../data_access_layer/api_repository/files_api_repository.dart';
import '../data_access_layer/api_repository/jobs_api_repository.dart';
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

/// Offline-first photos (D-56): every photo is first saved in the app's own folder with a small list
/// (queue.json), then sent one by one when there is internet. Nothing is lost if the app closes or the
/// phone has no signal; the list is read again at start and sending resumes.
class PhotoQueueService extends GetxService {
  PhotoQueueService({
    required this.files,
    required this.jobs,
    required this.folder,
    this.online,
    this.retryEvery = const Duration(minutes: 2),
    this.startDelay,
  });

  final IFilesApiRepository files;
  final IJobsApiRepository jobs;
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

  /// Goes up each time a photo reaches the server, so screens can reload.
  final RxInt sent = 0.obs;

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
        final raw = jsonDecode(await f.readAsString()) as List;
        items.assignAll(raw.map((e) => PendingPhoto.fromJson(Map<String, dynamic>.from(e as Map))));
        for (final p in items) {
          if (p.state == PendingState.sending) p.state = PendingState.waiting; // the app closed mid-send
        }
        items.removeWhere((p) => !File(p.path).existsSync());
      }
    } catch (e) {
      AppLogger.error('Saved photo list could not be read', error: e);
    }
    _onlineSub = online?.listen((up) {
      if (up) process();
    });
    _timer = Timer.periodic(retryEvery, (_) => process());
    if (startDelay != null && items.isNotEmpty) Timer(startDelay!, process);
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

  /// Sends waiting photos one at a time. Calls while sending wait for the same run.
  Future<void> process() => _running ??= _send().whenComplete(() => _running = null);

  Future<void> _send() async {
    for (final p in items.where((p) => p.state == PendingState.waiting).toList()) {
      if (!items.contains(p)) continue;
      p.state = PendingState.sending;
      items.refresh();
      final error = await _sendOne(p);
      if (error == null) {
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
        return; // no internet or not logged in: try again later
      }
      p
        ..tries += 1
        ..error = error.message;
      if (p.tries >= maxTries) p.state = PendingState.failed;
      items.refresh();
      await _save();
    }
  }

  bool _waitForNetwork(ApiException e) =>
      e.isNetwork || e.statusCode == 401 || e.code == 'session_expired' || (e.statusCode ?? 0) >= 500;

  Future<ApiException?> _sendOne(PendingPhoto p) async {
    final file = File(p.path);
    if (!file.existsSync()) return const ApiException(code: 'file_missing', message: 'The photo file is missing.');
    final upload = await files.upload(kind: UploadKind.photo, bytes: await file.readAsBytes(), contentType: 'image/jpeg');
    final uploadId = upload.dataOrNull;
    if (uploadId == null) return upload.errorOrNull;
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
    return added.errorOrNull;
  }

  Future<void> _save() async {
    try {
      final f = await _list;
      final tmp = File('${f.path}.tmp');
      await tmp.writeAsString(jsonEncode(items.map((p) => p.toJson()).toList()), flush: true);
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
