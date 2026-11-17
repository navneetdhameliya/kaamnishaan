import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../common_widgets/custom_inkwell.dart';
import '../../../../common_widgets/kn_cover_image.dart';
import '../../../../commons/text_widgets/base/custom_base_text_widget.dart';
import '../../../../theme/kn_app_theme.dart';
import '../../../../theme/kn_tokens.g.dart';
import '../messages_controller.dart';

/// One message: the job's picture with a small sign (new job, to review, changes, approved),
/// what happened, when, and a red dot while it is new.
class MessageCard extends StatelessWidget {
  const MessageCard({
    super.key,
    required this.title,
    required this.body,
    required this.when,
    required this.tone,
    required this.fresh,
    required this.onTap,
    this.coverUrl,
  });

  final String title;
  final String body;
  final String when;
  final MessageTone tone;
  final bool fresh;
  final VoidCallback onTap;
  final String? coverUrl;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final text = context.knText;
    final (Color color, IconData icon) = switch (tone) {
      MessageTone.job => (kn.actionPrimary, LucideIcons.briefcase),
      MessageTone.review => (kn.statusWarning, LucideIcons.clock),
      MessageTone.problem => (kn.statusDanger, LucideIcons.circleAlert),
      MessageTone.done => (kn.statusSuccess, LucideIcons.check),
    };
    return CustomInkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(KnSize.radiusLg),
      semanticLabel: '$title. $body',
      child: Container(
        padding: const EdgeInsets.all(KnSize.space12),
        decoration: BoxDecoration(
          color: kn.bgSurface,
          borderRadius: BorderRadius.circular(KnSize.radiusLg),
          border: Border.all(color: kn.borderDefault),
          boxShadow: KnShadow.sm,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 56,
              height: 60,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(KnSize.radiusMd),
                    child: KnCoverImage(url: coverUrl, width: 52, height: 52),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color,
                        border: Border.all(color: kn.bgSurface, width: 2),
                      ),
                      child: Icon(icon, size: 12, color: kn.textOnAction),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: KnSize.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: CustomBaseTextWidget(title, style: text.label, maxLines: 2)),
                      const SizedBox(width: KnSize.space8),
                      CustomBaseTextWidget(when, style: text.caption, color: kn.textSecondary),
                      if (fresh) ...[
                        const SizedBox(width: KnSize.space8),
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(shape: BoxShape.circle, color: kn.statusDanger),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  CustomBaseTextWidget(body, style: text.body, color: kn.textSecondary, maxLines: 3),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
