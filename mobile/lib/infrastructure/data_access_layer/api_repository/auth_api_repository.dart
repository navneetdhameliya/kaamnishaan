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
  Future<ApiResult<SessionOutModel>> refreshSession();
  Future<ApiResult<SessionOutModel>> switchCompany(String companyId);
  Future<ApiResult<void>> logout();
  Future<ApiResult<MeOutModel>> updateName(String name);
  Future<ApiResult<MyInviteListModel>> myInvites();
  Future<ApiResult<MeOutModel>> acceptInvite(String inviteId);
  Future<ApiResult<void>> declineInvite(String inviteId);
}

class AuthApiRepository implements IAuthApiRepository {
  AuthApiRepository({required IAuthApiProvider provider, required ApiClient client})
      : _provider = provider,
        _client = client;

  final IAuthApiProvider _provider;
  final ApiClient _client;

  Map<String, dynamic> _map(dynamic json) => Map<String, dynamic>.from(json as Map);

  @override
  Future<ApiResult<OtpSentModel>> sendOtp({required String phone}) =>
      guard(() async => OtpSentModel.fromJson(_map(await _provider.postOtpSend({'phone': phone}))));

  @override
  Future<ApiResult<SessionOutModel>> verifyOtp({required String challengeId, required String code, String? deviceId}) =>
      guard(() async => SessionOutModel.fromJson(_map(await _provider.postOtpVerify({
            'challenge_id': challengeId,
            'code': code,
            if (deviceId != null) 'device_id': deviceId,
          }))));

  @override
  Future<ApiResult<SessionOutModel>> refreshSession() => guard(() async {
        if (!await _client.refreshTokens() || _client.lastRefreshed == null) {
          throw ApiException(code: 'session_expired', message: LangKeys.errorSessionExpired.tr);
        }
        return SessionOutModel.fromJson(_client.lastRefreshed!);
      });

  @override
  Future<ApiResult<SessionOutModel>> switchCompany(String companyId) => guard(
      () async => SessionOutModel.fromJson(_map(await _provider.postSwitchCompany({'company_id': companyId}))));

  @override
  Future<ApiResult<void>> logout() => guard(() async {
        await _provider.postLogout();
      });

  @override
  Future<ApiResult<MeOutModel>> updateName(String name) =>
      guard(() async => MeOutModel.fromJson(_map(await _provider.patchMe({'name': name}))));

  @override
  Future<ApiResult<MyInviteListModel>> myInvites() =>
      guard(() async => MyInviteListModel.fromJson(_map(await _provider.getMyInvites())));

  @override
  Future<ApiResult<MeOutModel>> acceptInvite(String inviteId) =>
      guard(() async => MeOutModel.fromJson(_map(await _provider.postAcceptInvite(inviteId))));

  @override
  Future<ApiResult<void>> declineInvite(String inviteId) => guard(() async {
        await _provider.postDeclineInvite(inviteId);
      });
}
