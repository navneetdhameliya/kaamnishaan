import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../common_widgets/common_shimmer.dart';
import '../../../common_widgets/kn_cover_image.dart';
import '../../../common_widgets/kn_custom_button.dart';
import '../../../common_widgets/kn_screen_footer.dart';
import '../../../common_widgets/kn_text_link.dart';
import '../../../commons/behaviour/behaviour.dart';
import '../../../commons/text_widgets/base/custom_base_text_widget.dart';
import '../../../theme/kn_app_theme.dart';
import '../../../theme/kn_tokens.g.dart';
import 'custom_widgets/customer_parts.dart';
import 'customer_details_controller.dart';

/// M18 Customer details (Figma 45:1262).
class CustomerDetailsScreen extends GetView<CustomerDetailsController> {
  const CustomerDetailsScreen({super.key});

  static const _header = 256.0;
  static const _radius = Radius.circular(28);

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final text = context.knText;
    final top = MediaQuery.paddingOf(context).top;
    return Scaffold(
      backgroundColor: kn.bgCanvas,
      bottomNavigationBar: KnScreenFooter(
        children: [
          KnCustomButton(
            key: const ValueKey('customer-new-job'),
            text: LangKeys.customerNewJob.tr,
            icon: LucideIcons.plus,
            onTap: controller.onNewJobTap,
          ),
        ],
      ),
      body: ScrollConfiguration(
        behavior: const KnScrollBehavior(),
        child: Obx(() {
          final loaded = controller.customer.value != null;
          return SingleChildScrollView(
            child: Stack(
              children: [
                // the photo header
                ClipRRect(
                  borderRadius: const BorderRadius.only(bottomLeft: _radius, bottomRight: _radius),
                  child: SizedBox(
                    height: _header + top,
                    width: double.infinity,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (controller.cover != null)
                          KnCoverImage(url: controller.cover, height: _header + top)
                        else
                          const ColoredBox(color: KnPrimitive.mocha900),
                        ColoredBox(color: KnPrimitive.mocha900.withValues(alpha: 0.45)),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(KnSize.space16, top + 12, KnSize.space16, KnSize.space24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          HeaderButton(
                            key: const ValueKey('customer-back'),
                            icon: LucideIcons.chevronLeft,
                            label: MaterialLocalizations.of(context).backButtonTooltip,
                            onTap: Get.back,
                          ),
                          const Spacer(),
                          HeaderButton(
                            key: const ValueKey('customer-edit'),
                            icon: LucideIcons.pencil,
                            onTap: controller.onEditTap,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 140,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (controller.since.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: KnPrimitive.cream100.withValues(alpha: 0.16),
                                  borderRadius: BorderRadius.circular(KnSize.radiusFull),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(LucideIcons.briefcase, size: 14, color: KnPrimitive.cream50),
                                    const SizedBox(width: 6),
                                    CustomBaseTextWidget(controller.since, style: text.labelSm, color: KnPrimitive.cream50),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 8),
                            CustomBaseTextWidget(controller.name, style: text.h1, color: KnPrimitive.cream50, maxLines: 2),
                            if (controller.address.isNotEmpty)
                              CustomBaseTextWidget(
                                controller.address,
                                style: text.body,
                                color: KnPrimitive.cream100,
                                maxLines: 1,
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: KnSize.space16),
                      if (!loaded)
                        const CommonShimmer(height: 230, radius: KnSize.radiusLg)
                      else
                        _ContactCard(controller: controller),
                      const SizedBox(height: KnSize.space24),
                      Row(
                        children: [
                          Expanded(child: CustomBaseTextWidget(LangKeys.customerPastJobs.tr, style: text.h3)),
                          if (controller.hasMore)
                            KnTextLink(
                              key: const ValueKey('customer-see-all'),
                              text: controller.seeAllText,
                              large: true,
                              onTap: controller.onSeeAllTap,
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (controller.loading.value)
                        const CommonShimmer(height: 72, radius: KnSize.radiusLg)
                      else if (controller.jobs.isEmpty)
                        CustomBaseTextWidget(LangKeys.customerNoJobs.tr, style: text.body, color: kn.textSecondary)
                      else
                        for (final j in controller.shownJobs) ...[
                          PastJobCard(
                            key: ValueKey('past-${j.id}'),
                            title: j.title,
                            line: controller.jobLine(j),
                            status: j.status,
                            coverUrl: j.coverUrl,
                            onTap: () => controller.onJobTap(j),
                          ),
                          const SizedBox(height: 10),
                        ],
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  const _ContactCard({required this.controller});

  final CustomerDetailsController controller;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final text = context.knText;
    final phone = controller.phone;
    final email = controller.email;
    final address = controller.address;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: kn.bgSurface,
        borderRadius: BorderRadius.circular(KnSize.radiusLg),
        border: Border.all(color: kn.borderDefault),
        boxShadow: KnShadow.md,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: KnSize.space16, vertical: KnSize.space12),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: KnPrimitive.sage100),
                    child: CustomBaseTextWidget(controller.contactInitials, style: text.label, color: KnPrimitive.sage700),
                  ),
                  const SizedBox(width: KnSize.space12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CustomBaseTextWidget(controller.contactName, style: text.label, maxLines: 1),
                        const SizedBox(height: 2),
                        CustomBaseTextWidget(controller.contactLine, style: text.caption, color: kn.textSecondary, maxLines: 1),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            ContactLine(
              key: const ValueKey('customer-phone'),
              label: LangKeys.customerPhone.tr,
              value: phone ?? LangKeys.customerNotSaved.tr,
              empty: phone == null,
              icon: LucideIcons.phone,
              onTap: phone == null ? null : controller.onCallTap,
            ),
            ContactLine(
              key: const ValueKey('customer-email'),
              label: LangKeys.customerEmail.tr,
              value: email ?? LangKeys.customerNotSaved.tr,
              empty: email == null,
              icon: LucideIcons.mail,
              onTap: email == null ? null : controller.onEmailTap,
            ),
            ContactLine(
              key: const ValueKey('customer-address'),
              label: LangKeys.customerAddress.tr,
              value: address.isEmpty ? LangKeys.customerNotSaved.tr : address,
              empty: address.isEmpty,
              icon: LucideIcons.mapPin,
              onTap: address.isEmpty ? null : controller.onMapTap,
            ),
          ],
        ),
      ),
    );
  }
}
