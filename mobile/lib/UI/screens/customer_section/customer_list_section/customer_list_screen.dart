import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../common_widgets/common_shimmer.dart';
import '../../../common_widgets/kn_custom_button.dart';
import '../../../common_widgets/kn_screen_footer.dart';
import '../../../common_widgets/kn_title_bar.dart';
import '../../../commons/behaviour/behaviour.dart';
import '../../../commons/text_widgets/base/custom_base_text_widget.dart';
import '../../../theme/kn_app_theme.dart';
import '../../../theme/kn_tokens.g.dart';
import 'custom_widgets/customer_row.dart';
import 'customer_list_controller.dart';

/// Customers: a search, every customer and "Add customer" (no Figma frame; built like Team, M40).
class CustomerListScreen extends GetView<CustomerListController> {
  const CustomerListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final text = context.knText;
    return Scaffold(
      backgroundColor: kn.bgCanvas,
      bottomNavigationBar: KnScreenFooter(
        children: [
          KnCustomButton(
            key: const ValueKey('customers-add'),
            text: LangKeys.customersAdd.tr,
            icon: LucideIcons.plus,
            onTap: controller.onAddTap,
          ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: Obx(() {
          final items = controller.items;
          return RefreshIndicator(
            onRefresh: controller.load,
            child: ScrollConfiguration(
              behavior: const KnScrollBehavior(),
              child: ListView(
                controller: controller.scroll,
                padding: const EdgeInsets.fromLTRB(KnSize.space16, 12, KnSize.space16, KnSize.space24),
                children: [
                  KnTitleBar(title: LangKeys.meCustomers.tr),
                  const SizedBox(height: KnSize.space16),
                  TextField(
                    key: const ValueKey('customers-search'),
                    controller: controller.search,
                    onChanged: controller.onSearchChanged,
                    textInputAction: TextInputAction.search,
                    style: text.body,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: kn.bgSurface,
                      hintText: LangKeys.customersSearch.tr,
                      prefixIcon: Icon(LucideIcons.search, size: 20, color: kn.textSecondary),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(KnSize.radiusMd),
                        borderSide: BorderSide(color: kn.borderStrong),
                      ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(KnSize.radiusMd)),
                    ),
                  ),
                  const SizedBox(height: KnSize.space12),
                  if (controller.loading.value)
                    const CommonShimmer(height: 280, radius: KnSize.radiusLg)
                  else if (items.isNotEmpty) ...[
                    Container(
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: kn.bgSurface,
                        borderRadius: BorderRadius.circular(KnSize.radiusLg),
                        border: Border.all(color: kn.borderDefault),
                        boxShadow: KnShadow.sm,
                      ),
                      child: Material(
                        type: MaterialType.transparency,
                        child: Column(
                          children: [
                            for (final (i, c) in items.indexed)
                              CustomerRow(
                                key: ValueKey('customer-${c.id}'),
                                name: c.name,
                                initials: controller.initials(c),
                                line: controller.line(c),
                                jobs: controller.jobs(c),
                                divider: i < items.length - 1,
                                onTap: () => controller.onCustomerTap(c),
                              ),
                          ],
                        ),
                      ),
                    ),
                    if (controller.loadingMore.value)
                      const Padding(
                        padding: EdgeInsets.all(KnSize.space16),
                        child: Center(child: SizedBox.square(dimension: 24, child: CircularProgressIndicator(strokeWidth: 2))),
                      ),
                  ] else if (controller.noResults)
                    Padding(
                      padding: const EdgeInsets.all(KnSize.space24),
                      child: CustomBaseTextWidget(
                        LangKeys.customersNoResults.trParams({'q': controller.query.value.trim()}),
                        style: text.body,
                        color: kn.textSecondary,
                        textAlign: TextAlign.center,
                      ),
                    )
                  else if (controller.empty) ...[
                    const SizedBox(height: KnSize.space24),
                    Icon(LucideIcons.users, size: 40, color: kn.textSecondary),
                    const SizedBox(height: KnSize.space12),
                    CustomBaseTextWidget(LangKeys.customersEmptyTitle.tr, style: text.h3, textAlign: TextAlign.center),
                    const SizedBox(height: KnSize.space8),
                    CustomBaseTextWidget(
                      LangKeys.customersEmptyBody.tr,
                      style: text.body,
                      color: kn.textSecondary,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}
