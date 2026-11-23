import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../common_widgets/custom_inkwell.dart';
import '../../../common_widgets/kn_bottom_sheet.dart';
import '../../../common_widgets/kn_brand_mark.dart';
import '../../../common_widgets/kn_cover_image.dart';
import '../../../common_widgets/kn_custom_button.dart';
import '../../../common_widgets/kn_select_card.dart';
import '../../../common_widgets/kn_title_bar.dart';
import '../../../commons/behaviour/behaviour.dart';
import '../../../commons/text_widgets/base/custom_base_text_widget.dart';
import '../../../theme/kn_app_theme.dart';
import '../../../theme/kn_tokens.g.dart';
import 'company_settings_controller.dart';

/// M39 Company settings (Figma 49:1392).
class CompanySettingsScreen extends GetView<CompanySettingsController> {
  const CompanySettingsScreen({super.key});

  void _openTrades() {
    if (!controller.onTradeTap()) return;
    showKnBottomSheet<void>(
      title: LangKeys.settingsTrade.tr,
      child: ListView(
        shrinkWrap: true,
        children: [
          for (final t in controller.config.trades) ...[
            KnSelectCard(
              key: ValueKey('trade-${t.key}'),
              title: t.name,
              selected: controller.company?.trade == t.key,
              onTap: () => controller.onTradePicked(t),
            ),
            const SizedBox(height: KnSize.space8),
          ],
        ],
      ),
    );
  }

