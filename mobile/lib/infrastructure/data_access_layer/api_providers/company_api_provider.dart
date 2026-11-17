import '../../commons/constants/apis/api_constant.dart';
import '../networks/api_client.dart';

/// The company: create it (M07), change its details, its team and invites (M40).
/// Returns raw JSON; the repository makes models.
abstract class ICompanyApiProvider {
  Future<dynamic> postCompany(Map<String, dynamic> body);
  Future<dynamic> patchCompany(Map<String, dynamic> body);
  Future<dynamic> getTeam(Map<String, dynamic> query);
  Future<dynamic> postInvite(Map<String, dynamic> body);
  Future<dynamic> postResendInvite(String id);
  Future<dynamic> getInvitePreview();
  Future<dynamic> patchSettings(Map<String, dynamic> body);
  Future<dynamic> getPlans(Map<String, dynamic> query);
}

class CompanyApiProvider implements ICompanyApiProvider {
  CompanyApiProvider(this._client);

  final ApiClient _client;

  @override
  Future<dynamic> postCompany(Map<String, dynamic> body) => _client.post(APIConstant.companiesAPIEP, body: body);

  @override
  Future<dynamic> patchCompany(Map<String, dynamic> body) => _client.patch(APIConstant.companyAPIEP, body: body);

  @override
  Future<dynamic> getTeam(Map<String, dynamic> query) => _client.get(APIConstant.teamAPIEP, query: query);

  @override
  Future<dynamic> postInvite(Map<String, dynamic> body) => _client.post(APIConstant.invitesAPIEP, body: body);

  @override
  Future<dynamic> postResendInvite(String id) => _client.post(APIConstant.resendInviteAPIEP(id));

  @override
  Future<dynamic> getInvitePreview() => _client.get(APIConstant.invitePreviewAPIEP);

  @override
  Future<dynamic> patchSettings(Map<String, dynamic> body) =>
      _client.patch(APIConstant.companySettingsAPIEP, body: body);

  @override
  Future<dynamic> getPlans(Map<String, dynamic> query) => _client.get(APIConstant.plansAPIEP, query: query);
}
