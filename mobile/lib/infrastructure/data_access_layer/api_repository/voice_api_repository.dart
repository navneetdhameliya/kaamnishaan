import '../../models/api_models.g.dart';
import '../api_providers/voice_api_provider.dart';
import '../networks/api_result.dart';

abstract class IVoiceApiRepository {
  Future<ApiResult<VoiceNoteListModel>> notes(String jobId);
  Future<ApiResult<VoiceNoteOutModel>> note(String id);

  /// Confirms an audio upload; writing it out starts on the server. [clientUuid] makes a retry safe.
  Future<ApiResult<VoiceNoteOutModel>> addVoice({
    required String jobId,
    required String uploadId,
    required double durationS,
    required DateTime recordedAt,
    required String clientUuid,
    String? languageHint,
  });

  /// A typed note, when the microphone is off (D-27).
  Future<ApiResult<VoiceNoteOutModel>> addTyped({required String jobId, required String text, required String clientUuid});

  /// The technician's own corrected text (M29).
  Future<ApiResult<VoiceNoteOutModel>> edit(String id, String text);

  Future<ApiResult<VoiceNoteOutModel>> retranscribe(String id, {String? languageHint});
  Future<ApiResult<void>> delete(String id);

  /// Speak instead of typing: a short recording (an audio upload) becomes words. Nothing is kept.
  Future<ApiResult<DictationOutModel>> dictate(String uploadId, {String? languageHint});
}

class VoiceApiRepository implements IVoiceApiRepository {
  VoiceApiRepository({required this.provider});

  final IVoiceApiProvider provider;

  Map<String, dynamic> _map(dynamic json) => Map<String, dynamic>.from(json as Map);

  @override
  Future<ApiResult<VoiceNoteListModel>> notes(String jobId) =>
      guard(() async => VoiceNoteListModel.fromJson(_map(await provider.getNotes(jobId))));

  @override
  Future<ApiResult<VoiceNoteOutModel>> note(String id) =>
      guard(() async => VoiceNoteOutModel.fromJson(_map(await provider.getNote(id))));

  @override
  Future<ApiResult<VoiceNoteOutModel>> addVoice({
    required String jobId,
    required String uploadId,
    required double durationS,
    required DateTime recordedAt,
    required String clientUuid,
    String? languageHint,
  }) =>
      guard(() async => VoiceNoteOutModel.fromJson(_map(await provider.postVoiceNote(jobId, {
            'upload_id': uploadId,
            'duration_s': durationS,
            'recorded_at': recordedAt.toUtc().toIso8601String(),
            'client_uuid': clientUuid,
            'language_hint': ?languageHint,
          }))));

  @override
  Future<ApiResult<VoiceNoteOutModel>> addTyped({required String jobId, required String text, required String clientUuid}) =>
      guard(() async => VoiceNoteOutModel.fromJson(
            _map(await provider.postTypedNote(jobId, {'text': text, 'client_uuid': clientUuid})),
          ));

  @override
  Future<ApiResult<VoiceNoteOutModel>> edit(String id, String text) =>
      guard(() async => VoiceNoteOutModel.fromJson(_map(await provider.patchNote(id, {'transcript_edited': text}))));

  @override
  Future<ApiResult<VoiceNoteOutModel>> retranscribe(String id, {String? languageHint}) => guard(
        () async => VoiceNoteOutModel.fromJson(
          _map(await provider.postRetranscribe(id, {'language_hint': ?languageHint})),
        ),
      );

  @override
  Future<ApiResult<void>> delete(String id) => guard(() async {
        await provider.deleteNote(id);
      });

  @override
  Future<ApiResult<DictationOutModel>> dictate(String uploadId, {String? languageHint}) => guard(
        () async => DictationOutModel.fromJson(
          _map(await provider.postDictation({'upload_id': uploadId, 'language_hint': ?languageHint})),
        ),
      );
}
