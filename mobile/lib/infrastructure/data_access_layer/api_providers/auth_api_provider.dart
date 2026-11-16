import '../../commons/constants/apis/api_constant.dart';
import '../networks/api_client.dart';

/// Login, session and the signed-in person. Returns raw JSON; the repository makes models.
abstract class IAuthApiProvider {
  Future<dynamic> postOtpSend(Map<String, dynamic> body);
  Future<dynamic> postOtpVerify(Map<String, dynamic> body);
  Future<dynamic> postSwitchCompany(Map<String, dynamic> body);
  Future<dynamic> postLogout();
  Future<dynamic> getMe();
  Future<dynamic> patchMe(Map<String, dynamic> body);
  Future<dynamic> getMyInvites();
  Future<dynamic> postAcceptInvite(String inviteId);
  Future<dynamic> postDeclineInvite(String inviteId);
}

class AuthApiProvider implements IAuthApiProvider {
  AuthApiProvider(this._client);

  final ApiClient _client;

  @override
  Future<dynamic> postOtpSend(Map<String, dynamic> body) =>
      _client.post(APIConstant.otpSendAPIEP, body: body, options: ApiClient.public);

  @override
  Future<dynamic> postOtpVerify(Map<String, dynamic> body) =>
      _client.post(APIConstant.otpVerifyAPIEP, body: body, options: ApiClient.public);

  @override
  Future<dynamic> postSwitchCompany(Map<String, dynamic> body) =>
      _client.post(APIConstant.switchCompanyAPIEP, body: body);

  @override
  Future<dynamic> postLogout() => _client.post(APIConstant.logoutAPIEP);

  @override
  Future<dynamic> getMe() => _client.get(APIConstant.meAPIEP);

  @override
  Future<dynamic> patchMe(Map<String, dynamic> body) => _client.patch(APIConstant.meAPIEP, body: body);

  @override
  Future<dynamic> getMyInvites() => _client.get(APIConstant.myInvitesAPIEP);

  @override
  Future<dynamic> postAcceptInvite(String inviteId) => _client.post(APIConstant.acceptInviteAPIEP(inviteId));

  @override
  Future<dynamic> postDeclineInvite(String inviteId) => _client.post(APIConstant.declineInviteAPIEP(inviteId));
}
