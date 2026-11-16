import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../common_widgets/custom_inkwell.dart';
import '../../../common_widgets/kn_bottom_sheet.dart';
import '../../../common_widgets/kn_custom_button.dart';
import '../../../common_widgets/kn_custom_text_form_field.dart';
import '../../../common_widgets/kn_dropdown_field.dart';
import '../../../common_widgets/kn_initials_avatar.dart';
import '../../../common_widgets/kn_page_scaffold.dart';
import '../../../common_widgets/kn_screen_footer.dart';
import '../../../common_widgets/kn_select_card.dart';
import '../../../commons/text_widgets/base/custom_base_text_widget.dart';
import '../../../theme/kn_app_theme.dart';
import '../../../theme/kn_tokens.g.dart';
import 'profile_setup_controller.dart';

/// M11 Profile setup (Figma 16:958; name missing 73:2297).
class ProfileSetupScreen extends GetView<ProfileSetupController> {
  const ProfileSetupScreen({super.key});

  void _openTrades() {
    showKnBottomSheet<void>(
      title: LangKeys.profileWorkLabel.tr,
      child: ListView(
        shrinkWrap: true,
        children: [
          for (final t in controller.config.trades) ...[
            Obx(
              () => KnSelectCard(
                title: t.name,
                selected: controller.trade.value?.key == t.key,
                onTap: () => controller.onTradeSelected(t),
              ),
            ),
            const SizedBox(height: KnSize.space8),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final text = context.knText;
    return KnPageScaffold(
      showBack: Navigator.of(context).canPop(),
      footer: KnScreenFooter(
        children: [
          Obx(
            () => KnCustomButton(
              key: const ValueKey('save-profile'),
              text: LangKeys.profileSaveStart.tr,
              icon: LucideIcons.check,
              enabled: controller.isValid,
              loading: controller.apiCallLoader.value,
              onTap: controller.callSaveProfileAPI,
              onDisabledTap: controller.onDisabledSaveTap,
            ),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: KnSize.space12),
          CustomBaseTextWidget(LangKeys.profileTitle.tr, style: text.h1),
          const SizedBox(height: KnSize.space4),
          CustomBaseTextWidget(LangKeys.profileSubtitle.tr, style: text.bodyLg, color: kn.textSecondary),
          const SizedBox(height: KnSize.space8),
          Center(
            child: Column(
              children: [
                SizedBox(
                  width: 116,
                  height: 116,
                  child: Stack(
                    children: [
                      Obx(() {
                        final picked = controller.photo.value;
                        final saved = controller.savedPhotoUrl;
                        final ImageProvider? image =
                            picked != null ? MemoryImage(picked.bytes) : (saved != null ? NetworkImage(saved) : null);
                        return KnInitialsAvatar(
                          key: const ValueKey('profile-avatar'),
                          size: 112,
                          borderWidth: 3,
                          initials: controller.initials,
                          image: image,
                        );
                      }),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: CustomInkWell(
                          onTap: controller.onChangePhotoTap,
                          borderRadius: BorderRadius.circular(20),
                          child: Ink(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: kn.actionPrimary,
                              shape: BoxShape.circle,
                              border: Border.all(color: kn.bgCanvas, width: 2),
                            ),
                            child: Icon(LucideIcons.camera, size: 20, color: kn.textOnAction),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                CustomInkWell(
                  onTap: controller.onChangePhotoTap,
                  borderRadius: BorderRadius.circular(KnSize.radiusSm),
                  child: Padding(
                    padding: const EdgeInsets.all(KnSize.space8),
                    child: CustomBaseTextWidget(LangKeys.profileChangePhoto.tr, style: text.label, color: kn.textLink),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: KnSize.space16),
          Obx(
            () => KnCustomTextFormField(
              key: const ValueKey('name-field'),
              label: LangKeys.profileNameLabel.tr,
              controller: controller.nameController,
              focusNode: controller.nameFocusNode,
              onChanged: controller.onNameChanged,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.done,
              errorText: controller.showNameError.value ? LangKeys.profileNameMissing.tr : null,
              onHearError: controller.onHearErrorTap,
              trailing: CustomInkWell(
                onTap: controller.onMicTap,
                borderRadius: BorderRadius.circular(KnSize.radiusMd),
                child: Ink(
                  width: 32,
                  height: 40,
                  decoration: BoxDecoration(color: kn.bgSubtle, borderRadius: BorderRadius.circular(KnSize.radiusMd)),
                  child: Icon(LucideIcons.mic, size: 20, color: kn.textPrimary),
                ),
              ),
            ),
          ),
          const SizedBox(height: KnSize.space16),
          Obx(
            () => KnDropdownField(
              label: LangKeys.profileWorkLabel.tr,
              value: controller.trade.value?.name ?? '',
              onTap: controller.config.trades.isEmpty ? null : _openTrades,
            ),
          ),
          const SizedBox(height: KnSize.space16),
          KnCustomTextFormField(
            label: LangKeys.profilePhoneLabel.tr,
            initialValue: controller.phoneText,
            readOnly: true,
          ),
          const SizedBox(height: KnSize.space24),
        ],
      ),
    );
  }
}
