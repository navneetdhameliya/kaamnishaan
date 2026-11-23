import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../infrastructure/data_access_layer/api_repository/company_api_repository.dart';
import '../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../../infrastructure/models/api_models.g.dart';
import '../../../../infrastructure/services/session_service.dart';
import '../../../../infrastructure/shared/text_utils.dart';
import '../../../../infrastructure/shared/time_utils.dart';
import '../../../common_widgets/kn_confirm_dialog.dart';
import '../../../common_widgets/kn_toast.dart';

/// A team member's own page (from Team, M40; no Figma frame: built from M40's rows and M18's cards).
/// Who they are, how to call them, their jobs waiting / going / done, and, for whoever may: change their
/// role, take them off the team (their jobs not started go back to Unassigned), or resend / cancel an
/// invite they haven't accepted. Goes back with true when the team changed.
class TeamMemberController extends GetxController {
  TeamMemberController({
    required this.company,
    required this.session,
    MemberOutModel? member,
    Future<bool> Function(Uri)? openUrl,
    Future<bool> Function({required String title, required String body, required String action})? confirm,
  })  : member = Rxn<MemberOutModel>(member ?? Get.arguments as MemberOutModel),
        _openUrl = openUrl ?? launchUrl,
        _confirm = confirm;

  final ICompanyApiRepository company;
  final SessionService session;
  final Rxn<MemberOutModel> member;
  final Future<bool> Function(Uri) _openUrl;
  final Future<bool> Function({required String title, required String body, required String action})? _confirm;

  final RxBool loading = true.obs;

