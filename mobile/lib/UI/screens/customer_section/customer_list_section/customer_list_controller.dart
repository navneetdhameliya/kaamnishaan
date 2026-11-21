import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../../../infrastructure/commons/constants/app_routes.dart';
import '../../../../infrastructure/data_access_layer/api_repository/customers_api_repository.dart';
import '../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../../infrastructure/models/api_models.g.dart';
import '../../../../infrastructure/shared/job_arguments.dart';
import '../../../../infrastructure/shared/text_utils.dart';
import '../../../common_widgets/kn_toast.dart';

/// Customers (owners and managers, from Me): every customer, newest work first, with a search by name,
/// phone or city, more as you scroll, and "Add customer". No Figma frame: built like Team (M40).
class CustomerListController extends GetxController {
  CustomerListController({required this.customers, this.debounce = const Duration(milliseconds: 300)});

  final ICustomersApiRepository customers;
  final Duration debounce;

  final RxList<CustomerListItemModel> items = <CustomerListItemModel>[].obs;
  final RxBool loading = true.obs;
  final RxBool loadingMore = false.obs;
  final RxString query = ''.obs;
  final TextEditingController search = TextEditingController();
  final ScrollController scroll = ScrollController();
  String? _next;
  int _asked = 0; // a slow old answer never replaces a newer search
  Timer? _typing;

  @override
  void onInit() {
    super.onInit();
    scroll.addListener(() {
      if (scroll.hasClients && scroll.position.extentAfter < 400) loadMore();
    });
    load();
  }

  @override
  void onClose() {
    _typing?.cancel();
    search.dispose();
    scroll.dispose();
    super.onClose();
  }

  /// The first page for the current search.
  Future<void> load() async {
    final ask = ++_asked;
    final result = await customers.page(q: query.value);
    if (ask != _asked) return;
    loading.value = false;
    final page = result.dataOrNull;
    if (page == null) {
      final e = result.errorOrNull!;
      if (!e.isNetwork) KnToast.error(e.message);
      return;
    }
    items.assignAll(page.data);
    _next = page.meta.nextCursor;
  }

  bool get hasMore => _next != null;

  /// The next page, when the list is scrolled near its end.
  Future<void> loadMore() async {
    final cursor = _next;
    if (cursor == null || loadingMore.value || loading.value) return;
    loadingMore.value = true;
    final ask = _asked;
    final result = await customers.page(q: query.value, cursor: cursor);
    loadingMore.value = false;
    final page = result.dataOrNull;
    if (ask != _asked || page == null) return;
    items.addAll(page.data);
    _next = page.meta.nextCursor;
  }

  void onSearchChanged(String v) {
    _typing?.cancel();
    _typing = Timer(debounce, () {
      if (v.trim() == query.value.trim()) return;
      query.value = v;
      loading.value = true;
      load();
    });
  }

  // ---- what each row shows -----------------------------------------------------------------

  String initials(CustomerListItemModel c) => TextUtils.initials(c.name);

  /// "Rahul Mehta · Ahmedabad", or the phone when the contact is the customer.
  String line(CustomerListItemModel c) {
    final pc = c.primaryContact;
    final who = pc == null ? null : (pc.name.trim().toLowerCase() == c.name.trim().toLowerCase() ? pc.phone : pc.name);
    return [?who, ?c.city].where((x) => x.trim().isNotEmpty).join(' · ');
  }

  /// "5 jobs" / "1 job" / "No jobs yet"
  String jobs(CustomerListItemModel c) => switch (c.jobCount) {
        0 => LangKeys.customersNoJobs.tr,
        1 => LangKeys.customersJobOne.tr,
        final n => LangKeys.customersJobs.trParams({'n': '$n'}),
      };

  bool get empty => !loading.value && items.isEmpty && query.value.trim().isEmpty;

  bool get noResults => !loading.value && items.isEmpty && query.value.trim().isNotEmpty;

  // ---- taps --------------------------------------------------------------------------------

  Future<void> onCustomerTap(CustomerListItemModel c) async {
    await Get.toNamed<void>(RoutesConstants.customerScreen, arguments: CustomerArguments(id: c.id, name: c.name));
    await load(); // the name, contact or address may have changed
  }

  /// "Add customer": the form, then the new customer's page.
  Future<void> onAddTap() async {
    final made = await Get.toNamed<CustomerOutModel?>(RoutesConstants.customerEditScreen);
    if (made == null) return;
    await load();
    await Get.toNamed<void>(RoutesConstants.customerScreen, arguments: CustomerArguments(id: made.id, name: made.name));
  }
}
