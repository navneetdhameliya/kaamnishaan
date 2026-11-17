import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../../infrastructure/commons/constants/app_routes.dart';
import '../../../../infrastructure/data_access_layer/api_repository/checklists_api_repository.dart';
import '../../../../infrastructure/data_access_layer/api_repository/customers_api_repository.dart';
import '../../../../infrastructure/data_access_layer/api_repository/jobs_api_repository.dart';
import '../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../../infrastructure/lang/translation_service.dart';
import '../../../../infrastructure/models/api_models.g.dart';
import '../../../../infrastructure/services/session_service.dart';
import '../../../../infrastructure/shared/job_arguments.dart';
import '../../../../infrastructure/shared/text_utils.dart';
import '../../../common_widgets/kn_customer_search.dart';
import '../../../common_widgets/kn_toast.dart';

/// What Assign technician (M17) says when the manager taps "Save job without technician".
const saveWithoutTechnician = 'save';

/// M16 New job: customer (search, or a new name), address, day and time, the work, a checklist and,
/// if the manager wants, the technician (M17). Customer, time and work are needed.
class NewJobController extends GetxController with CustomerSearchMixin {
  NewJobController({
    required this.jobs,
    required this.customers,
    required this.checklists,
    required this.session,
    required this.translation,
    DateTime Function()? clock,
    this.searchDelay = const Duration(milliseconds: 300),
    CustomerListItemModel? preset,
  })  : _clock = clock ?? DateTime.now,
        _preset = preset ?? (Get.arguments is CustomerListItemModel ? Get.arguments as CustomerListItemModel : null),
        clientUuid = const Uuid().v4();

  final IJobsApiRepository jobs;
  @override
  final ICustomersApiRepository customers;
  final IChecklistsApiRepository checklists;
  final SessionService session;
  final TranslationService translation;
  final DateTime Function() _clock;
  @override
  final Duration searchDelay;

  /// From Customer details (M18): the job starts with this customer and address.
  final CustomerListItemModel? _preset;

  /// Sent with the job so a retry after a lost answer makes one job, not two.
  final String clientUuid;

  final Rxn<CustomerListItemModel> customer = Rxn<CustomerListItemModel>();

  /// A new customer's name (when no known customer is picked).
  final RxnString newCustomer = RxnString();
  final TextEditingController address = TextEditingController();
  final TextEditingController work = TextEditingController();
  final FocusNode workFocus = FocusNode();
  final RxString workText = ''.obs;
  late final Rx<DateTime> day;
  final Rxn<TimeOfDay> time = Rxn<TimeOfDay>();
  final RxList<TemplateListItemModel> templates = <TemplateListItemModel>[].obs;
  final Rxn<TemplateListItemModel> checklist = Rxn<TemplateListItemModel>();
  final Rxn<AssignableTechnicianModel> technician = Rxn<AssignableTechnicianModel>();

  /// After the first "Create job" tap, missing fields show in red.
  final RxBool tried = false.obs;
  final RxBool saving = false.obs;


  @override
  void onInit() {
    super.onInit();
    final now = _clock();
    day = DateTime(now.year, now.month, now.day).obs;
    final c = _preset;
    if (c != null) {
      customer.value = c;
      address.text = c.site?.address ?? '';
    }
    loadTemplates();
  }

  @override
  void onClose() {
    address.dispose();
    work.dispose();
    workFocus.dispose();
    disposeSearch();
    super.onClose();
  }

  Future<void> loadTemplates() async {
    final list = (await checklists.templates()).dataOrNull;
    if (list != null) templates.assignAll(list.data.where((t) => t.status == 'published'));
  }

  // ---- what it shows -----------------------------------------------------------------------

  String get company => session.me.value?.company?.name ?? '';

  String get customerName => customer.value?.name ?? newCustomer.value ?? '';

  String get dayLabel => DateFormat('EEE, d MMM', translation.currentCode).format(day.value);

  String get timeLabel {
    final t = time.value;
    if (t == null) return '';
    final d = day.value;
    return DateFormat.jm(translation.currentCode).format(DateTime(d.year, d.month, d.day, t.hour, t.minute));
  }

