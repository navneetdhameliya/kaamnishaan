import '../../commons/constants/apis/api_constant.dart';
import '../networks/api_client.dart';

/// The job report: making it with AI, reading, editing and sending it to the manager (M31–M32).
abstract class IReportsApiProvider {
  Future<dynamic> postStart(String jobId);
  Future<dynamic> getTask(String taskId);
  Future<dynamic> getReport(String id);
  Future<dynamic> patchReport(String id, Map<String, dynamic> body);
  Future<dynamic> postRegenerate(String id, String section);
  Future<dynamic> postSubmit(String id);
}

class ReportsApiProvider implements IReportsApiProvider {
  ReportsApiProvider(this._client);

  final ApiClient _client;

  @override
  Future<dynamic> postStart(String jobId) => _client.post(APIConstant.jobReportsAPIEP(jobId));

  @override
  Future<dynamic> getTask(String taskId) => _client.get(APIConstant.taskAPIEP(taskId));

  @override
  Future<dynamic> getReport(String id) => _client.get(APIConstant.reportAPIEP(id));

  @override
  Future<dynamic> patchReport(String id, Map<String, dynamic> body) =>
      _client.patch(APIConstant.reportAPIEP(id), body: body);

  @override
  Future<dynamic> postRegenerate(String id, String section) =>
      _client.post(APIConstant.reportRegenerateAPIEP(id, section));

  @override
  Future<dynamic> postSubmit(String id) => _client.post(APIConstant.reportSubmitAPIEP(id));
}
