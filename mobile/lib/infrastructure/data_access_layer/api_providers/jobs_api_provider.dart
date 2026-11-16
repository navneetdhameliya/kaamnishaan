import '../../commons/constants/apis/api_constant.dart';
import '../networks/api_client.dart';

/// Jobs: the list (M14), one job (M15), starting it, and its proof steps (M19).
abstract class IJobsApiProvider {
  Future<dynamic> getJobs(Map<String, dynamic> query);
  Future<dynamic> getJob(String id);
  Future<dynamic> postStart(String id, Map<String, dynamic> body);
  Future<dynamic> getProof(String id);
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
}
