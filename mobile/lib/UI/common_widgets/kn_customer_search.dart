import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../infrastructure/data_access_layer/api_repository/customers_api_repository.dart';
import '../../infrastructure/lang/lang_keys.g.dart';
import '../../infrastructure/models/api_models.g.dart';
import '../commons/text_widgets/base/custom_base_text_widget.dart';
import '../theme/kn_app_theme.dart';
import '../theme/kn_tokens.g.dart';
import 'custom_inkwell.dart';

/// Searching the company's customers by name or phone, for a bottom sheet (New job M16, Me → Customers).
mixin CustomerSearchMixin on GetxController {
  ICustomersApiRepository get customers;

  Duration get searchDelay;

  final TextEditingController search = TextEditingController();
  final RxString query = ''.obs;
  final RxList<CustomerListItemModel> found = <CustomerListItemModel>[].obs;
  final RxBool searching = false.obs;
  Timer? _debounce;

  /// Opens the search with [text] typed (all customers, A–Z, when empty).
  void startSearch([String text = '']) {
    search.text = text;
    query.value = text;
    _find(text);
  }

  void onSearchChanged(String q) {
    query.value = q;
    _debounce?.cancel();
    _debounce = Timer(searchDelay, () => _find(q));
  }

  Future<void> _find(String q) async {
    searching.value = true;
    final list = (await customers.search(q)).dataOrNull;
    searching.value = false;
    if (list != null && q == query.value) found.assignAll(list.data);
  }

  /// "Add “Sharma house” as new customer" shows when no customer has exactly that name.
  bool get canAddNew {
    final q = query.value.trim().toLowerCase();
    return q.isNotEmpty && !found.any((c) => c.name.toLowerCase() == q);
  }

  void disposeSearch() {
    _debounce?.cancel();
    search.dispose();
  }
}

/// One row in a pick list sheet (a customer, a checklist).
class KnPickRow extends StatelessWidget {
  const KnPickRow({
    super.key,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.icon,
    this.selected = false,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final text = context.knText;
    final sub = subtitle;
    final radius = BorderRadius.circular(KnSize.radiusMd);
    return CustomInkWell(
      onTap: onTap,
      borderRadius: radius,
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: KnSize.space12, vertical: 10),
        decoration: BoxDecoration(
          color: kn.bgSurface,
          borderRadius: radius,
          border: Border.all(color: selected ? kn.actionPrimary : kn.borderDefault, width: selected ? 2 : 1),
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20, color: kn.textLink),
              const SizedBox(width: KnSize.space12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CustomBaseTextWidget(title, style: text.label, maxLines: 2),
                  if (sub != null && sub.isNotEmpty)
                    CustomBaseTextWidget(sub, style: text.caption, color: kn.textSecondary, maxLines: 1),
                ],
              ),
            ),
            if (selected) Icon(LucideIcons.check, size: 20, color: kn.actionPrimary),
          ],
        ),
      ),
    );
  }
}

/// The customer search sheet: a search box, matching customers with their address and, when
/// [onAddNew] is given, "Add “…” as new customer".
class KnCustomerSearchSheet extends StatelessWidget {
  const KnCustomerSearchSheet({
    super.key,
    required this.search,
    required this.onPicked,
    this.onAddNew,
    this.selectedId,
  });

  final CustomerSearchMixin search;
  final ValueChanged<CustomerListItemModel> onPicked;
  final VoidCallback? onAddNew;
  final String? selectedId;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final add = onAddNew;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const ValueKey('customer-search'),
          controller: search.search,
          autofocus: true,
          onChanged: search.onSearchChanged,
          textCapitalization: TextCapitalization.words,
          style: context.knText.body,
          decoration: InputDecoration(
            filled: true,
            fillColor: kn.bgSurface,
            hintText: LangKeys.newjobCustomerHint.tr,
            prefixIcon: Icon(LucideIcons.search, size: 20, color: kn.textSecondary),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(KnSize.radiusMd)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(KnSize.radiusMd),
              borderSide: BorderSide(color: kn.borderStrong),
            ),
          ),
        ),
        const SizedBox(height: KnSize.space12),
        Flexible(
          child: Obx(() {
            final adding = add != null && search.canAddNew;
            return ListView(
              shrinkWrap: true,
              children: [
                if (adding)
                  KnPickRow(
                    key: const ValueKey('customer-add'),
                    icon: LucideIcons.userPlus,
                    title: LangKeys.newjobAddCustomer.trParams({'name': search.query.value.trim()}),
                    subtitle: LangKeys.newjobNewCustomer.tr,
                    onTap: add,
                  ),
                for (final c in search.found) ...[
                  const SizedBox(height: KnSize.space8),
                  KnPickRow(
                    key: ValueKey('customer-${c.id}'),
                    title: c.name,
                    subtitle: c.site?.address ?? c.city,
                    selected: selectedId == c.id,
                    onTap: () => onPicked(c),
                  ),
                ],
                if (!search.searching.value && search.found.isEmpty && !adding)
                  Padding(
                    padding: const EdgeInsets.all(KnSize.space16),
                    child: CustomBaseTextWidget(
                      LangKeys.newjobNoCustomers.tr,
                      style: context.knText.body,
                      color: kn.textSecondary,
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            );
          }),
        ),
      ],
    );
  }
}

/// A search on its own, for opening a customer from anywhere (Me → Customers → M18).
class CustomerFinder extends GetxController with CustomerSearchMixin {
  CustomerFinder({required this.customers, this.searchDelay = const Duration(milliseconds: 300)});

  @override
  final ICustomersApiRepository customers;

  @override
  final Duration searchDelay;

  @override
  void onClose() {
    disposeSearch();
    super.onClose();
  }
}
