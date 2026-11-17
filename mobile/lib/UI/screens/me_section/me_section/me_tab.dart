import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../infrastructure/commons/constants/app_routes.dart';
import '../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../../infrastructure/shared/text_utils.dart';
import '../../../common_widgets/kn_initials_avatar.dart';
import '../../../commons/behaviour/behaviour.dart';
import '../../../commons/text_widgets/base/custom_base_text_widget.dart';
import '../../../theme/kn_app_theme.dart';
import '../../../theme/kn_tokens.g.dart';
import 'custom_widgets/logout_dialog.dart';
import 'custom_widgets/me_rows.dart';
import 'me_controller.dart';

/// M37 Me (Figma 32:1586), the last tab for technicians and for owners and managers.
class MeTab extends GetView<MeController> {
  const MeTab({super.key});

  Future<void> _logout() async {
    final waiting = controller.waiting;
    if (waiting == 0) return controller.logout();
    final choice = await showLogoutDialog(waiting);
    if (choice == LogoutChoice.logout) {
      await controller.logout();
    } else if (choice == LogoutChoice.sendFirst) {
      await Get.toNamed(RoutesConstants.waitingToSendScreen);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = context.knText;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: RefreshIndicator(
        onRefresh: controller.load,
        child: ScrollConfiguration(
          behavior: const KnScrollBehavior(),
          child: Obx(() {
            final p = controller.profile;
            final technician = !controller.isManager;
            return ListView(
              padding: EdgeInsets.zero,
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                Stack(
                  children: [
                    Container(
                      height: 230 + MediaQuery.paddingOf(context).top,
                      decoration: const BoxDecoration(
                        color: KnPrimitive.mocha900,
                        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        children: [
                          Positioned(
                            right: -70,
                            top: -60,
                            child: Container(
                              width: 220,
                              height: 220,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: KnPrimitive.cream100.withValues(alpha: 0.10), width: 30),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(KnSize.space16, 20, KnSize.space16, 0),
                        child: Column(
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: KnPrimitive.cream100, width: 3),
                                  ),
                                  child: KnInitialsAvatar(
                                    initials: TextUtils.initials(controller.name),
                                    url: p?.avatarUrl,
                                    size: 72,
                                    borderWidth: 0,
                                  ),
                                ),
                                const SizedBox(width: KnSize.space16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 4),
                                      CustomBaseTextWidget(controller.name, style: text.h2, color: KnPrimitive.cream50, maxLines: 1),
                                      if (controller.company.isNotEmpty)
                                        CustomBaseTextWidget(
                                          controller.company,
                                          style: text.body,
                                          color: KnPrimitive.cream400,
                                          maxLines: 1,
                                        ),
                                      const SizedBox(height: KnSize.space8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: KnPrimitive.cream100.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(KnSize.radiusFull),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(LucideIcons.briefcase, size: 14, color: KnPrimitive.cream50),
                                            const SizedBox(width: 6),
                                            CustomBaseTextWidget(controller.role, style: text.labelSm, color: KnPrimitive.cream50),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Semantics(
                                  label: LangKeys.meEditProfile.tr,
                                  button: true,
                                  child: Material(
                                    color: KnPrimitive.cream100.withValues(alpha: 0.12),
                                    shape: const CircleBorder(),
                                    child: InkWell(
                                      key: const ValueKey('me-edit'),
                                      customBorder: const CircleBorder(),
                                      onTap: controller.onEditTap,
                                      child: const SizedBox.square(
                                        dimension: 44,
                                        child: Icon(LucideIcons.pencil, size: 20, color: KnPrimitive.cream50),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 28),
                            StatsCard(stats: controller.numbers),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(KnSize.space16, KnSize.space16, KnSize.space16, 120),
                  child: Column(
                    children: [
                      MeCard(
                        rows: [
                          if (technician)
                            MeRow(
                              key: const ValueKey('me-reports'),
                              icon: LucideIcons.fileText,
                              label: LangKeys.meMyReports.tr,
                              value: '${controller.stats.value?.reportsSent ?? ''}',
                              onTap: controller.onMyReportsTap,
                            ),
                          if (technician)
                            MeRow(
                              key: const ValueKey('me-reviews'),
                              icon: LucideIcons.star,
                              label: LangKeys.meMyReviews.tr,
                              onTap: controller.onMyReviewsTap,
                            ),
                          if (technician || controller.waiting > 0)
                            MeRow(
                              key: const ValueKey('me-waiting'),
                              icon: LucideIcons.cloud,
                              label: LangKeys.meWaiting.tr,
                              badge: controller.waiting,
                              onTap: controller.onWaitingTap,
                            ),
                          if (!technician) ...[
                            MeRow(
                              key: const ValueKey('me-team'),
                              icon: LucideIcons.users,
                              label: LangKeys.meTeam.tr,
                              value: controller.stats.value?.team == null
                                  ? ''
                                  : LangKeys.mePeople.trParams({'n': '${controller.stats.value!.team}'}),
                              onTap: controller.onTeamTap,
                            ),
                            MeRow(
                              key: const ValueKey('me-company-settings'),
                              icon: LucideIcons.building,
                              label: LangKeys.meCompanySettings.tr,
                              onTap: controller.onCompanySettingsTap,
                            ),
                            MeRow(
                              key: const ValueKey('me-customers'),
                              icon: LucideIcons.briefcase,
                              label: LangKeys.meCustomers.tr,
                              value: '${controller.stats.value?.customers ?? ''}',
                              onTap: controller.onCustomersTap,
                            ),
                          ],
                          MeRow(
                            key: const ValueKey('me-language'),
                            icon: LucideIcons.globe,
                            label: LangKeys.meLanguage.tr,
                            value: controller.languageName,
                            onTap: controller.onLanguageTap,
                          ),
                          MeRow(
                            key: const ValueKey('me-messages'),
                            icon: LucideIcons.bell,
                            label: LangKeys.meMessages.tr,
                            badge: controller.unread.value,
                            onTap: controller.onMessagesTap,
                          ),
                        ],
                      ),
                      const SizedBox(height: KnSize.space24),
                      MeCard(
                        rows: [
                          MeRow(
                            key: const ValueKey('me-help'),
                            icon: LucideIcons.phone,
                            label: LangKeys.meHelp.tr,
                            onTap: controller.onComingSoonTap,
                          ),
                          MeRow(
                            key: const ValueKey('log-out'),
                            icon: LucideIcons.logOut,
                            label: LangKeys.commonLogOut.tr,
                            danger: true,
                            chevron: false,
                            onTap: _logout,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
}
