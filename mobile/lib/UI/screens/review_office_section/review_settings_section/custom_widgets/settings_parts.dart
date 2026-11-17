import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../../common_widgets/custom_inkwell.dart';
import '../../../../common_widgets/kn_custom_button.dart';
import '../../../../common_widgets/kn_screen_footer.dart';
import '../../../../commons/text_widgets/base/custom_base_text_widget.dart';
import '../../../../theme/kn_app_theme.dart';
import '../../../../theme/kn_tokens.g.dart';
import '../review_settings_controller.dart';

/// A white card with lines between its rows.
class SettingsCard extends StatelessWidget {
  const SettingsCard({super.key, required this.children, this.padding = EdgeInsets.zero});

  final List<Widget> children;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    return Container(
      padding: padding,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: kn.bgSurface,
        borderRadius: BorderRadius.circular(KnSize.radiusLg),
        border: Border.all(color: kn.borderDefault),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0 && padding == EdgeInsets.zero) Divider(height: 1, color: kn.borderDefault),
              children[i],
            ],
          ],
        ),
      ),
    );
  }
}

/// "Day 2" in a dark square.
class DayBadge extends StatelessWidget {
  const DayBadge({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    return Container(
      width: 52,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: kn.actionPrimary, borderRadius: BorderRadius.circular(KnSize.radiusMd)),
      child: CustomBaseTextWidget(label, style: context.knText.labelSm, color: kn.textOnAction),
    );
  }
}

/// A soft chip ("WhatsApp", "Customer's language"); with [onTap] it can be picked.
class SoftChip extends StatelessWidget {
  const SoftChip({super.key, required this.label, this.selected = true, this.onTap});

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final radius = BorderRadius.circular(KnSize.radiusFull);
    final chip = Ink(
      padding: const EdgeInsets.symmetric(horizontal: KnSize.space12, vertical: 6),
      decoration: BoxDecoration(
        color: selected ? kn.actionSecondary : kn.bgSurface,
        borderRadius: radius,
        border: Border.all(color: selected ? kn.actionSecondary : kn.borderDefault),
      ),
      child: CustomBaseTextWidget(label, style: context.knText.labelSm, color: selected ? kn.textPrimary : kn.textSecondary),
    );
    final tap = onTap;
    return tap == null ? chip : CustomInkWell(onTap: tap, borderRadius: radius, semanticLabel: label, child: chip);
  }
}

/// The footer with Save.
class SettingsSaveFooter extends StatelessWidget {
  const SettingsSaveFooter({super.key, required this.controller});

  final ReviewSettingsController controller;

  @override
  Widget build(BuildContext context) {
    return KnScreenFooter(
      children: [
        Obx(
          () => Align(
            alignment: Alignment.centerLeft,
            child: IntrinsicWidth(
              child: KnCustomButton(
                key: const ValueKey('review-settings-save'),
                text: LangKeys.commonSave.tr,
                icon: LucideIcons.check,
                loading: controller.saving.value,
                enabled: controller.canEdit && controller.dirty,
                onTap: controller.onSave,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
