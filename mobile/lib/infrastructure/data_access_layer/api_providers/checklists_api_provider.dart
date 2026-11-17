import '../../commons/constants/apis/api_constant.dart';
import '../networks/api_client.dart';

/// A job's checklists (M24) and their questions and answers (M25), and the checklist builder (M26).
abstract class IChecklistsApiProvider {
  Future<dynamic> getJobChecklists(String jobId);
  Future<dynamic> getSubmission(String id);
  Future<dynamic> putAnswer(String id, String questionId, Map<String, dynamic> body);
  Future<dynamic> getTemplates();
  Future<dynamic> getTemplate(String id);
  Future<dynamic> postTemplate(Map<String, dynamic> body);
  Future<dynamic> patchTemplate(String id, Map<String, dynamic> body);
  Future<dynamic> postCopy(String id);
  Future<dynamic> postQuestion(String id, Map<String, dynamic> body);
  Future<dynamic> patchQuestion(String id, String questionId, Map<String, dynamic> body);
  Future<dynamic> deleteQuestion(String id, String questionId);
}

class ChecklistsApiProvider implements IChecklistsApiProvider {
  ChecklistsApiProvider(this._client);

  final ApiClient _client;

  @override
  Future<dynamic> getJobChecklists(String jobId) => _client.get(APIConstant.jobChecklistsAPIEP(jobId));

  @override
  Future<dynamic> getSubmission(String id) => _client.get(APIConstant.submissionAPIEP(id));

  @override
  Future<dynamic> putAnswer(String id, String questionId, Map<String, dynamic> body) =>
      _client.put(APIConstant.answerAPIEP(id, questionId), body: body);

  @override
  Future<dynamic> getTemplates() => _client.get(APIConstant.checklistTemplatesAPIEP);

  @override
  Future<dynamic> getTemplate(String id) => _client.get(APIConstant.checklistTemplateAPIEP(id));

  @override
  Future<dynamic> postTemplate(Map<String, dynamic> body) => _client.post(APIConstant.checklistTemplatesAPIEP, body: body);

  @override
  Future<dynamic> patchTemplate(String id, Map<String, dynamic> body) =>
      _client.patch(APIConstant.checklistTemplateAPIEP(id), body: body);

  @override
  Future<dynamic> postCopy(String id) => _client.post(APIConstant.copyTemplateAPIEP(id));

  @override
  Future<dynamic> postQuestion(String id, Map<String, dynamic> body) =>
      _client.post(APIConstant.templateQuestionsAPIEP(id), body: body);

  @override
  Future<dynamic> patchQuestion(String id, String questionId, Map<String, dynamic> body) =>
      _client.patch(APIConstant.templateQuestionAPIEP(id, questionId), body: body);

  @override
  Future<dynamic> deleteQuestion(String id, String questionId) =>
      _client.delete(APIConstant.templateQuestionAPIEP(id, questionId));
}