  DateTime? get scheduledAt {
    final t = time.value;
    if (t == null) return null;
    final d = day.value;
    return DateTime(d.year, d.month, d.day, t.hour, t.minute);
  }

  String checklistLabel(TemplateListItemModel t) => '${t.name} · ${t.questionCount}';

  bool get customerMissing => tried.value && customerName.isEmpty;

  bool get timeMissing => tried.value && time.value == null;

  bool get workMissing => tried.value && workText.value.trim().isEmpty;

  int get missing => [customerName.isEmpty, time.value == null, workText.value.trim().isEmpty].where((m) => m).length;

  /// "2 things are missing. Please fill them in."
  String? get missingBanner {
    if (!tried.value || missing == 0) return null;
    return missing == 1 ? LangKeys.newjobMissingOne.tr : LangKeys.newjobMissingMany.trParams({'n': '$missing'});
  }

  String get technicianLine {
    final t = technician.value;
    if (t == null) return LangKeys.newjobTapToChoose.tr;
    return LangKeys.assignLoad.trParams({'n': '${t.jobsToday}', 'max': '${t.capacity}'});
  }

  String get technicianInitials => TextUtils.initials(technician.value?.name ?? '');

  // ---- customer ----------------------------------------------------------------------------

  /// Opens the search with all customers (A–Z), or the new name typed before; typing narrows it.
  void prepareSearch() => startSearch(newCustomer.value ?? '');

  void onCustomerPicked(CustomerListItemModel c) {
    customer.value = c;
    newCustomer.value = null;
    address.text = c.site?.address ?? '';
    Get.back<void>();
  }

  void onNewCustomerPicked() {
    customer.value = null;
    newCustomer.value = query.value.trim();
    address.clear();
    Get.back<void>();
  }

  // ---- when, work, checklist ---------------------------------------------------------------

  DateTime get firstDay {
    final now = _clock();
    return DateTime(now.year, now.month, now.day);
  }

  void onDatePicked(DateTime? d) {
    if (d != null) day.value = DateTime(d.year, d.month, d.day);
  }

  void onTimePicked(TimeOfDay? t) {
    if (t != null) time.value = t;
  }

  void onWorkChanged(String v) => workText.value = v;

  /// The microphone: the field opens with the keyboard, whose own microphone types what is said (D-65).
  void onWorkMicTap() => workFocus.requestFocus();

  void onChecklistPicked(TemplateListItemModel? t) {
    checklist.value = t;
    Get.back<void>();
  }

  // ---- technician and saving ---------------------------------------------------------------

  Future<void> onAssignTap() async {
    final picked = await Get.toNamed(
      RoutesConstants.assignTechnicianScreen,
      arguments: AssignArguments(
        customer: customerName,
        title: workText.value.trim(),
        at: scheduledAt ?? day.value,
        selectedId: technician.value?.id,
      ),
    );
    if (picked is AssignableTechnicianModel) {
      technician.value = picked;
    } else if (picked == saveWithoutTechnician) {
      technician.value = null;
      await onCreateTap();
    }
  }

  Future<void> onCreateTap() async {
    tried.value = true;
    if (missing > 0 || saving.value) return;
    saving.value = true;
    final result = await jobs.create(
      title: workText.value,
      scheduledAt: scheduledAt!,
      clientUuid: clientUuid,
      customerId: customer.value?.id,
      newCustomer: customer.value == null ? newCustomer.value : null,
      address: address.text,
      technicianId: technician.value?.id,
      checklistIds: [?checklist.value?.id],
    );
    saving.value = false;
    final job = result.dataOrNull;
    if (job == null) return KnToast.error(result.errorOrNull!.message);
    final who = technician.value?.name;
    KnToast.success(
      who == null ? LangKeys.newjobCreated.tr : LangKeys.newjobCreatedFor.trParams({'name': TextUtils.firstName(who)}),
    );
    Get.back<bool>(result: true);
  }
}
