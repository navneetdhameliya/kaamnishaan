import '../../commons/constants/apis/api_constant.dart';
import '../networks/api_client.dart';

/// Jobs: the list (M14), one job (M15), starting it, and its proof steps (M19).
abstract class IJobsApiProvider {
  Future<dynamic> getJobs(Map<String, dynamic> query);
  Future<dynamic> getJob(String id);
  Future<dynamic> postStart(String id, Map<String, dynamic> body);
  Future<dynamic> getProof(String id);
  Future<dynamic> getEvidence(String id);
  Future<dynamic> postEvidence(String id, Map<String, dynamic> body);
  Future<dynamic> getEvidenceDetail(String evidenceId);
  Future<dynamic> postNote(String evidenceId, Map<String, dynamic> body);
  Future<dynamic> deleteEvidence(String evidenceId);
  Future<dynamic> postPair(String jobId, Map<String, dynamic> body);
  Future<dynamic> postJob(Map<String, dynamic> body);
  Future<dynamic> getTechnicians({String? jobId, Map<String, dynamic>? query});
  Future<dynamic> postAssign(String id, Map<String, dynamic> body);
  Future<dynamic> postCancel(String id, Map<String, dynamic> body);
  Future<dynamic> deleteJob(String id);
  Future<dynamic> getEquipmentHistory(String id);
  Future<dynamic> postAskManager(String id, Map<String, dynamic> body);
}

class JobsApiProvider implements IJobsApiProvider {
  JobsApiProvider(this._client);

  final ApiClient _client;

  @override
  Future<dynamic> getJobs(Map<String, dynamic> query) => _client.get(APIConstant.jobsAPIEP, query: query);

  @override
  Future<dynamic> getJob(String id) => _client.get(APIConstant.jobAPIEP(id));

  @override
  Future<dynamic> postStart(String id, Map<String, dynamic> body) =>
      _client.post(APIConstant.startJobAPIEP(id), body: body);

  @override
  Future<dynamic> getProof(String id) => _client.get(APIConstant.jobProofAPIEP(id));

  @override
  Future<dynamic> getEvidence(String id) => _client.get(APIConstant.jobEvidenceAPIEP(id));

  @override
  Future<dynamic> postEvidence(String id, Map<String, dynamic> body) =>
      _client.post(APIConstant.jobEvidenceAPIEP(id), body: body);

  @override
  Future<dynamic> getEvidenceDetail(String evidenceId) => _client.get(APIConstant.evidenceAPIEP(evidenceId));

  @override
  Future<dynamic> postNote(String evidenceId, Map<String, dynamic> body) =>
      _client.post(APIConstant.evidenceNotesAPIEP(evidenceId), body: body);

  @override
  Future<dynamic> deleteEvidence(String evidenceId) => _client.delete(APIConstant.evidenceAPIEP(evidenceId));

  @override
  Future<dynamic> postPair(String jobId, Map<String, dynamic> body) =>
      _client.post(APIConstant.photoPairsAPIEP(jobId), body: body);

  @override
  Future<dynamic> postJob(Map<String, dynamic> body) => _client.post(APIConstant.jobsAPIEP, body: body);

  @override
  Future<dynamic> getTechnicians({String? jobId, Map<String, dynamic>? query}) => _client.get(
        jobId == null ? APIConstant.newJobTechniciansAPIEP : APIConstant.jobTechniciansAPIEP(jobId),
        query: query,
      );

  @override
  Future<dynamic> postAssign(String id, Map<String, dynamic> body) =>
      _client.post(APIConstant.assignJobAPIEP(id), body: body);

  @override
  Future<dynamic> postCancel(String id, Map<String, dynamic> body) =>
      _client.post(APIConstant.jobCancelAPIEP(id), body: body);

  @override
  Future<dynamic> deleteJob(String id) => _client.delete(APIConstant.jobAPIEP(id));

  @override
  Future<dynamic> getEquipmentHistory(String id) => _client.get(APIConstant.jobEquipmentHistoryAPIEP(id));

  @override
  Future<dynamic> postAskManager(String id, Map<String, dynamic> body) =>
      _client.post(APIConstant.jobAskManagerAPIEP(id), body: body);
}
