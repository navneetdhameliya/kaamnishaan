import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../common_widgets/custom_inkwell.dart';
import '../../../../common_widgets/kn_cover_image.dart';
import '../../../../common_widgets/kn_job_status_pill.dart';
import '../../../../commons/text_widgets/base/custom_base_text_widget.dart';
import '../../../../theme/kn_app_theme.dart';
import '../../../../theme/kn_tokens.g.dart';

/// A round see-through button on the photo header (back, edit).
class HeaderButton extends StatelessWidget {
  const HeaderButton({super.key, required this.icon, required this.onTap, this.label});

  final IconData icon;
  final VoidCallback onTap;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return CustomInkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      semanticLabel: label,
      child: Ink(
        width: 44,
        height: 44,
        decoration: BoxDecoration(shape: BoxShape.circle, color: KnPrimitive.cream100.withValues(alpha: 0.12)),
        child: Icon(icon, size: 22, color: KnPrimitive.cream50),
      ),
    );
  }
}

/// One line of the contact card: what it is, the value, and a round action (call, email, map).
class ContactLine extends StatelessWidget {
  const ContactLine({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.onTap,
    this.empty = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback? onTap;
  final bool empty;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final text = context.knText;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: KnSize.space16, vertical: KnSize.space8),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: kn.borderDefault))),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CustomBaseTextWidget(label, style: text.caption, color: kn.textSecondary),
                CustomBaseTextWidget(
                  value,
                  style: empty ? text.body : text.label,
                  color: empty ? kn.textSecondary : kn.textPrimary,
                  maxLines: 2,
                ),
              ],
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: KnSize.space12),
            CustomInkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(20),
              semanticLabel: label,
              child: Ink(
                width: 40,
                height: 40,
                decoration: BoxDecoration(shape: BoxShape.circle, color: kn.bgSubtle),
                child: Icon(icon, size: 20, color: kn.textPrimary),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A past job: its photo, title, day and who did it, and its status.
class PastJobCard extends StatelessWidget {
  const PastJobCard({
    super.key,
    required this.title,
    required this.line,
    required this.status,
    required this.onTap,
    this.coverUrl,
  });

  final String title;
  final String line;
  final String status;
  final String? coverUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final text = context.knText;
    final radius = BorderRadius.circular(KnSize.radiusLg);
    return CustomInkWell(
      onTap: onTap,
      borderRadius: radius,
      semanticLabel: title,
      child: Ink(
        padding: const EdgeInsets.all(KnSize.space8),
        decoration: BoxDecoration(color: kn.bgSurface, borderRadius: radius, border: Border.all(color: kn.borderDefault)),
        child: Row(
          children: [
            KnCoverImage(url: coverUrl, width: 56, height: 56, radius: KnSize.radiusMd, placeholderIcon: LucideIcons.wrench),
            const SizedBox(width: KnSize.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CustomBaseTextWidget(title, style: text.label, maxLines: 2),
                  const SizedBox(height: 2),
                  CustomBaseTextWidget(line, style: text.caption, color: kn.textSecondary, maxLines: 1),
                ],
              ),
            ),
            const SizedBox(width: KnSize.space8),
            KnJobStatusPill(status: status),
          ],
        ),
      ),
    );
  }
}
