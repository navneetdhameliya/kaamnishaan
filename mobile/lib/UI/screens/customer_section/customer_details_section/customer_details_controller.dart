import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../infrastructure/commons/constants/app_routes.dart';
import '../../../../infrastructure/data_access_layer/api_repository/customers_api_repository.dart';
import '../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../../infrastructure/lang/translation_service.dart';
import '../../../../infrastructure/models/api_models.g.dart';
import '../../../../infrastructure/shared/job_arguments.dart';
import '../../../../infrastructure/shared/text_utils.dart';
import '../../../common_widgets/kn_toast.dart';

/// M18 Customer details: who they are, the main contact (call, email, map), their jobs,
/// "New job for this customer", and the pencil to edit them.
class CustomerDetailsController extends GetxController {
  CustomerDetailsController({
    required this.customers,
    required this.translation,
    CustomerArguments? args,
    Future<bool> Function(Uri)? open,
  })  : args = args ?? Get.arguments as CustomerArguments,
        _open = open ?? ((u) => launchUrl(u, mode: LaunchMode.externalApplication));

  final ICustomersApiRepository customers;
  final TranslationService translation;
  final CustomerArguments args;
  final Future<bool> Function(Uri) _open;

  /// Past jobs show this many until "See all".
  static const firstJobs = 2;

  final Rxn<CustomerOutModel> customer = Rxn<CustomerOutModel>();
  final RxList<JobListItemModel> jobs = <JobListItemModel>[].obs;
  final RxBool loading = true.obs;
  final RxBool showAll = false.obs;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    final results = await Future.wait([customers.customer(args.id), customers.jobs(args.id)]);
    loading.value = false;
    final c = results[0].dataOrNull as CustomerOutModel?;
    if (c == null) {
      final e = results[0].errorOrNull!;
      if (!e.isNetwork) KnToast.error(e.message);
    } else {
      customer.value = c;
    }
    final list = results[1].dataOrNull as JobListModel?;
    if (list != null) {
      final sorted = [...list.data]..sort((a, b) {
          final x = a.scheduledAt ?? a.updatedAt;
          final y = b.scheduledAt ?? b.updatedAt;
          return y.compareTo(x); // newest first
        });
      jobs.assignAll(sorted);
    }
  }

  // ---- what it shows -----------------------------------------------------------------------

  String get name => customer.value?.name ?? args.name;

  /// "Customer since 2024 · 5 jobs"
  String get since {
    final c = customer.value;
    if (c == null) return '';
    return LangKeys.customerSince.trParams({'year': '${c.customerSince.toLocal().year}', 'n': '${c.jobCount}'});
  }

  SiteOutModel? get site => customer.value?.sites.firstOrNull;

  String get address {
    final s = site;
    if (s == null) return '';
    return [s.addressLine1, s.addressLine2, s.city].where((p) => p != null && p.trim().isNotEmpty).join(', ');
  }

  /// The main contact, or the first one.
  ContactOutModel? get contact {
    final all = customer.value?.contacts ?? const <ContactOutModel>[];
    return all.firstWhereOrNull((c) => c.isPrimary) ?? all.firstOrNull;
  }

  String get contactName => contact?.name ?? name;

  String get contactInitials {
    final words = contactName.split(' ').where((w) => w.isNotEmpty && !w.endsWith('.')).toList();
    return words.isEmpty ? TextUtils.initials(contactName) : TextUtils.initials(words.join(' '));
  }

  /// "Clinic owner · main contact"
  String get contactLine {
    final title = contact?.title;
    return title == null || title.trim().isEmpty
        ? LangKeys.customerMainContact.tr
        : LangKeys.customerRoleMain.trParams({'title': title});
  }

  String? get phone => contact?.phone;

  String? get email => contact?.email;

  /// The newest job photo shows at the top.
  String? get cover => jobs.map((j) => j.coverUrl).whereType<String>().firstOrNull;

  List<JobListItemModel> get shownJobs => showAll.value ? jobs : jobs.take(firstJobs).toList();

  bool get hasMore => jobs.length > firstJobs;

  String get seeAllText =>
      showAll.value ? LangKeys.customerShowLess.tr : LangKeys.customerSeeAll.trParams({'n': '${jobs.length}'});

  /// "12 Aug · Ramesh"
  String jobLine(JobListItemModel j) {
    final at = j.scheduledAt ?? j.updatedAt;
    final who = j.assignee?.name;
    return [
      DateFormat('d MMM', translation.currentCode).format(at.toLocal()),
      who == null ? LangKeys.customerNotAssigned.tr : TextUtils.firstName(who),
    ].join(' · ');
  }

  // ---- actions -----------------------------------------------------------------------------

  Future<void> onCallTap() async {
    final p = phone;
    if (p != null) await _open(Uri(scheme: 'tel', path: p.replaceAll(' ', '')));
  }

  Future<void> onEmailTap() async {
    final e = email;
    if (e != null) await _open(Uri(scheme: 'mailto', path: e));
  }

  /// Opens the phone's maps app at the address.
  Future<void> onMapTap() async {
    final s = site;
    if (s == null) return;
    final lat = s.lat;
    final lng = s.lng;
    final query = lat != null && lng != null ? '$lat,$lng' : address;
    await _open(Uri.https('www.google.com', '/maps/search/', {'api': '1', 'query': query}));
  }

  void onSeeAllTap() => showAll.toggle();

  Future<void> onJobTap(JobListItemModel j) async {
    await Get.toNamed(RoutesConstants.jobDetailsScreen, arguments: JobArguments.of(j));
    load();
  }

  /// New job (M16) with this customer and address filled in.
  Future<void> onNewJobTap() async {
    final c = customer.value;
    final s = site;
    final made = await Get.toNamed(
      RoutesConstants.newJobScreen,
      arguments: CustomerListItemModel(
        id: args.id,
        name: name,
        jobCount: c?.jobCount ?? 0,
        site: s == null ? null : SiteBriefModel(id: s.id, address: address, city: s.city),
      ),
    );
    if (made == true) await load();
  }

  /// Editing a customer comes later.
  /// Edit customer: the name, phone, email, address and note; the page shows the change at once.
  Future<void> onEditTap() async {
    final c = customer.value;
    if (c == null) return;
    final saved = await Get.toNamed<CustomerOutModel?>(RoutesConstants.customerEditScreen, arguments: c);
    if (saved != null) customer.value = saved;
  }
}
