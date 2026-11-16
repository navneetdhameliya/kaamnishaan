import 'dart:convert';

import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../infrastructure/commons/constants/app_routes.dart';
import '../../../../infrastructure/data_access_layer/api_repository/home_api_repository.dart';
import '../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../../infrastructure/lang/translation_service.dart';
import '../../../../infrastructure/models/api_models.g.dart';
import '../../../../infrastructure/services/preferences_service.dart';
import '../../../../infrastructure/services/session_service.dart';
import '../../../../infrastructure/shared/app_logger.dart';
import '../../../../infrastructure/shared/job_arguments.dart';
import '../../../../infrastructure/shared/text_utils.dart';
import '../../../../infrastructure/shared/time_utils.dart';
import '../../../common_widgets/kn_toast.dart';

/// M12 Today for technicians: today's numbers, the job in progress, what comes next.
/// The last answer is kept on the phone, so without internet the screen still shows the day.
class TodayController extends GetxController {
  TodayController({
    required this.repository,
    required this.session,
    required this.prefs,
    required this.translation,
    DateTime Function()? clock,
    Future<bool> Function(Uri uri)? openUrl,
  })  : _clock = clock ?? DateTime.now,
        _openUrl = openUrl ?? ((uri) => launchUrl(uri));

  final IHomeApiRepository repository;
  final SessionService session;
  final PreferencesService prefs;
  final TranslationService translation;
  final DateTime Function() _clock;
  final Future<bool> Function(Uri uri) _openUrl;

  final Rxn<TodayModel> data = Rxn<TodayModel>();
  final RxBool loading = false.obs;
  final RxBool offline = false.obs;

  /// How many "Next up" rows the screen shows (the rest are behind "See all").
  static const nextUpRows = 3;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  String? get _userId => session.me.value?.id;

  String get name => data.value?.name ?? session.me.value?.name ?? '';

  String get firstName => TextUtils.firstName(name);

  String get initials => TextUtils.initials(name);

  String? get avatarUrl => session.me.value?.avatarUrl;

  String get greetingLine {
    final now = _clock();
    return '${TimeUtils.greeting(now)} · ${TimeUtils.shortDate(now, translation.currentCode)}';
  }

  bool get isEmpty {
    final d = data.value;
    return d != null && d.currentJob == null && d.nextJobs.isEmpty;
  }

  List<JobListItemModel> get nextUp => (data.value?.nextJobs ?? const []).take(nextUpRows).toList();

  String timeOf(DateTime? t) => t == null ? '' : TimeUtils.clock(t, translation.currentCode);

  Future<void> load() async {
    loading.value = data.value == null;
    if (data.value == null) _readCache();
    final result = await repository.today();
    loading.value = false;
    final today = result.dataOrNull;
    if (today != null) {
      data.value = today;
      offline.value = false;
      _writeCache(today);
      return;
    }
    final error = result.errorOrNull!;
    if (error.isNetwork) {
      offline.value = true;
    } else {
      KnToast.error(error.message);
    }
  }

  void _readCache() {
    final id = _userId;
    final raw = id == null ? null : prefs.cachedToday(id);
    if (raw == null) return;
    try {
      data.value = TodayModel.fromJson(Map<String, dynamic>.from(jsonDecode(raw) as Map));
    } catch (e) {
      AppLogger.error('Saved Today could not be read', error: e);
    }
  }

  void _writeCache(TodayModel today) {
    final id = _userId;
    if (id != null) prefs.setCachedToday(id, jsonEncode(today.toJson()));
  }

  Future<void> onCallManagerTap() async {
    final phone = data.value?.manager?.phone;
    if (phone == null) return;
    await _openUrl(Uri(scheme: 'tel', path: phone));
  }

  /// A job in progress opens its proof (M19); others open the job details (M15).
  void onJobTap(JobListItemModel job) {
    final working = job.status == 'in_progress' || job.status == 'changes_requested';
    Get.toNamed(
      working ? RoutesConstants.captureHubScreen : RoutesConstants.jobDetailsScreen,
      arguments: JobArguments.of(job),
    );
  }

  void onSeeAllTap() => Get.toNamed(RoutesConstants.jobListScreen);

  /// Notifications come later.
  void onBellTap() => KnToast.info(LangKeys.commonComingSoon.tr);
}
