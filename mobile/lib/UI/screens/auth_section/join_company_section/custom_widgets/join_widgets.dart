import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../common_widgets/custom_inkwell.dart';
import '../../../../commons/text_widgets/base/custom_base_text_widget.dart';
import '../../../../theme/kn_app_theme.dart';
import '../../../../theme/kn_tokens.g.dart';

/// Company logo square (80 × 80). Uses the company's logo, or its name on brand brown.
class CompanyLogo extends StatelessWidget {
  const CompanyLogo({super.key, required this.name, this.logoUrl, this.faded = false, this.alert = false});

  final String name;
  final String? logoUrl;
  final bool faded;
  final bool alert;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final box = ClipRRect(
      borderRadius: BorderRadius.circular(KnSize.radiusXl),
      child: Container(
        width: 80,
        height: 80,
        color: KnPrimitive.mocha900,
        alignment: Alignment.center,
        child: logoUrl != null
            ? Image.network(logoUrl!, width: 80, height: 80, fit: BoxFit.cover)
            : Padding(
                padding: const EdgeInsets.all(KnSize.space8),
                child: CustomBaseTextWidget(
                  name,
                  style: context.knText.labelSm,
                  color: KnPrimitive.cream100,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                ),
              ),
      ),
    );
    return SizedBox(
      width: 88,
      height: 88,
      child: Stack(
        children: [
          Opacity(opacity: faded ? 0.55 : 1, child: box),
          if (alert)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: kn.statusDanger,
                  shape: BoxShape.circle,
                  border: Border.all(color: kn.bgCanvas, width: 3),
                ),
                child: Icon(LucideIcons.circleAlert, size: 16, color: kn.textOnAction),
              ),
            ),
        ],
      ),
    );
  }
}

/// White rounded card used on M10.
class JoinCard extends StatelessWidget {
  const JoinCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(KnSize.space16),
        decoration: BoxDecoration(
          color: context.kn.bgSurface,
          borderRadius: BorderRadius.circular(KnSize.radiusLg),
          border: Border.all(color: context.kn.borderDefault),
          boxShadow: KnShadow.sm,
        ),
        child: child,
      );
}

/// "Priya Mehta invited you · 2 days ago" with a tick or a call button.
class InviterRow extends StatelessWidget {
  const InviterRow({super.key, required this.title, required this.subtitle, this.onCall});

  final String title;
  final String subtitle;
  final VoidCallback? onCall;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final initials = title.trim().isEmpty ? '?' : title.trim()[0].toUpperCase();
    return Row(
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: kn.bgSubtle,
          child: CustomBaseTextWidget(initials, style: context.knText.h3),
        ),
        const SizedBox(width: KnSize.space12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CustomBaseTextWidget(title, style: context.knText.label),
              CustomBaseTextWidget(subtitle, style: context.knText.caption, color: kn.textSecondary),
            ],
          ),
        ),
        if (onCall != null)
          CustomInkWell(
            onTap: onCall,
            borderRadius: BorderRadius.circular(22),
            child: Ink(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: kn.bgSubtle, shape: BoxShape.circle),
              child: Icon(LucideIcons.phone, size: 20, color: kn.textPrimary),
            ),
          )
        else
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(color: kn.statusSuccessBg, shape: BoxShape.circle),
            child: Icon(LucideIcons.check, size: 16, color: kn.statusSuccess),
          ),
      ],
    );
  }
}

/// One "When you join" line: icon in a soft circle, then the text.
class BenefitRow extends StatelessWidget {
  const BenefitRow({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: KnSize.space12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: context.kn.bgSubtle, shape: BoxShape.circle),
              child: Icon(icon, size: 18, color: context.kn.textPrimary),
            ),
            const SizedBox(width: KnSize.space12),
            Expanded(child: CustomBaseTextWidget(text, style: context.knText.body)),
          ],
        ),
      );
}
