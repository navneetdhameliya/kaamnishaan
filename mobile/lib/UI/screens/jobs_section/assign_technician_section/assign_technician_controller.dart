import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../../infrastructure/commons/constants/app_routes.dart';
import '../../../../infrastructure/data_access_layer/api_repository/jobs_api_repository.dart';
import '../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../../infrastructure/lang/translation_service.dart';
import '../../../../infrastructure/models/api_models.g.dart';
import '../../../../infrastructure/shared/job_arguments.dart';
import '../../../../infrastructure/shared/text_utils.dart';
import '../../../common_widgets/kn_toast.dart';
import '../new_job_section/new_job_controller.dart';

/// How busy a technician is that day: the colour of the bar on M17.
enum LoadTone { light, busy, full }

/// M17 Assign technician: who can do the job, least busy first, with their jobs that day.
/// People who have not joined yet show greyed out. From New job (M16) it hands the pick back;
/// for a saved job it gives the job at once.
class AssignTechnicianController extends GetxController {
  AssignTechnicianController({
    required this.jobs,
    required this.translation,
    AssignArguments? args,
    DateTime Function()? clock,
  })  : args = args ?? Get.arguments as AssignArguments,
        _clock = clock ?? DateTime.now;

  final IJobsApiRepository jobs;
  final TranslationService translation;
  final AssignArguments args;
  final DateTime Function() _clock;

  final RxList<AssignableTechnicianModel> people = <AssignableTechnicianModel>[].obs;
  final RxBool loading = true.obs;
  final RxBool failed = false.obs;
  final RxnString picked = RxnString();
  final RxBool saving = false.obs;

  @override
  void onInit() {
    super.onInit();
    picked.value = args.selectedId;
    load();
  }

  Future<void> load() async {
    loading.value = true;
    failed.value = false;
    final result = await jobs.technicians(jobId: args.jobId, at: args.at);
    loading.value = false;
    final list = result.dataOrNull;
    if (list == null) {
      failed.value = true;
      final e = result.errorOrNull!;
      if (!e.isNetwork) KnToast.error(e.message);
      return;
    }
    people.assignAll(list.data);
  }

  // ---- what it shows -----------------------------------------------------------------------

  bool get empty => !loading.value && !failed.value && people.isEmpty;

  bool get _today {
    final at = args.at;
    if (at == null) return true;
    final now = _clock();
    return at.year == now.year && at.month == now.month && at.day == now.day;
  }

  /// "AC not cooling · Sat 31 Oct, 11:30 AM"
  String get summary {
    final at = args.at;
    final when = at == null
        ? ''
        : at.hour == 0 && at.minute == 0
            ? DateFormat('EEE d MMM', translation.currentCode).format(at)
            : '${DateFormat('EEE d MMM', translation.currentCode).format(at)}, ${DateFormat.jm(translation.currentCode).format(at)}';
    return [if (args.title.isNotEmpty) args.title, if (when.isNotEmpty) when].join(' · ');
  }

  String get heading => _today
      ? LangKeys.assignAvailableToday.tr
      : LangKeys.assignAvailableOn.trParams({'day': DateFormat('EEE d MMM', translation.currentCode).format(args.at!)});

  bool invited(AssignableTechnicianModel t) => t.status == 'invited';

  /// "3 jobs today · 1.1 km away"; "Technician · invite sent" for people who have not joined.
  String line(AssignableTechnicianModel t) {
    if (invited(t)) return LangKeys.assignInviteSent.tr;
    final jobsLine = (_today ? LangKeys.assignJobsToday : LangKeys.assignJobsThatDay).trParams({'n': '${t.jobsToday}'});
    final km = t.distanceKm;
    return [
      jobsLine,
      if (km != null) LangKeys.assignKmAway.trParams({'km': km.toStringAsFixed(1)}),
    ].join(' · ');
  }

  /// "3 of 5 jobs"; "Full day" when there is no room (still allowed: a hint, not a block, D-17).
  String loadText(AssignableTechnicianModel t) => t.jobsToday >= t.capacity
      ? LangKeys.assignFull.tr
      : LangKeys.assignLoad.trParams({'n': '${t.jobsToday}', 'max': '${t.capacity}'});

  double share(AssignableTechnicianModel t) => t.capacity <= 0 ? 1 : (t.jobsToday / t.capacity).clamp(0, 1).toDouble();

  LoadTone tone(AssignableTechnicianModel t) {
    if (t.jobsToday >= t.capacity) return LoadTone.full;
    return share(t) >= 0.5 ? LoadTone.busy : LoadTone.light;
  }

  AssignableTechnicianModel? get chosen => people.firstWhereOrNull((t) => t.id == picked.value);

  String get buttonText {
    final c = chosen;
    return c == null ? LangKeys.assignPick.tr : LangKeys.assignButton.trParams({'name': TextUtils.firstName(c.name)});
  }

  /// "Save job without technician" only makes sense before the job is saved.
  bool get canSaveWithout => args.jobId == null;

  // ---- actions -----------------------------------------------------------------------------

  void onPersonTap(AssignableTechnicianModel t) {
    if (invited(t)) {
      KnToast.info(LangKeys.assignAfterJoiningToast.trParams({'name': TextUtils.firstName(t.name)}));
      return;
    }
    picked.value = t.id;
  }

  Future<void> onAssignTap() async {
    final c = chosen;
    if (c == null) return;
    final jobId = args.jobId;
    if (jobId == null) {
      Get.back<AssignableTechnicianModel>(result: c);
      return;
    }
    saving.value = true;
    final result = await jobs.assign(jobId, c.id);
    saving.value = false;
    if (result.dataOrNull == null) return KnToast.error(result.errorOrNull!.message);
    KnToast.success(LangKeys.assignDone.trParams({'name': TextUtils.firstName(c.name)}));
    Get.back<bool>(result: true);
  }

  /// M40 Invite person (as a technician); the list loads again after an invite.
  Future<void> onInviteTap() async {
    final sent = await Get.toNamed(RoutesConstants.inviteScreen, arguments: 'technician');
    if (sent == true) await load();
  }

  void onSaveWithoutTap() => Get.back<String>(result: saveWithoutTechnician);
}
