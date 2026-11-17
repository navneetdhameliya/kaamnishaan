import 'package:get/get.dart';

import '../../lang/lang_keys.g.dart';
import '../../models/api_models.g.dart';
import '../api_providers/auth_api_provider.dart';
import '../networks/api_client.dart';
import '../networks/api_exception.dart';
import '../networks/api_result.dart';

abstract class IAuthApiRepository {
  Future<ApiResult<OtpSentModel>> sendOtp({required String phone});
  Future<ApiResult<SessionOutModel>> verifyOtp({required String challengeId, required String code, String? deviceId});
  Future<ApiResult<SessionOutModel>> loginWithEmail({required String email, required String password});
  Future<ApiResult<SessionOutModel>> registerOwner({
    required String name,
    required String email,
    required String password,
  });
  Future<ApiResult<void>> forgotPassword(String email);
  Future<ApiResult<SessionOutModel>> refreshSession();
  Future<ApiResult<SessionOutModel>> switchCompany(String companyId);
  Future<ApiResult<void>> logout();
  Future<ApiResult<MeOutModel>> updateProfile({String? name, String? trade, String? avatarUploadId});
  Future<ApiResult<MyInviteListModel>> myInvites();

  /// GET /me: who I am now (M09 checks whether the email is confirmed).
  Future<ApiResult<MeOutModel>> me();

  /// M09 "Resend link".
  Future<ApiResult<void>> sendVerification();

  /// M09 "Wrong email? Change it": only before it is confirmed; a new link goes to the new email.
  Future<ApiResult<void>> changeEmail(String email);
  Future<ApiResult<MeOutModel>> acceptInvite(String inviteId);
  Future<ApiResult<void>> declineInvite(String inviteId);
}

class AuthApiRepository implements IAuthApiRepository {
  AuthApiRepository({required this.provider, required this.client});

  final IAuthApiProvider provider;
  final ApiClient client;

  Map<String, dynamic> _map(dynamic json) => Map<String, dynamic>.from(json as Map);

  @override
  Future<ApiResult<OtpSentModel>> sendOtp({required String phone}) =>
      guard(() async => OtpSentModel.fromJson(_map(await provider.postOtpSend({'phone': phone}))));

  @override
  Future<ApiResult<SessionOutModel>> verifyOtp({required String challengeId, required String code, String? deviceId}) =>
      guard(() async => SessionOutModel.fromJson(_map(await provider.postOtpVerify({
            'challenge_id': challengeId,
            'code': code,
            'device_id': ?deviceId,
          }))));

  @override
  Future<ApiResult<SessionOutModel>> loginWithEmail({required String email, required String password}) =>
      guard(() async => SessionOutModel.fromJson(
          _map(await provider.postLogin({'email': email.trim(), 'password': password}))));

  @override
  Future<ApiResult<SessionOutModel>> registerOwner({
    required String name,
    required String email,
    required String password,
  }) =>
      guard(() async => SessionOutModel.fromJson(_map(await provider.postRegister({
            'name': name.trim(),
            'email': email.trim(),
            'password': password,
            'accept_terms': true,
          }))));

  @override
  Future<ApiResult<void>> forgotPassword(String email) => guard(() async {
        await provider.postForgotPassword({'email': email.trim()});
      });

  @override
  Future<ApiResult<SessionOutModel>> refreshSession() => guard(() async {
        if (!await client.refreshTokens() || client.lastRefreshed == null) {
          throw ApiException(code: 'session_expired', message: LangKeys.errorSessionExpired.tr);
        }
        return SessionOutModel.fromJson(client.lastRefreshed!);
      });

  @override
  Future<ApiResult<SessionOutModel>> switchCompany(String companyId) => guard(
      () async => SessionOutModel.fromJson(_map(await provider.postSwitchCompany({'company_id': companyId}))));

  @override
  Future<ApiResult<void>> logout() => guard(() async {
        await provider.postLogout();
      });

  @override
  Future<ApiResult<MeOutModel>> updateProfile({String? name, String? trade, String? avatarUploadId}) =>
      guard(() async => MeOutModel.fromJson(_map(await provider.patchMe({
            'name': ?name,
            'trade': ?trade,
            'avatar_upload_id': ?avatarUploadId,
          }))));

  @override
  Future<ApiResult<MyInviteListModel>> myInvites() =>
      guard(() async => MyInviteListModel.fromJson(_map(await provider.getMyInvites())));

  @override
  Future<ApiResult<MeOutModel>> acceptInvite(String inviteId) =>
      guard(() async => MeOutModel.fromJson(_map(await provider.postAcceptInvite(inviteId))));

  @override
  Future<ApiResult<void>> declineInvite(String inviteId) => guard(() async {
        await provider.postDeclineInvite(inviteId);
      });

  @override
  Future<ApiResult<MeOutModel>> me() => guard(() async => MeOutModel.fromJson(_map(await provider.getMe())));

  @override
  Future<ApiResult<void>> sendVerification() => guard(() async {
        await provider.postSendVerification();
      });

  @override
  Future<ApiResult<void>> changeEmail(String email) => guard(() async {
        await provider.patchEmail(email.trim().toLowerCase());
      });
}
