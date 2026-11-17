import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../../infrastructure/lang/translation_service.dart';
import '../../../../infrastructure/shared/text_utils.dart';
import '../../../common_widgets/custom_inkwell.dart';
import '../../../common_widgets/kn_bottom_sheet.dart';
import '../../../common_widgets/kn_country_picker_sheet.dart';
import '../../../common_widgets/kn_custom_button.dart';
import '../../../common_widgets/kn_custom_text_form_field.dart';
import '../../../common_widgets/kn_dropdown_field.dart';
import '../../../common_widgets/kn_initials_avatar.dart';
import '../../../common_widgets/kn_inline_error.dart';
import '../../../common_widgets/kn_screen_footer.dart';
import '../../../common_widgets/kn_select_card.dart';
import '../../../common_widgets/kn_text_link.dart';
import '../../../common_widgets/kn_title_bar.dart';
import '../../../commons/behaviour/behaviour.dart';
import '../../../commons/text_widgets/base/custom_base_text_widget.dart';
import '../../../theme/kn_app_theme.dart';
import '../../../theme/kn_tokens.g.dart';
import 'invite_controller.dart';

/// M40 Invite person (Figma 41:822; number problems 77:2084).
class InviteScreen extends GetView<InviteController> {
  const InviteScreen({super.key});

  void _openCountries() {
    showKnBottomSheet<void>(
      title: LangKeys.invitePhone.tr,
      child: KnCountryPickerSheet(
        countries: controller.config.countries,
        selected: controller.country.value,
        onSelected: controller.onCountrySelected,
      ),
    );
  }

