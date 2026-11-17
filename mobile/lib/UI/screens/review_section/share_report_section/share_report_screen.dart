import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../../infrastructure/shared/text_utils.dart';
import '../../../common_widgets/common_shimmer.dart';
import '../../../common_widgets/custom_inkwell.dart';
import '../../../common_widgets/kn_cover_image.dart';
import '../../../common_widgets/kn_custom_button.dart';
import '../../../common_widgets/kn_screen_footer.dart';
import '../../../commons/behaviour/behaviour.dart';
import '../../../commons/text_widgets/base/custom_base_text_widget.dart';
import '../../../theme/kn_app_theme.dart';
import '../../../theme/kn_tokens.g.dart';
import 'custom_widgets/share_parts.dart';
import 'share_report_controller.dart';

/// M35 Share report (Figma 48:1431; no contact 77:2326).
class ShareReportScreen extends GetView<ShareReportController> {
  const ShareReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final text = context.knText;
    return Scaffold(
      backgroundColor: kn.bgCanvas,
      bottomNavigationBar: KnScreenFooter(
        children: [
          Obx(
            () => KnCustomButton(
              key: const ValueKey('share-send'),
              text: LangKeys.shareSend.tr,
              enabled: controller.canSend,
              loading: controller.sending.value,
              onTap: controller.onSendTap,
            ),
          ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: ScrollConfiguration(
          behavior: const KnScrollBehavior(),
          child: Obx(() {
            final info = controller.info.value;
            return ListView(
              padding: const EdgeInsets.fromLTRB(KnSize.space16, 12, KnSize.space16, KnSize.space24),
              children: [
                Row(
                  children: [
                    CustomInkWell(
                      key: const ValueKey('share-close'),
                      onTap: Get.back,
                      borderRadius: BorderRadius.circular(22),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: kn.bgSurface,
                          border: Border.all(color: kn.borderDefault),
                        ),
                        child: Icon(LucideIcons.x, size: 20, color: kn.textPrimary),
                      ),
                    ),
                    const SizedBox(width: KnSize.space12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CustomBaseTextWidget(LangKeys.shareTitle.tr, style: text.h3),
                          CustomBaseTextWidget(controller.subtitle, style: text.caption, color: kn.textSecondary, maxLines: 1),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: KnSize.space16),
                if (info == null) ...const [
                  CommonShimmer(height: 72, radius: KnSize.radiusLg),
                  SizedBox(height: KnSize.space16),
                  CommonShimmer(height: 220, radius: KnSize.radiusLg),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(KnSize.space12),
                    decoration: BoxDecoration(color: kn.actionSecondary, borderRadius: BorderRadius.circular(KnSize.radiusLg)),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(KnSize.radiusMd),
                          child: KnCoverImage(url: controller.args.coverUrl, width: 48, height: 48),
                        ),
                        const SizedBox(width: KnSize.space12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CustomBaseTextWidget(
                                LangKeys.sharePdfTitle.trParams({'n': '${controller.pages}'}),
                                style: text.label,
                              ),
                              CustomBaseTextWidget(controller.pdfMeta, style: text.caption, color: kn.textSecondary, maxLines: 1),
                            ],
                          ),
                        ),
                        Icon(LucideIcons.check, size: 20, color: kn.statusSuccess),
                      ],
                    ),
                  ),
                  const SizedBox(height: KnSize.space16),
                  CustomBaseTextWidget(LangKeys.shareSendTo.tr, style: text.label),
                  const SizedBox(height: KnSize.space8),
                  RecipientCard(
                    initials: TextUtils.initials(controller.name),
                    name: controller.name,
                    contact: controller.contactLine,
                    error: controller.contactError.value != null,
                    onChange: controller.onEditContactTap,
                  ),
                  if (controller.contactError.value != null) ...[
                    const SizedBox(height: KnSize.space8),
                    Row(
                      children: [
                        Icon(LucideIcons.circleAlert, size: 16, color: kn.statusDanger),
                        const SizedBox(width: 6),
                        Expanded(
                          child: CustomBaseTextWidget(
                            LangKeys.shareNoContactBody.tr,
                            style: text.captionStrong,
                            color: kn.statusDanger,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (controller.editing.value) ...[
                    const SizedBox(height: KnSize.space12),
                    CustomBaseTextWidget(LangKeys.shareAddContact.tr, style: text.label),
                    const SizedBox(height: KnSize.space8),
                    TextField(
                      key: const ValueKey('share-contact'),
                      controller: controller.contact,
                      keyboardType: TextInputType.emailAddress,
                      onChanged: controller.onContactChanged,
                      style: text.body,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: kn.bgSurface,
                        hintText: '+91 98250 11111 · name@email.com',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(KnSize.radiusMd)),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(KnSize.radiusMd),
                          borderSide: BorderSide(color: kn.borderStrong),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: KnSize.space16),
                  CustomBaseTextWidget(LangKeys.shareSendBy.tr, style: text.label),
                  const SizedBox(height: KnSize.space8),
                  Row(
                    children: [
                      for (final (key, icon, label) in [
                        ('sms', LucideIcons.messageCircle, LangKeys.shareSms.tr),
                        ('email', LucideIcons.mail, LangKeys.shareEmail.tr),
                        ('whatsapp', LucideIcons.phone, LangKeys.shareWhatsapp.tr),
                      ]) ...[
                        Expanded(
                          child: ChannelTile(
                            key: ValueKey('share-channel-$key'),
                            icon: icon,
                            label: label,
                            selected: controller.picked.contains(key),
                            enabled: controller.available(key),
                            onTap: () => controller.onChannelTap(key),
                          ),
                        ),
                        const SizedBox(width: KnSize.space8),
                      ],
                      Expanded(
                        child: ChannelTile(
                          key: const ValueKey('share-channel-more'),
                          icon: LucideIcons.ellipsis,
                          label: LangKeys.shareMore.tr,
                          selected: false,
                          enabled: true,
                          onTap: controller.onMoreTap,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: KnSize.space16),
                  LinkCard(
                    linkText: controller.linkText,
                    busy: controller.linkBusy.value,
                    onCopy: controller.onCopyTap,
                    onTurnOff: controller.link == null ? null : controller.onTurnOffTap,
                  ),
                ],
              ],
            );
          }),
        ),
      ),
    );
  }
}
