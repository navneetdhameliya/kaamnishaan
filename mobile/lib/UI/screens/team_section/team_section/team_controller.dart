import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../../../infrastructure/commons/constants/app_routes.dart';
import '../../../../infrastructure/data_access_layer/api_repository/company_api_repository.dart';
import '../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../../infrastructure/models/api_models.g.dart';
import '../../../../infrastructure/services/session_service.dart';
import '../../../../infrastructure/shared/text_utils.dart';
import '../../../../infrastructure/shared/time_utils.dart';
import '../../../common_widgets/kn_toast.dart';

enum TeamFilter { all, technicians, managers }

/// The coloured word beside a person on M40.
enum MemberTone { good, info, quiet }

/// M40 Team: everyone in the company (owners and managers first), what each technician is doing today,
/// and people who have not joined yet with "Resend". "Invite person" opens the invite.
class TeamController extends GetxController {
  TeamController({required this.company, required this.session, DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  final ICompanyApiRepository company;
  final SessionService session;
  final DateTime Function() _clock;

  final RxList<MemberOutModel> members = <MemberOutModel>[].obs;
  final RxBool loading = true.obs;
  final Rx<TeamFilter> filter = TeamFilter.all.obs;
  final RxBool searching = false.obs;
  final TextEditingController search = TextEditingController();
  final RxString query = ''.obs;

  /// Invite ids being sent again right now.
  final RxSet<String> resending = <String>{}.obs;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  @override
  void onClose() {
    search.dispose();
    super.onClose();
  }

  Future<void> load() async {
    final result = await company.team();
    loading.value = false;
    final list = result.dataOrNull;
    if (list == null) {
      final e = result.errorOrNull!;
      if (!e.isNetwork) KnToast.error(e.message);
      return;
    }
    members.assignAll(list.data);
  }

  // ---- what it shows -----------------------------------------------------------------------

  bool _manager(MemberOutModel m) => m.role == 'owner' || m.role == 'manager';

  int get technicianCount => members.where((m) => m.role == 'technician').length;

  int get managerCount => members.where(_manager).length;

  String get subtitle => LangKeys.teamSubtitle.trParams({
        'company': session.me.value?.company?.name ?? '',
        'n': '${members.length}',
      });

  String chipLabel(TeamFilter f) => switch (f) {
        TeamFilter.all => LangKeys.teamAll.trParams({'n': '${members.length}'}),
        TeamFilter.technicians => LangKeys.teamTechnicians.trParams({'n': '$technicianCount'}),
        TeamFilter.managers => LangKeys.teamManagers.trParams({'n': '$managerCount'}),
      };

  Iterable<MemberOutModel> get _shown {
    final q = query.value.trim().toLowerCase();
    return members.where((m) {
      final fits = switch (filter.value) {
        TeamFilter.all => true,
        TeamFilter.technicians => m.role == 'technician',
        TeamFilter.managers => _manager(m),
      };
      if (!fits) return false;
      if (q.isEmpty) return true;
      return m.name.toLowerCase().contains(q) || (m.phone ?? '').replaceAll(' ', '').contains(q.replaceAll(' ', ''));
    });
  }

  List<MemberOutModel> get active => _shown.where((m) => m.status == 'active').toList();

  List<MemberOutModel> get waiting => _shown.where((m) => m.status == 'invited').toList();

  bool get onlyMe => !loading.value && members.length <= 1;

  bool isMe(MemberOutModel m) => m.id == session.me.value?.id;

  String name(MemberOutModel m) => isMe(m) ? LangKeys.teamYou.trParams({'name': m.name}) : m.name;

  String initials(MemberOutModel m) => TextUtils.initials(m.name);

  String role(MemberOutModel m) => switch (m.role) {
        'owner' => LangKeys.roleOwner.tr,
        'manager' => LangKeys.roleManager.tr,
        _ => LangKeys.roleTechnician.tr,
      };

  /// "Technician · 3 jobs" (today); managers show their role only.
  String line(MemberOutModel m) {
    if (m.status == 'invited') {
      final at = m.invitedAt;
      return at == null
          ? role(m)
          : LangKeys.teamSmsSent.trParams({'role': role(m), 'ago': TimeUtils.ago(at, _clock())});
    }
    return m.role == 'technician'
        ? LangKeys.teamJobsToday.trParams({'role': role(m), 'n': '${m.jobsToday ?? 0}'})
        : role(m);
  }

  /// "Online" (you), "On a job", "Driving", "Free"; nothing for others.
  String? state(MemberOutModel m) {
    if (isMe(m)) return LangKeys.teamOnline.tr;
    return switch (m.liveStatus) {
      'on_job' => LangKeys.teamOnJob.tr,
      'driving' => LangKeys.teamDriving.tr,
      'idle' => LangKeys.teamFree.tr,
      _ => null,
    };
  }

  MemberTone tone(MemberOutModel m) {
    if (isMe(m) || m.liveStatus == 'on_job') return MemberTone.good;
    return m.liveStatus == 'driving' ? MemberTone.info : MemberTone.quiet;
  }

  // ---- actions -----------------------------------------------------------------------------

  void onFilterTap(TeamFilter f) => filter.value = f;

  void onSearchTap() {
    searching.toggle();
    if (!searching.value) {
      search.clear();
      query.value = '';
    }
  }

  void onSearchChanged(String q) => query.value = q;

  /// A person's own page: their jobs, and changing their role or taking them off the team.
  Future<void> onMemberTap(MemberOutModel m) async {
    final changed = await Get.toNamed<bool>(RoutesConstants.teamMemberScreen, arguments: m);
    if (changed == true) await load();
  }

  Future<void> onResendTap(MemberOutModel m) async {
    final id = m.inviteId;
    if (id == null || resending.contains(id)) return;
    resending.add(id);
    final result = await company.resendInvite(id);
    resending.remove(id);
    if (result.dataOrNull == null) return KnToast.error(result.errorOrNull!.message);
    KnToast.success(LangKeys.teamResent.trParams({'name': TextUtils.firstName(m.name)}));
    await load();
  }

  Future<void> onInviteTap() async {
    final sent = await Get.toNamed(RoutesConstants.inviteScreen);
    if (sent == true) await load();
  }
}
