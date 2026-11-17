import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../../common_widgets/custom_inkwell.dart';
import '../../../../common_widgets/kn_custom_button.dart';
import '../../../../commons/text_widgets/base/custom_base_text_widget.dart';
import '../../../../theme/kn_app_theme.dart';
import '../../../../theme/kn_tokens.g.dart';

/// Who gets the report, with "Change".
class RecipientCard extends StatelessWidget {
  const RecipientCard({
    super.key,
    required this.initials,
    required this.name,
    required this.contact,
    required this.error,
    required this.onChange,
  });

  final String initials;
  final String name;
  final String contact;
  final bool error;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final text = context.knText;
    return Container(
      padding: const EdgeInsets.all(KnSize.space12),
      decoration: BoxDecoration(
        color: kn.bgSurface,
        borderRadius: BorderRadius.circular(KnSize.radiusLg),
        border: Border.all(color: error ? kn.statusDanger : kn.borderDefault, width: error ? 1.5 : 1),
        boxShadow: KnShadow.sm,
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(shape: BoxShape.circle, color: kn.statusSuccessBg),
            child: CustomBaseTextWidget(initials, style: text.label, color: kn.statusSuccess),
          ),
          const SizedBox(width: KnSize.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CustomBaseTextWidget(name, style: text.label, maxLines: 1),
                CustomBaseTextWidget(
                  contact.isEmpty ? LangKeys.shareNoContact.tr : contact,
                  style: text.caption,
                  color: contact.isEmpty ? kn.statusDanger : kn.textSecondary,
                  maxLines: 1,
                ),
              ],
            ),
          ),
          CustomInkWell(
            key: const ValueKey('share-change'),
            onTap: onChange,
            borderRadius: BorderRadius.circular(KnSize.radiusSm),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: CustomBaseTextWidget(
                contact.isEmpty ? LangKeys.shareEdit.tr : LangKeys.shareChange.tr,
                style: text.label,
                color: kn.textLink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// SMS / Email / WhatsApp / More.
class ChannelTile extends StatelessWidget {
  const ChannelTile({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: CustomInkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(KnSize.radiusLg),
        semanticLabel: label,
        child: Container(
          height: 84,
          decoration: BoxDecoration(
            color: kn.bgSurface,
            borderRadius: BorderRadius.circular(KnSize.radiusLg),
            border: Border.all(color: selected ? kn.textPrimary : kn.borderDefault, width: selected ? 2 : 1),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(shape: BoxShape.circle, color: selected ? kn.actionPrimary : kn.actionSecondary),
                child: Icon(icon, size: 18, color: selected ? kn.textOnAction : kn.textPrimary),
              ),
              const SizedBox(height: 6),
              CustomBaseTextWidget(label, style: context.knText.captionStrong, maxLines: 1),
            ],
          ),
        ),
      ),
    );
  }
}

/// The secure link: copy it, or turn it off.
class LinkCard extends StatelessWidget {
  const LinkCard({super.key, required this.linkText, required this.busy, required this.onCopy, this.onTurnOff});

  final String linkText;
  final bool busy;
  final VoidCallback onCopy;
  final VoidCallback? onTurnOff;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final text = context.knText;
    final has = linkText.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(KnSize.space12),
      decoration: BoxDecoration(
        color: kn.bgSurface,
        borderRadius: BorderRadius.circular(KnSize.radiusLg),
        border: Border.all(color: kn.borderDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(shape: BoxShape.circle, color: kn.statusSuccessBg),
                child: Icon(LucideIcons.link, size: 18, color: kn.statusSuccess),
              ),
              const SizedBox(width: KnSize.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CustomBaseTextWidget(LangKeys.shareSecure.tr, style: text.caption, color: kn.textSecondary),
                    CustomBaseTextWidget(has ? linkText : LangKeys.shareNoLink.tr, style: text.label, maxLines: 1),
                  ],
                ),
              ),
              KnCustomButton(
                key: const ValueKey('share-copy'),
                text: has ? LangKeys.shareCopy.tr : LangKeys.shareMakeLink.tr,
                variant: KnButtonVariant.secondary,
                small: true,
                loading: busy,
                onTap: onCopy,
              ),
            ],
          ),
          const SizedBox(height: KnSize.space8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(LucideIcons.lock, size: 14, color: kn.textSecondary),
              ),
              const SizedBox(width: KnSize.space8),
              Expanded(child: CustomBaseTextWidget(LangKeys.shareWorks.tr, style: text.caption, color: kn.textSecondary)),
            ],
          ),
          if (onTurnOff != null) ...[
            const SizedBox(height: KnSize.space8),
            CustomInkWell(
              key: const ValueKey('share-turn-off'),
              onTap: onTurnOff!,
              borderRadius: BorderRadius.circular(KnSize.radiusSm),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.x, size: 16, color: kn.statusDanger),
                    const SizedBox(width: 6),
                    CustomBaseTextWidget(LangKeys.shareTurnOff.tr, style: text.label, color: kn.statusDanger),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
