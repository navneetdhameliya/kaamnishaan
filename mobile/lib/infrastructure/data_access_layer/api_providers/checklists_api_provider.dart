import '../../commons/constants/apis/api_constant.dart';
import '../networks/api_client.dart';

/// A job's checklists (M24) and their questions and answers (M25).
abstract class IChecklistsApiProvider {
  Future<dynamic> getJobChecklists(String jobId);
  Future<dynamic> getSubmission(String id);
  Future<dynamic> putAnswer(String id, String questionId, Map<String, dynamic> body);
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
}
