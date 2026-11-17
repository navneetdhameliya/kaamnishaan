import '../../models/api_models.g.dart';
import '../api_providers/company_api_provider.dart';
import '../networks/api_result.dart';

abstract class ICompanyApiRepository {
  Future<ApiResult<CompanyOutModel>> createCompany({
    required String name,
    required String trade,
    required String country,
    required String timezone,
  });
  Future<ApiResult<CompanyOutModel>> setLogo(String uploadId);

  /// The team (M40): everyone, owners first, with people still to join. [role]: manager or technician.
  Future<ApiResult<MemberListModel>> team({String? role, String? q});

  /// Sends the join SMS. A number already in the team fails with `phone_in_team`
  /// (details.existing_member has their name).
  Future<ApiResult<InviteOutModel>> invite({
    required String phone,
    required String name,
    required String role,
    String? smsLanguage,
  });

  /// A fresh SMS; the old link stops working.
  Future<ApiResult<InviteOutModel>> resendInvite(String inviteId);

  /// The SMS text, shown while the invite is filled in.
  Future<ApiResult<String>> invitePreview();
}

class CompanyApiRepository implements ICompanyApiRepository {
  CompanyApiRepository({required this.provider});

  final ICompanyApiProvider provider;

  Map<String, dynamic> _map(dynamic json) => Map<String, dynamic>.from(json as Map);

  @override
  Future<ApiResult<CompanyOutModel>> createCompany({
    required String name,
    required String trade,
    required String country,
    required String timezone,
  }) =>
      guard(() async => CompanyOutModel.fromJson(_map(await provider.postCompany({
            'name': name.trim(),
            'trade': trade,
            'country': country,
            'timezone': timezone,
          }))));

  @override
  Future<ApiResult<CompanyOutModel>> setLogo(String uploadId) =>
      guard(() async => CompanyOutModel.fromJson(_map(await provider.patchCompany({'logo_upload_id': uploadId}))));

  @override
  Future<ApiResult<MemberListModel>> team({String? role, String? q}) => guard(
        () async => MemberListModel.fromJson(_map(await provider.getTeam({
              'role': ?role,
              if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
            }))),
      );

  @override
  Future<ApiResult<InviteOutModel>> invite({
    required String phone,
    required String name,
    required String role,
    String? smsLanguage,
  }) =>
      guard(() async => InviteOutModel.fromJson(_map(await provider.postInvite({
            'phone': phone,
            'name': name.trim(),
            'role': role,
            'sms_language': ?smsLanguage,
          }))));

  @override
  Future<ApiResult<InviteOutModel>> resendInvite(String inviteId) =>
      guard(() async => InviteOutModel.fromJson(_map(await provider.postResendInvite(inviteId))));

  @override
  Future<ApiResult<String>> invitePreview() =>
      guard(() async => _map(await provider.getInvitePreview())['text'] as String);
}