  /// The action running now: role, remove, resend or cancel.
  final RxnString busy = RxnString();
  bool _changed = false;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    final m = member.value;
    if (m == null) return;
    final result = await company.member(m.id);
    loading.value = false;
    final fresh = result.dataOrNull;
    if (fresh != null) {
      member.value = fresh;
    } else if (!result.errorOrNull!.isNetwork) {
      KnToast.error(result.errorOrNull!.message);
    }
  }

  // ---- what it shows -----------------------------------------------------------------------

  MemberOutModel get m => member.value!;

  bool get isMe => m.id == session.me.value?.id;

  bool get invited => m.status == 'invited';

  bool get technician => m.role == 'technician';

  /// The owner: may change managers too.
  bool get _ownerPowers => session.me.value?.permissions.contains('team.manage_managers') ?? false;

  /// Who this person is to me: not me, not the owner, and a technician unless I am the owner.
  bool get _mayManage => !isMe && m.role != 'owner' && (technician || _ownerPowers);

  String get initials => TextUtils.initials(m.name);

  String get roleLabel => switch (m.role) {
        'owner' => LangKeys.roleOwner.tr,
        'manager' => LangKeys.roleManager.tr,
        _ => LangKeys.roleTechnician.tr,
      };

  /// "On a job", "Free", "Waiting to join"…
  String? get state {
    if (invited) return LangKeys.teamWaiting.tr;
    return switch (m.liveStatus) {
      'on_job' => LangKeys.teamOnJob.tr,
      'driving' => LangKeys.teamDriving.tr,
      'idle' => LangKeys.teamFree.tr,
      _ => null,
    };
  }

  /// "Joined 3 Nov 2026" / "SMS sent 2 days ago"
  String? get since {
    final locale = Get.locale?.languageCode ?? 'en';
    if (invited) {
      final at = m.invitedAt;
      return at == null ? null : LangKeys.tmInvited.trParams({'ago': TimeUtils.ago(at, DateTime.now())});
    }
    final at = m.joinedAt;
    return at == null ? null : LangKeys.tmJoined.trParams({'date': TimeUtils.date(at, locale)});
  }

  bool get showJobs => technician && !invited;

  int get waitingJobs => m.waitingJobs ?? 0;

  int get activeJobs => m.activeJobs ?? 0;

  int get doneJobs => m.doneJobs30d ?? 0;

  bool get canCall => !isMe && (m.phone ?? '').isNotEmpty;

  /// Only the owner changes roles (managers can't make or unmake managers).
  bool get canChangeRole => _mayManage && _ownerPowers && !invited;

  String get roleAction => technician ? LangKeys.tmMakeManager.tr : LangKeys.tmMakeTechnician.tr;

  bool get canRemove => _mayManage && !invited;

  bool get canHandleInvite => _mayManage && invited && m.inviteId != null;

  // ---- actions -----------------------------------------------------------------------------

  Future<bool> _ask({required String title, required String body, required String action, bool danger = false}) =>
      _confirm?.call(title: title, body: body, action: action) ??
      showKnConfirmDialog(
        title: title,
        body: body,
        action: action,
        danger: danger,
        icon: danger ? LucideIcons.userMinus : LucideIcons.check,
      );

  Future<void> onCallTap() async {
    final phone = m.phone;
    if (phone != null) await _openUrl(Uri(scheme: 'tel', path: phone));
  }

  Future<void> onRoleTap() async {
    if (!canChangeRole || busy.value != null) return;
    final to = technician ? 'manager' : 'technician';
    final first = TextUtils.firstName(m.name);
    final ok = await _ask(
      title: technician ? LangKeys.tmMakeManagerTitle.trParams({'name': first}) : LangKeys.tmMakeTechnicianTitle.trParams({'name': first}),
      body: technician ? LangKeys.tmMakeManagerBody.tr : LangKeys.tmMakeTechnicianBody.tr,
      action: roleAction,
    );
    if (!ok) return;
    busy.value = 'role';
    final result = await company.setRole(m.id, to);
    busy.value = null;
    final fresh = result.dataOrNull;
    if (fresh == null) return KnToast.error(result.errorOrNull!.message);
    _changed = true;
    member.value = fresh;
    await load();
    KnToast.success(LangKeys.tmRoleChanged.trParams({'name': first, 'role': roleLabel}));
  }

  /// What happens to their jobs, said before they are removed.
  String get removeBody => !technician
      ? LangKeys.tmRemoveBodyManager.tr
      : waitingJobs == 0
          ? LangKeys.tmRemoveBody.tr
          : LangKeys.tmRemoveBodyJobs.trParams({'n': '$waitingJobs'});

  Future<void> onRemoveTap() async {
    if (!canRemove || busy.value != null) return;
    final first = TextUtils.firstName(m.name);
    final ok = await _ask(
      title: LangKeys.tmRemoveTitle.trParams({'name': first}),
      body: removeBody,
      action: LangKeys.tmRemove.tr,
      danger: true,
    );
    if (!ok) return;
    busy.value = 'remove';
    final result = await company.removeMember(m.id);
    busy.value = null;
    if (!result.isSuccess) return KnToast.error(result.errorOrNull!.message);
    _changed = true;
    KnToast.success(LangKeys.tmRemoved.trParams({'name': first}));
    Get.back<bool>(result: true);
  }

  Future<void> onResendTap() async {
    final id = m.inviteId;
    if (id == null || busy.value != null) return;
    busy.value = 'resend';
    final result = await company.resendInvite(id);
    busy.value = null;
    if (result.dataOrNull == null) return KnToast.error(result.errorOrNull!.message);
    _changed = true;
    KnToast.success(LangKeys.teamResent.trParams({'name': TextUtils.firstName(m.name)}));
    await load();
  }

  Future<void> onCancelInviteTap() async {
    final id = m.inviteId;
    if (id == null || busy.value != null) return;
    final first = TextUtils.firstName(m.name);
    final ok = await _ask(
      title: LangKeys.tmCancelInviteTitle.trParams({'name': first}),
      body: LangKeys.tmCancelInviteBody.tr,
      action: LangKeys.tmCancelInvite.tr,
      danger: true,
    );
    if (!ok) return;
    busy.value = 'cancel';
    final result = await company.cancelInvite(id);
    busy.value = null;
    if (!result.isSuccess) return KnToast.error(result.errorOrNull!.message);
    KnToast.success(LangKeys.tmInviteCancelled.trParams({'name': first}));
    Get.back<bool>(result: true);
  }

  /// The back arrow: tells Team to reload when something changed here.
  void onBackTap() => Get.back<bool>(result: _changed);
}
