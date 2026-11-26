import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../infrastructure/commons/constants/app_routes.dart';
import '../../../../infrastructure/data_access_layer/api_repository/jobs_api_repository.dart';
import '../../../../infrastructure/data_access_layer/api_repository/reviews_api_repository.dart';
import '../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../../infrastructure/lang/translation_service.dart';
import '../../../../infrastructure/models/api_models.g.dart';
import '../../../../infrastructure/services/location_service.dart';
import '../../../../infrastructure/services/session_service.dart';
import '../../../../infrastructure/services/speech_service.dart';
import '../../../../infrastructure/shared/job_arguments.dart';
import '../../../../infrastructure/shared/review_words.dart';
import '../../../../infrastructure/shared/time_utils.dart';
import '../../../common_widgets/kn_confirm_dialog.dart';
import '../../../common_widgets/kn_toast.dart';
import 'custom_widgets/equipment_history_sheet.dart';

/// M15 Job details: where, when, who to meet, the problem and the machine; Start job for the technician.
class JobDetailsController extends GetxController {
  JobDetailsController({
    required this.repository,
    required this.session,
    required this.speech,
    required this.translation,
    this.location,
    this.reviews,
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
  final ILocationService? location;

  /// Asking the customer for a review (the card under the job).
  final IReviewsApiRepository? reviews;
  final JobArguments args;
  final DateTime Function() _clock;
  final Future<bool> Function(Uri uri) _openUrl;

  final Rxn<JobOutModel> job = Rxn<JobOutModel>();

  /// How far the phone is from the site, e.g. "2.4 km away" (D-153); null when not known.
  final RxnString distance = RxnString();
  final RxBool loading = false.obs;
  final RxBool starting = false.obs;
  final RxBool askingReview = false.obs;

  /// Earlier jobs on this job's machine (the Equipment card opens them); null until loaded.
  final Rxn<List<JobListItemModel>> history = Rxn<List<JobListItemModel>>();

  /// The office's changes (assign, cancel, delete): what is running now, and the cancel reason box.
  final RxnString busy = RxnString();
  final TextEditingController cancelReason = TextEditingController();
  final RxString cancelDraft = ''.obs;

  /// Asks before deleting (tests answer here); null shows the confirm dialog.
  Future<bool> Function()? confirmDelete;

  late final ReviewWords reviewWords = ReviewWords(translation.currentCode);

  @override
  void onInit() {
    super.onInit();
    cancelReason.addListener(() => cancelDraft.value = cancelReason.text);
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

  // ---- customer review (M15) ----------------------------------------------------------------

  Future<void> onRequestReviewTap() async {
    final repo = reviews;
    final id = job.value?.id;
    if (repo == null || id == null || askingReview.value) return;
    askingReview.value = true;
    final result = await repo.request(id);
    askingReview.value = false;
    final card = result.dataOrNull;
    if (card == null) return KnToast.error(result.errorOrNull!.message);
    KnToast.success(
      card.status == 'queued'
          ? LangKeys.reviewAskedQueued.tr
          : LangKeys.reviewAskedSent.trParams({'name': reviewWords.contact(card)}),
    );
    await load();
  }

  Future<void> onCancelReviewTap() async {
    final repo = reviews;
    final id = job.value?.review?.requestId;
    if (repo == null || id == null) return;
    final result = await repo.cancel(id);
    if (result.errorOrNull != null) return KnToast.error(result.errorOrNull!.message);
    KnToast.info(LangKeys.reviewCancelled.tr);
    await load();
  }

  Future<void> onOpenReviewTap() async {
    final id = job.value?.review?.review?.id;
    if (id != null) await Get.toNamed<void>(RoutesConstants.reviewDetailsScreen, arguments: id);
  }

  /// Owners and managers open the customer's page (M18) from the name.
  bool get canOpenCustomer => const {'owner', 'manager'}.contains(session.me.value?.role) && job.value != null;

  Future<void> onCustomerTap() async {
    final c = job.value?.customer;
    if (c == null) return;
    await Get.toNamed<void>(RoutesConstants.customerScreen, arguments: CustomerArguments(id: c.id, name: c.name));
  }

  bool get canStart => job.value?.actions.contains('start') ?? false;

  bool get canContinue {
    final s = job.value?.status;
    return mine && (s == 'in_progress' || s == 'changes_requested');
  }

  @override
  void onClose() {
    cancelReason.dispose();
    super.onClose();
  }

  // ---- the office's changes (owners and managers) -----------------------------------------

  List<String> get _actions => job.value?.actions ?? const [];

  bool get canAssign => _actions.contains('assign');

  bool get canCancel => _actions.contains('cancel');

  bool get canDelete => _actions.contains('delete');

  bool get hasMenu => canAssign || canCancel || canDelete;

  /// "Assign technician" when nobody has the job yet, else "Change technician".
  String get assignLabel => job.value?.assignee == null ? LangKeys.jobAssign.tr : LangKeys.jobChangeTech.tr;

  /// The big button for an unassigned job (the office's main next step).
  bool get showAssignButton => canAssign && job.value?.assignee == null && !canStart && !canContinue;

  /// M17 with this job: giving it saves at once; the page loads again.
  Future<void> onAssignTap() async {
    final j = job.value;
    if (j == null || !canAssign) return;
    final done = await Get.toNamed<bool>(
      RoutesConstants.assignTechnicianScreen,
      arguments: AssignArguments(
        customer: j.customer.name,
        title: j.title,
        jobId: j.id,
        at: j.scheduledAt,
        selectedId: j.assignee?.id,
      ),
    );
    if (done == true) {
      _changed = true;
      await load();
    }
  }

  /// Quick reasons above the box; tapping one fills it.
  List<String> get cancelReasons => [
        LangKeys.jobCancelWhyCustomer.tr,
        LangKeys.jobCancelWhyMoved.tr,
        LangKeys.jobCancelWhyTwice.tr,
      ];

  void startCancel() {
    cancelReason.clear();
    cancelDraft.value = '';
  }

  void onCancelReasonPick(String r) {
    cancelReason.text = r;
    cancelDraft.value = r;
  }

  bool get canSendCancel => cancelDraft.value.trim().isNotEmpty && busy.value == null;

  /// "Cancel job" in the reason sheet; true when it worked (the sheet closes).
  Future<bool> onCancelJob() async {
    final j = job.value;
    final why = cancelReason.text.trim();
    if (j == null || why.isEmpty || busy.value != null) return false;
    busy.value = 'cancel';
    final result = await repository.cancel(j.id, why);
    busy.value = null;
    final fresh = result.dataOrNull;
    if (fresh == null) {
      KnToast.error(result.errorOrNull!.message);
      return false;
    }
    _changed = true;
    job.value = fresh;
    KnToast.success(LangKeys.jobCancelled.tr);
    return true;
  }

  Future<void> onDeleteTap() async {
    final j = job.value;
    if (j == null || !canDelete || busy.value != null) return;
    final ok = await (confirmDelete?.call() ??
        showKnConfirmDialog(
          title: LangKeys.jobDeleteTitle.tr,
          body: LangKeys.jobDeleteBody.tr,
          action: LangKeys.jobDelete.tr,
          danger: true,
        ));
    if (!ok) return;
    busy.value = 'delete';
    final result = await repository.delete(j.id);
    busy.value = null;
    if (!result.isSuccess) return KnToast.error(result.errorOrNull!.message);
    _changed = true;
    KnToast.success(LangKeys.jobDeleted.tr);
    Get.back<bool>(result: true);
  }

  bool _changed = false;

  /// The back arrow: the job list reloads when the office changed this job.
  void onBackTap() => Get.back<bool>(result: _changed);

  Future<void> load() async {
    loading.value = job.value == null;
    final result = await repository.job(args.id);
    loading.value = false;
    final data = result.dataOrNull;
    if (data != null) {
      job.value = data;
      unawaited(_measure(data));
    } else {
      KnToast.error(result.errorOrNull!.message);
    }
  }

  /// Open jobs only: once you are on site (or done) the distance says nothing.
  Future<void> _measure(JobOutModel j) async {
    final s = j.site;
    final loc = location;
    if (loc == null || s?.lat == null || s?.lng == null || !const {'unassigned', 'assigned'}.contains(j.status)) {
      return;
    }
    final here = await loc.current();
    if (here == null) return;
    distance.value = distanceText(metersBetween(here.lat, here.lng, s!.lat!, s.lng!));
  }

  /// "350 m away", "2.4 km away", "18 km away".
  static String distanceText(double m) {
    if (m < 1000) return LangKeys.jobDistanceM.trParams({'n': '${(m / 10).round() * 10}'});
    final km = m / 1000;
    return LangKeys.jobDistanceKm.trParams({'n': km < 10 ? km.toStringAsFixed(1) : '${km.round()}'});
  }

  /// Straight-line distance (haversine), in metres.
  static double metersBetween(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371000.0;
    double rad(double d) => d * math.pi / 180;
    final dLat = rad(lat2 - lat1), dLng = rad(lng2 - lng1);
    final a = math.pow(math.sin(dLat / 2), 2) + math.cos(rad(lat1)) * math.cos(rad(lat2)) * math.pow(math.sin(dLng / 2), 2);
    return 2 * r * math.asin(math.sqrt(a));
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
    final where = await location?.current(); // where the job started, as proof (D-57)
    final result = await repository.start(args.id, lat: where?.lat, lng: where?.lng);
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

  /// The Equipment card: what was done on this machine before (D-142).
  void onEquipmentTap() {
    loadHistory();
    showEquipmentHistorySheet(this);
  }

  Future<void> loadHistory() async {
    history.value = null;
    final result = await repository.equipmentHistory(args.id);
    final data = result.dataOrNull;
    if (data == null) {
      history.value = const [];
      return KnToast.error(result.errorOrNull!.message);
    }
    history.value = data.data;
  }

  /// "12 Mar 2026 · Ramesh Patel" (the date alone when nobody was on it).
  String historyLine(JobListItemModel j) {
    final at = j.scheduledAt ?? j.updatedAt;
    final date = DateFormat('d MMM y', translation.currentCode).format(at.toLocal());
    final name = j.assignee?.name;
    return name == null || name.isEmpty ? date : LangKeys.historyLine.trParams({'date': date, 'name': name});
  }

  void onHistoryJobTap(JobListItemModel j) {
    Get.back<void>();
    Get.toNamed(RoutesConstants.jobDetailsScreen, arguments: JobArguments.of(j), preventDuplicates: false);
  }
}