  void _openPhone() {
    if (!controller.onPhoneTap()) return;
    showKnBottomSheet<void>(
      title: LangKeys.settingsContactPhone.tr,
      child: Builder(
        builder: (context) {
          final kn = context.kn;
          final text = context.knText;
          return Obx(
            () => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CustomBaseTextWidget(LangKeys.settingsContactPhoneHint.tr, style: text.caption, color: kn.textSecondary),
                const SizedBox(height: KnSize.space12),
                TextField(
                  key: const ValueKey('settings-phone-box'),
                  controller: controller.phoneBox,
                  keyboardType: TextInputType.phone,
                  maxLength: 20,
                  autofocus: true,
                  style: text.body,
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: '+91 98250 00000',
                    filled: true,
                    fillColor: kn.bgSurface,
                    prefixIcon: Icon(LucideIcons.phone, size: 20, color: kn.textSecondary),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(KnSize.radiusMd)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(KnSize.radiusMd),
                      borderSide: BorderSide(color: kn.borderStrong),
                    ),
                  ),
                ),
                const SizedBox(height: KnSize.space16),
                KnCustomButton(
                  key: const ValueKey('settings-phone-save'),
                  text: LangKeys.commonSave.tr,
                  loading: controller.saving.value,
                  onTap: () async {
                    if (await controller.onPhoneSave()) Get.back<void>();
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _logo(double size) {
    final url = controller.logoUrl;
    return url == null
        ? KnBrandMark(size: size)
        : KnCoverImage(url: url, width: size, height: size, radius: size / 4, placeholderIcon: LucideIcons.image);
  }

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final text = context.knText;
    return Scaffold(
      backgroundColor: kn.bgCanvas,
      body: SafeArea(
        child: ScrollConfiguration(
          behavior: const KnScrollBehavior(),
          child: Obx(() {
            final owner = controller.isOwner;
            final planLine = controller.planLine;
            return ListView(
              padding: const EdgeInsets.fromLTRB(KnSize.space16, 12, KnSize.space16, KnSize.space24),
              children: [
                KnTitleBar(title: LangKeys.settingsTitle.tr, subtitle: LangKeys.settingsSubtitle.tr),
                const SizedBox(height: KnSize.space16),
                _Card(
                  child: Padding(
                    padding: const EdgeInsets.all(KnSize.space12),
                    child: Row(
                      children: [
                        _logo(56),
                        const SizedBox(width: KnSize.space12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CustomBaseTextWidget(controller.name, style: text.h3, maxLines: 2),
                              CustomBaseTextWidget(controller.meta, style: text.caption, color: kn.textSecondary),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: kn.statusWarningBg,
                                  borderRadius: BorderRadius.circular(KnSize.radiusFull),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(LucideIcons.lock, size: 14, color: kn.statusWarning),
                                    const SizedBox(width: 6),
                                    CustomBaseTextWidget(
                                      LangKeys.settingsOwnerOnly.tr,
                                      style: text.labelSm,
                                      color: kn.statusWarning,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: KnSize.space12),
                CustomBaseTextWidget(LangKeys.settingsCompany.tr, style: text.label, color: kn.textSecondary),
                const SizedBox(height: KnSize.space12),
                _Card(
                  child: Column(
                    children: [
                      _Row(
                        key: const ValueKey('settings-trade'),
                        icon: LucideIcons.briefcase,
                        label: LangKeys.settingsTrade.tr,
                        value: controller.tradeName,
                        onTap: _openTrades,
                      ),
                      _Row(
                        key: const ValueKey('settings-country'),
                        icon: LucideIcons.globe,
                        label: LangKeys.settingsCountry.tr,
                        value: controller.countryName,
                        chevron: false,
                        onTap: controller.onCountryTap,
                      ),
                      _Row(
                        key: const ValueKey('settings-logo'),
                        icon: LucideIcons.image,
                        label: LangKeys.settingsLogo.tr,
                        trailing: controller.savingLogo.value
                            ? const SizedBox.square(dimension: 24, child: CircularProgressIndicator(strokeWidth: 2.5))
                            : _logo(28),
                        onTap: controller.onLogoTap,
                      ),
                      _Row(
                        key: const ValueKey('settings-phone'),
                        icon: LucideIcons.phone,
                        label: LangKeys.settingsContactPhone.tr,
                        value: controller.contactPhone.isEmpty ? LangKeys.settingsContactPhoneNone.tr : controller.contactPhone,
                        onTap: _openPhone,
                      ),
                      _Row(
                        key: const ValueKey('settings-plan'),
                        icon: LucideIcons.star,
                        label: LangKeys.settingsPlan.tr,
                        sub: planLine,
                        value: controller.planValue,
                        divider: false,
                        onTap: controller.onPlanTap,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: KnSize.space12),
                CustomBaseTextWidget(LangKeys.settingsPermissions.tr, style: text.label, color: kn.textSecondary),
                const SizedBox(height: KnSize.space12),
                _Card(
                  child: Padding(
                    padding: const EdgeInsets.all(KnSize.space12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CustomInkWell(
                          key: const ValueKey('settings-tech-share'),
                          onTap: () => controller.onShareChanged(!controller.techniciansCanShare),
                          borderRadius: BorderRadius.circular(KnSize.radiusMd),
                          child: SizedBox(
                            height: 56,
                            child: Row(
                              children: [
                                IgnorePointer(
                                  child: Opacity(
                                    opacity: owner ? 1 : 0.6,
                                    child: Switch(
                                      value: controller.techniciansCanShare,
                                      onChanged: (_) {},
                                      activeThumbColor: kn.bgSurface,
                                      activeTrackColor: kn.actionPrimary,
                                      inactiveThumbColor: kn.bgSurface,
                                      inactiveTrackColor: kn.borderStrong,
                                      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: KnSize.space12),
                                Expanded(child: CustomBaseTextWidget(LangKeys.settingsTechShare.tr, style: text.body)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        CustomBaseTextWidget(LangKeys.settingsTechShareHelp.tr, style: text.caption, color: kn.textSecondary),
                      ],
                    ),
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

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: kn.bgSurface,
        borderRadius: BorderRadius.circular(KnSize.radiusLg),
        border: Border.all(color: kn.borderDefault),
        boxShadow: KnShadow.sm,
      ),
      child: Material(type: MaterialType.transparency, child: child),
    );
  }
}

/// A settings row: icon, label (and a small line), the value or a picture, and a chevron.
class _Row extends StatelessWidget {
  const _Row({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.value,
    this.sub,
    this.trailing,
    this.chevron = true,
    this.divider = true,
  });

  final IconData icon;
  final String label;
  final String? value;
  final String? sub;
  final Widget? trailing;
  final bool chevron;
  final bool divider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final text = context.knText;
    final small = sub;
    final shown = value;
    return CustomInkWell(
      onTap: onTap,
      semanticLabel: label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: KnSize.space12, vertical: 10),
        decoration: BoxDecoration(border: divider ? Border(bottom: BorderSide(color: kn.borderDefault)) : null),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(shape: BoxShape.circle, color: kn.bgSubtle),
              child: Icon(icon, size: 18, color: kn.textPrimary),
            ),
            const SizedBox(width: KnSize.space12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CustomBaseTextWidget(label, style: text.label),
                if (small != null) CustomBaseTextWidget(small, style: text.caption, color: kn.textSecondary),
              ],
            ),
            const SizedBox(width: KnSize.space12),
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: trailing ??
                    CustomBaseTextWidget(
                      shown ?? '',
                      style: text.body,
                      color: kn.textSecondary,
                      maxLines: 2,
                      textAlign: TextAlign.end,
                    ),
              ),
            ),
            if (chevron) ...[
              const SizedBox(width: KnSize.space8),
              Icon(LucideIcons.chevronRight, size: 20, color: kn.textSecondary),
            ],
          ],
        ),
      ),
    );
  }
}
