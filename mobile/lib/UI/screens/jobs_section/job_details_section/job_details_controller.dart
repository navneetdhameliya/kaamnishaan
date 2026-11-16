import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../infrastructure/commons/constants/app_routes.dart';
import '../../../../infrastructure/data_access_layer/api_repository/jobs_api_repository.dart';
import '../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../../infrastructure/lang/translation_service.dart';
import '../../../../infrastructure/models/api_models.g.dart';
import '../../../../infrastructure/services/session_service.dart';
import '../../../../infrastructure/services/speech_service.dart';
import '../../../../infrastructure/shared/job_arguments.dart';
import '../../../../infrastructure/shared/time_utils.dart';
import '../../../common_widgets/kn_toast.dart';

/// M15 Job details: where, when, who to meet, the problem and the machine; Start job for the technician.
class JobDetailsController extends GetxController {
  JobDetailsController({
    required this.repository,
    required this.session,
    required this.speech,
    required this.translation,
    JobArguments? args,
    DateTime Function()? clock,
    Future<bool> Function(Uri uri)? openUrl,
  })  : args = args ?? Get.arguments as JobArguments,
        _clock = clock ?? DateTime.now,
        _openUrl = openUrl ?? ((uri) => launchUrl(uri, mode: LaunchMode.externalApplication));

  final IJobsApiRepository repository;
  final SessionService session;
  final ISpeechService speech;
  final TranslationService translation;
  final JobArguments args;
  final DateTime Function() _clock;
  final Future<bool> Function(Uri uri) _openUrl;

  final Rxn<JobOutModel> job = Rxn<JobOutModel>();
  final RxBool loading = false.obs;
  final RxBool starting = false.obs;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  String get customer => job.value?.customer.name ?? args.customer ?? '';

  String get address {
    final s = job.value?.site;
    return [s?.address, s?.city].where((p) => p != null && p.isNotEmpty).join(', ');
  }

  String get problem {
    final j = job.value;
    final d = j?.description?.trim();
    return d == null || d.isEmpty ? (j?.title ?? args.title ?? '') : d;
  }

  /// "Today · 11:30 AM", "Tomorrow · 9:00 AM", "Mon 2 Nov · 2:00 PM"
  String get when {
    final at = job.value?.scheduledAt?.toLocal();
    if (at == null) return '';
    final now = _clock();
    final day = DateTime(at.year, at.month, at.day).difference(DateTime(now.year, now.month, now.day)).inDays;
    final locale = translation.currentCode;
    final dayLabel = switch (day) {
      0 => LangKeys.jobsToday.tr,
      1 => LangKeys.jobsTomorrow.tr,
      _ => TimeUtils.shortDate(at, locale),
    };
    return LangKeys.jobWhen.trParams({'day': dayLabel, 'time': TimeUtils.clock(at, locale)});
  }

  /// "Split AC · 1.5 ton"
  String get equipmentName {
    final e = job.value?.equipment;
    if (e == null) return '';
    return [e.type, e.capacity].where((p) => p != null && p.isNotEmpty).join(' · ');
  }

  /// "Room 2 · last service 12 Aug"
  String get equipmentInfo {
    final e = job.value?.equipment;
    if (e == null) return '';
    final last = e.lastServiceAt == null
        ? null
        : LangKeys.jobLastService.trParams({'date': DateFormat('d MMM', translation.currentCode).format(e.lastServiceAt!)});
    return [e.location, e.brand, last].where((p) => p != null && p.isNotEmpty).join(' · ');
  }

  bool get mine => job.value?.assignee?.id == session.me.value?.id;

  bool get canStart => job.value?.actions.contains('start') ?? false;

  bool get canContinue {
    final s = job.value?.status;
    return mine && (s == 'in_progress' || s == 'changes_requested');
  }

  Future<void> load() async {
    loading.value = job.value == null;
    final result = await repository.job(args.id);
    loading.value = false;
    final data = result.dataOrNull;
    if (data != null) {
      job.value = data;
    } else {
      KnToast.error(result.errorOrNull!.message);
    }
  }

  Future<void> onNavigateTap() async {
    final s = job.value?.site;
    final destination = s?.lat != null && s?.lng != null ? '${s!.lat},${s.lng}' : address;
    if (destination.isEmpty) return;
    final uri = Uri.https('www.google.com', '/maps/dir/', {'api': '1', 'destination': destination});
    if (!await _open(uri)) KnToast.info(LangKeys.jobNoMapApp.tr);
  }

  Future<void> onCallTap() async {
    final phone = job.value?.contact?.phone;
    if (phone != null) await _open(Uri(scheme: 'tel', path: phone));
  }

  Future<bool> _open(Uri uri) async {
    try {
      return await _openUrl(uri);
    } catch (_) {
      return false;
    }
  }

  void onSpeakTap() => speech.speak(
        LangKeys.jobSpeak.trParams({'customer': customer, 'address': address, 'problem': problem}),
        languageCode: translation.currentCode,
      );

  Future<void> onStartTap() async {
    if (starting.value) return;
    starting.value = true;
    final result = await repository.start(args.id);
    starting.value = false;
    final started = result.dataOrNull;
    if (started == null) return KnToast.error(result.errorOrNull!.message);
    job.value = started;
    Get.offNamed(
      RoutesConstants.captureHubScreen,
      arguments: JobArguments(id: started.id, customer: started.customer.name, title: started.title),
    );
  }

  void onContinueTap() => Get.toNamed(
        RoutesConstants.captureHubScreen,
        arguments: JobArguments(id: args.id, customer: customer, title: job.value?.title ?? args.title),
      );

  /// Equipment history comes later.
  void onEquipmentTap() => KnToast.info(LangKeys.commonComingSoon.tr);
}
