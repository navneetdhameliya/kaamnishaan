import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../../../infrastructure/models/api_models.g.dart';
import '../../../../common_widgets/kn_cover_image.dart';
import '../../../../common_widgets/kn_custom_button.dart';
import '../../../../commons/text_widgets/base/custom_base_text_widget.dart';
import '../../../../theme/kn_app_theme.dart';
import '../../../../theme/kn_tokens.g.dart';

/// M12 "NOW · In progress" card: the job being worked on, its proof steps and "Continue job".
class NowJobCard extends StatelessWidget {
  const NowJobCard({super.key, required this.job, required this.time, required this.onContinue, this.offline = false});

  final JobListItemModel job;
  final String time;
  final VoidCallback onContinue;

  /// No internet: "Saved on phone" on the picture.
  final bool offline;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final text = context.knText;
    final proof = job.proof;
    final where = [job.site?.address, job.title].where((s) => s != null && s.isNotEmpty).join(' · ');
    return Container(
      key: const ValueKey('now-card'),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: kn.bgSurface,
        borderRadius: BorderRadius.circular(KnSize.radiusLg),
        boxShadow: KnShadow.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 112,
            child: Stack(
              fit: StackFit.expand,
              children: [
                KnCoverImage(url: job.coverUrl, height: 112),
                Positioned(left: 12, top: 12, child: _nowChip(context)),
                if (time.isNotEmpty) Positioned(right: 12, top: 12, child: _timeChip(context)),
                if (offline) Positioned(left: 12, bottom: 12, child: _savedChip(context)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(KnSize.space16, 14, KnSize.space16, KnSize.space16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CustomBaseTextWidget(job.customer.name, style: text.h2, maxLines: 1),
                const SizedBox(height: KnSize.space2),
                Row(
                  children: [
                    Icon(LucideIcons.mapPin, size: 16, color: kn.textSecondary),
                    const SizedBox(width: KnSize.space4),
                    Expanded(
                      child: CustomBaseTextWidget(where, style: text.body, color: kn.textSecondary, maxLines: 1),
                    ),
                  ],
                ),
                if (proof != null) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: CustomBaseTextWidget(LangKeys.todayProof.tr, style: text.labelSm, color: kn.textSecondary),
                      ),
                      CustomBaseTextWidget(
                        LangKeys.todayProofSteps.trParams({'done': '${proof.done}', 'total': '${proof.total}'}),
                        style: text.labelSm,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: proof.total == 0 ? 0 : proof.done / proof.total,
                      minHeight: 6,
                      backgroundColor: kn.bgSubtle,
                      color: kn.statusSuccess,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                KnCustomButton(
                  key: const ValueKey('continue-job'),
                  text: LangKeys.todayContinueJob.tr,
                  icon: LucideIcons.camera,
                  onTap: onContinue,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pill(BuildContext context, {required Color color, required List<Widget> children, EdgeInsets? padding}) =>
      Container(
        padding: padding ?? const EdgeInsets.symmetric(horizontal: 10, vertical: KnSize.space4),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(KnSize.radiusFull)),
        child: Row(mainAxisSize: MainAxisSize.min, children: children),
      );

  Widget _nowChip(BuildContext context) => _pill(
        context,
        color: KnPrimitive.cream50,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(color: KnPrimitive.green650, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          CustomBaseTextWidget(LangKeys.todayNow.tr, style: context.knText.labelSm, color: KnPrimitive.mocha950),
        ],
      );

  Widget _timeChip(BuildContext context) => _pill(
        context,
        color: KnPrimitive.mocha950.withValues(alpha: 0.75),
        children: [
          const Icon(LucideIcons.clock, size: 14, color: KnPrimitive.cream50),
          const SizedBox(width: KnSize.space4),
          CustomBaseTextWidget(time, style: context.knText.labelSm, color: KnPrimitive.cream50),
        ],
      );

  Widget _savedChip(BuildContext context) => _pill(
        context,
        color: context.kn.borderDefault,
        padding: const EdgeInsets.symmetric(horizontal: KnSize.space12, vertical: KnSize.space4),
        children: [
          Icon(LucideIcons.cloud, size: 16, color: context.kn.textSecondary),
          const SizedBox(width: KnSize.space4),
          CustomBaseTextWidget(LangKeys.todaySavedOnPhone.tr, style: context.knText.labelSm, color: context.kn.textSecondary),
        ],
      );
}
