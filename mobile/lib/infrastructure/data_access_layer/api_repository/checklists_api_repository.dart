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

  /// The company's checklists to add to a new job (M16).
  Future<ApiResult<TemplateListModel>> templates();

  /// M26: one checklist with its questions (and every language of each).
  Future<ApiResult<TemplateOutModel>> template(String id);

  /// M26 "New checklist": starts as a draft.
  Future<ApiResult<TemplateOutModel>> create(String name);

  /// Rename, or [status] published / archived.
  Future<ApiResult<TemplateOutModel>> update(String id, {String? name, String? status});

  /// A KaamNishaan checklist copied so the company can change it.
  Future<ApiResult<TemplateOutModel>> copy(String id);

  Future<ApiResult<TemplateOutModel>> addQuestion(String id, QuestionInModel body);

  Future<ApiResult<TemplateOutModel>> updateQuestion(String id, String questionId, QuestionPatchModel body);

  Future<ApiResult<void>> deleteQuestion(String id, String questionId);
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

  @override
  Future<ApiResult<TemplateListModel>> templates() =>
      guard(() async => TemplateListModel.fromJson(_map(await provider.getTemplates())));

  Map<String, dynamic> _clean(Map<String, dynamic> m) => m..removeWhere((_, v) => v == null || v == false);

  @override
  Future<ApiResult<TemplateOutModel>> template(String id) =>
      guard(() async => TemplateOutModel.fromJson(_map(await provider.getTemplate(id))));

  @override
  Future<ApiResult<TemplateOutModel>> create(String name) =>
      guard(() async => TemplateOutModel.fromJson(_map(await provider.postTemplate({'name': name}))));

  @override
  Future<ApiResult<TemplateOutModel>> update(String id, {String? name, String? status}) => guard(
        () async => TemplateOutModel.fromJson(_map(await provider.patchTemplate(id, {'name': ?name, 'status': ?status}))),
      );

  @override
  Future<ApiResult<TemplateOutModel>> copy(String id) =>
      guard(() async => TemplateOutModel.fromJson(_map(await provider.postCopy(id))));

  @override
  Future<ApiResult<TemplateOutModel>> addQuestion(String id, QuestionInModel body) => guard(
        () async => TemplateOutModel.fromJson(_map(await provider.postQuestion(id, _keep(body.toJson())))),
      );

  @override
  Future<ApiResult<TemplateOutModel>> updateQuestion(String id, String questionId, QuestionPatchModel body) => guard(
        () async => TemplateOutModel.fromJson(_map(await provider.patchQuestion(id, questionId, _clean(body.toJson())))),
      );

  @override
  Future<ApiResult<void>> deleteQuestion(String id, String questionId) => guard(() async {
        await provider.deleteQuestion(id, questionId);
      });

  /// Leave out what isn't set (keeps `required: false`).
  Map<String, dynamic> _keep(Map<String, dynamic> m) => m..removeWhere((_, v) => v == null);
}
