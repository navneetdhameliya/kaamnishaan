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
  Future<dynamic> getReports(Map<String, dynamic> query);
  Future<dynamic> postApprove(String id);
  Future<dynamic> postChanges(String id, Map<String, dynamic> body);
  Future<dynamic> getPdf(String id);
  Future<dynamic> getShare(String id);
  Future<dynamic> postShareLink(String id, Map<String, dynamic> body);
  Future<dynamic> deleteShareLink(String linkId);
  Future<dynamic> postSend(String id, Map<String, dynamic> body);
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

  @override
  Future<dynamic> getReports(Map<String, dynamic> query) => _client.get(APIConstant.reportsAPIEP, query: query);

  @override
  Future<dynamic> postApprove(String id) => _client.post(APIConstant.reportApproveAPIEP(id));

  @override
  Future<dynamic> postChanges(String id, Map<String, dynamic> body) =>
      _client.post(APIConstant.reportChangesAPIEP(id), body: body);

  @override
  Future<dynamic> getPdf(String id) => _client.get(APIConstant.reportPdfAPIEP(id));

  @override
  Future<dynamic> getShare(String id) => _client.get(APIConstant.reportShareAPIEP(id));

  @override
  Future<dynamic> postShareLink(String id, Map<String, dynamic> body) =>
      _client.post(APIConstant.reportShareLinksAPIEP(id), body: body);

  @override
  Future<dynamic> deleteShareLink(String linkId) => _client.delete(APIConstant.shareLinkAPIEP(linkId));

  @override
  Future<dynamic> postSend(String id, Map<String, dynamic> body) =>
      _client.post(APIConstant.reportSendAPIEP(id), body: body);
}
