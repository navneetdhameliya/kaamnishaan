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

  /// A team member's own page: what the list shows plus jobs waiting, going and done (30 days).
  Future<ApiResult<MemberOutModel>> member(String userId);

  /// Makes them a manager or a technician (managers change technicians only; the owner changes both).
  Future<ApiResult<MemberOutModel>> setRole(String userId, String role);

  /// Takes them off the team; their jobs not started go back to Unassigned.
  Future<ApiResult<void>> removeMember(String userId);

  /// Cancels an invite that hasn't been accepted yet.
  Future<ApiResult<void>> cancelInvite(String inviteId);

  /// M39: the company's trade (owner only).
  Future<ApiResult<CompanyOutModel>> setTrade(String trade);

  /// M39: the company's name, as customers see it on reports (owner only).
  Future<ApiResult<CompanyOutModel>> rename(String name);

  /// M39: "Technicians can share reports" (owner only).
  Future<ApiResult<CompanyOutModel>> setTechniciansCanShare(bool on);

  /// The number customers see as Call on their report page; '' takes it off (D-145).
  Future<ApiResult<CompanyOutModel>> setContactPhone(String phone);

  /// The plans with prices in [currency], names in [locale] (M39 plan row).
  Future<ApiResult<PlansOutModel>> plans({required String currency, required String locale});
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

  @override
  Future<ApiResult<CompanyOutModel>> setTrade(String trade) =>
      guard(() async => CompanyOutModel.fromJson(_map(await provider.patchCompany({'trade': trade}))));

  @override
  Future<ApiResult<CompanyOutModel>> rename(String name) =>
      guard(() async => CompanyOutModel.fromJson(_map(await provider.patchCompany({'name': name}))));

  @override
  Future<ApiResult<CompanyOutModel>> setTechniciansCanShare(bool on) => guard(
        () async => CompanyOutModel.fromJson(_map(await provider.patchSettings({'technicians_can_share': on}))),
      );

  @override
  Future<ApiResult<CompanyOutModel>> setContactPhone(String phone) => guard(
        () async => CompanyOutModel.fromJson(_map(await provider.patchSettings({'contact_phone': phone}))),
      );

  @override
  Future<ApiResult<PlansOutModel>> plans({required String currency, required String locale}) => guard(
        () async => PlansOutModel.fromJson(_map(await provider.getPlans({'currency': currency, 'locale': locale}))),
      );

  @override
  Future<ApiResult<MemberOutModel>> member(String userId) =>
      guard(() async => MemberOutModel.fromJson(_map(await provider.getMember(userId))));

  @override
  Future<ApiResult<MemberOutModel>> setRole(String userId, String role) =>
      guard(() async => MemberOutModel.fromJson(_map(await provider.patchMember(userId, {'role': role}))));

  @override
  Future<ApiResult<void>> removeMember(String userId) => guard(() async {
        await provider.deleteMember(userId);
      });

  @override
  Future<ApiResult<void>> cancelInvite(String inviteId) => guard(() async {
        await provider.deleteInvite(inviteId);
      });
}