  void _openLanguages() {
    showKnBottomSheet<void>(
      title: LangKeys.inviteLanguage.tr,
      child: ListView(
        shrinkWrap: true,
        children: [
          for (final l in TranslationService.languages) ...[
            Obx(
              () => KnSelectCard(
                key: ValueKey('sms-lang-${l.code}'),
                title: l.nativeName,
                selected: controller.smsLanguage.value == l.code,
                onTap: () => controller.onLanguagePicked(l.code),
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
    return Scaffold(
      backgroundColor: kn.bgCanvas,
      bottomNavigationBar: KnScreenFooter(
        children: [
          Obx(
            () => KnCustomButton(
              key: const ValueKey('invite-send'),
              text: LangKeys.inviteSend.tr,
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
            final phoneError = controller.phoneError;
            final see = controller.seeInTeam;
            return ListView(
              padding: const EdgeInsets.fromLTRB(KnSize.space16, 12, KnSize.space16, KnSize.space24),
              children: [
                KnTitleBar(
                  buttonKey: const ValueKey('invite-close'),
                  title: LangKeys.inviteTitle.tr,
                  subtitle: LangKeys.inviteSubtitle.tr,
                  icon: LucideIcons.x,
                ),
                const SizedBox(height: KnSize.space16),
                CustomBaseTextWidget(LangKeys.inviteRole.tr, style: text.label),
                const SizedBox(height: KnSize.space8),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: kn.actionSecondary, borderRadius: BorderRadius.circular(KnSize.radiusFull)),
                  child: Row(
                    children: [
                      for (final r in const ['technician', 'manager'])
                        Expanded(
                          child: Opacity(
                            opacity: r == 'manager' && !controller.canInviteManager ? 0.5 : 1,
                            child: CustomInkWell(
                              key: ValueKey('invite-role-$r'),
                              onTap: r == 'manager' && !controller.canInviteManager ? null : () => controller.onRoleTap(r),
                              borderRadius: BorderRadius.circular(KnSize.radiusFull),
                              child: Container(
                                height: 40,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: controller.role.value == r ? kn.bgSurface : null,
                                  borderRadius: BorderRadius.circular(KnSize.radiusFull),
                                  boxShadow: controller.role.value == r ? KnShadow.sm : null,
                                ),
                                child: CustomBaseTextWidget(
                                  r == 'manager' ? LangKeys.roleManager.tr : LangKeys.roleTechnician.tr,
                                  style: text.label,
                                  color: controller.role.value == r ? kn.textPrimary : kn.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: KnSize.space12),
                CustomBaseTextWidget(LangKeys.invitePhone.tr, style: text.label),
                const SizedBox(height: KnSize.space8),
                Row(
                  children: [
                    CustomInkWell(
                      key: const ValueKey('invite-country'),
                      onTap: controller.config.countries.isEmpty ? null : _openCountries,
                      borderRadius: BorderRadius.circular(KnSize.radiusLg),
                      semanticLabel: controller.country.value.dialCode,
                      child: Ink(
                        height: KnSize.tapTechnician,
                        padding: const EdgeInsets.symmetric(horizontal: KnSize.space12),
                        decoration: BoxDecoration(
                          color: kn.bgSurface,
                          borderRadius: BorderRadius.circular(KnSize.radiusLg),
                          border: Border.all(color: kn.borderDefault),
                        ),
                        child: Row(
                          children: [
                            Text(controller.country.value.flag, style: const TextStyle(fontSize: 20)),
                            const SizedBox(width: 6),
                            CustomBaseTextWidget(controller.country.value.dialCode, style: text.label),
                            const SizedBox(width: 4),
                            Icon(LucideIcons.chevronDown, size: 18, color: kn.textSecondary),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: KnSize.space8),
                    Expanded(
                      child: TextField(
                        key: const ValueKey('invite-phone'),
                        controller: controller.phone,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9 ]')), LengthLimitingTextInputFormatter(17)],
                        onChanged: controller.onPhoneChanged,
                        style: text.body,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: kn.bgSurface,
                          contentPadding: const EdgeInsets.symmetric(horizontal: KnSize.space16, vertical: 16),
                          suffixIcon: Icon(LucideIcons.phone, size: 20, color: kn.textSecondary),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(KnSize.radiusLg),
                            borderSide: BorderSide(
                              color: phoneError != null ? kn.statusDanger : kn.borderStrong,
                              width: phoneError != null ? 2 : 1,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(KnSize.radiusLg),
                            borderSide: BorderSide(color: phoneError != null ? kn.statusDanger : kn.focusRing, width: 2),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (phoneError != null) ...[
                  const SizedBox(height: KnSize.space8),
                  KnInlineError(message: phoneError),
                ],
                if (see != null) ...[
                  const SizedBox(height: KnSize.space8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: KnTextLink(
                      key: const ValueKey('invite-see-in-team'),
                      text: see,
                      chevron: true,
                      onTap: controller.onSeeInTeamTap,
                    ),
                  ),
                ],
                const SizedBox(height: KnSize.space12),
                KnCustomTextFormField(
                  fieldKey: const ValueKey('invite-name'),
                  label: LangKeys.inviteName.tr,
                  controller: controller.name,
                  focusNode: controller.nameFocus,
                  textCapitalization: TextCapitalization.words,
                  onChanged: controller.onNameChanged,
                  errorText: controller.nameError,
                  trailing: CustomInkWell(
                    key: const ValueKey('invite-name-mic'),
                    onTap: controller.onNameMicTap,
                    borderRadius: BorderRadius.circular(20),
                    child: Ink(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(color: kn.bgSubtle, borderRadius: BorderRadius.circular(20)),
                      child: Icon(LucideIcons.mic, size: 22, color: kn.textPrimary),
                    ),
                  ),
                ),
                const SizedBox(height: KnSize.space12),
                KnDropdownField(
                  key: const ValueKey('invite-language'),
                  label: LangKeys.inviteLanguage.tr,
                  value: controller.languageName,
                  onTap: _openLanguages,
                ),
                if (controller.preview.value.isNotEmpty) ...[
                  const SizedBox(height: KnSize.space12),
                  CustomBaseTextWidget(controller.willGet, style: text.label, color: kn.textSecondary),
                  const SizedBox(height: KnSize.space12),
                  Container(
                    key: const ValueKey('invite-preview'),
                    padding: const EdgeInsets.all(KnSize.space12),
                    decoration: BoxDecoration(
                      color: kn.bgSubtle,
                      border: Border.all(color: kn.borderDefault),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(4),
                        topRight: Radius.circular(KnSize.radiusLg),
                        bottomLeft: Radius.circular(KnSize.radiusLg),
                        bottomRight: Radius.circular(KnSize.radiusLg),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CustomBaseTextWidget(controller.preview.value, style: text.body),
                        const SizedBox(height: KnSize.space8),
                        Row(
                          children: [
                            KnInitialsAvatar(
                              initials: TextUtils.initials(controller.inviter),
                              url: controller.session.me.value?.avatarUrl,
                              size: 20,
                              borderWidth: 0,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: CustomBaseTextWidget(
                                controller.inviterLine,
                                style: text.caption,
                                color: kn.textSecondary,
                                maxLines: 1,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
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
