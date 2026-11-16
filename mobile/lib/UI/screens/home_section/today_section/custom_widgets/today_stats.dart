import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../../common_widgets/common_shimmer.dart';
import '../../../../commons/text_widgets/base/custom_base_text_widget.dart';
import '../../../../theme/kn_app_theme.dart';
import '../../../../theme/kn_tokens.g.dart';

/// M12 header numbers: jobs today, done, photos. [loading] shows grey blocks.
class TodayStats extends StatelessWidget {
  const TodayStats({super.key, required this.jobs, required this.done, required this.photos, this.loading = false});

  final int jobs;
  final int done;
  final int photos;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final cells = [
      (LucideIcons.briefcase, jobs, LangKeys.todayJobs.tr),
      (LucideIcons.check, done, LangKeys.todayDone.tr),
      (LucideIcons.camera, photos, LangKeys.todayPhotos.tr),
    ];
    return Row(
      children: [
        for (var i = 0; i < cells.length; i++) ...[
          if (i > 0) const SizedBox(width: KnSize.space8),
          Expanded(child: _cell(context, cells[i].$1, cells[i].$2, cells[i].$3)),
        ],
      ],
    );
  }

  Widget _cell(BuildContext context, IconData icon, int value, String label) {
    final text = context.knText;
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: KnSize.space12, vertical: 10),
      decoration: BoxDecoration(
        color: KnPrimitive.cream100.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(KnSize.radiusMd),
      ),
      child: loading
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _block(40, 24),
                const SizedBox(height: 8),
                _block(64, 10),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 16, color: KnPrimitive.cream400),
                    const SizedBox(width: 6),
                    CustomBaseTextWidget('$value', style: text.h2, color: KnPrimitive.cream50),
                  ],
                ),
                const SizedBox(height: 2),
                CustomBaseTextWidget(label, style: text.caption, color: KnPrimitive.cream400, maxLines: 1),
              ],
            ),
    );
  }

  Widget _block(double w, double h) => Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          color: KnPrimitive.cream100.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(KnSize.radiusSm),
        ),
      );
}

/// Grey blocks in the shape of the Now card and two job rows, while Today loads (Figma 20:977).
class TodaySkeleton extends StatelessWidget {
  const TodaySkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    Widget card({required Widget child}) => Container(
          decoration: BoxDecoration(
            color: kn.bgSurface,
            borderRadius: BorderRadius.circular(KnSize.radiusLg),
            border: Border.all(color: kn.borderDefault),
          ),
          clipBehavior: Clip.antiAlias,
          child: child,
        );
    Widget row() => card(
          child: const Padding(
            padding: EdgeInsets.all(KnSize.space8),
            child: Row(
              children: [
                CommonShimmer(width: 56, height: 56, radius: 12),
                SizedBox(width: KnSize.space12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CommonShimmer(width: 150, height: 16, radius: 8),
                      SizedBox(height: 10),
                      CommonShimmer(width: 100, height: 12, radius: 6),
                    ],
                  ),
                ),
                CommonShimmer(width: 64, height: 28, radius: 14),
              ],
            ),
          ),
        );
    return Column(
      key: const ValueKey('today-loading'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        card(
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CommonShimmer(height: 112, radius: 0),
              Padding(
                padding: EdgeInsets.all(KnSize.space16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CommonShimmer(width: 220, height: 24, radius: 12),
                    SizedBox(height: 16),
                    CommonShimmer(width: 260, height: 16, radius: 8),
                    SizedBox(height: 16),
                    CommonShimmer(height: 6, radius: 3),
                    SizedBox(height: 16),
                    CommonShimmer(height: 56, radius: KnSize.radiusLg),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: KnSize.space16),
        Row(
          children: [
            Expanded(child: CustomBaseTextWidget(LangKeys.todayNextUp.tr, style: context.knText.h3)),
            Icon(LucideIcons.refreshCw, size: 16, color: kn.textSecondary),
            const SizedBox(width: 6),
            CustomBaseTextWidget(LangKeys.todayLoading.tr, style: context.knText.labelSm, color: kn.textSecondary),
          ],
        ),
        const SizedBox(height: 10),
        row(),
        const SizedBox(height: 10),
        row(),
      ],
    );
  }
}
