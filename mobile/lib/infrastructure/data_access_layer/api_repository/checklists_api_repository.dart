import '../../models/api_models.g.dart';
import '../api_providers/checklists_api_provider.dart';
import '../networks/api_result.dart';

abstract class IChecklistsApiRepository {
  Future<ApiResult<JobChecklistListModel>> forJob(String jobId);
  Future<ApiResult<SubmissionOutModel>> submission(String id);

  /// [value]: "yes"/"no", "pass"/"fail", a number, a choice key or text. [clientUuid] makes a retry safe.
  Future<ApiResult<SubmissionOutModel>> answer({
    required String checklistId,
    required String questionId,
    required String clientUuid,
    Object? value,
    String? photoId,
    String? signatureUploadId,
  });
}

class ChecklistsApiRepository implements IChecklistsApiRepository {
  ChecklistsApiRepository({required this.provider});

  final IChecklistsApiProvider provider;

  Map<String, dynamic> _map(dynamic json) => Map<String, dynamic>.from(json as Map);

  @override
  Future<ApiResult<JobChecklistListModel>> forJob(String jobId) =>
      guard(() async => JobChecklistListModel.fromJson(_map(await provider.getJobChecklists(jobId))));

  @override
  Future<ApiResult<SubmissionOutModel>> submission(String id) =>
      guard(() async => SubmissionOutModel.fromJson(_map(await provider.getSubmission(id))));

  @override
  Future<ApiResult<SubmissionOutModel>> answer({
    required String checklistId,
    required String questionId,
    required String clientUuid,
    Object? value,
    String? photoId,
    String? signatureUploadId,
  }) =>
      guard(() async => SubmissionOutModel.fromJson(_map(await provider.putAnswer(checklistId, questionId, {
            'value': ?value,
            'photo_id': ?photoId,
            'signature_upload_id': ?signatureUploadId,
            'client_uuid': clientUuid,
          }))));
}
