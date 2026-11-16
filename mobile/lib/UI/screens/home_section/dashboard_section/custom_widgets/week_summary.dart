import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../../../infrastructure/models/api_models.g.dart';
import '../../../../commons/text_widgets/base/custom_base_text_widget.dart';
import '../../../../theme/kn_app_theme.dart';
import '../../../../theme/kn_tokens.g.dart';
import '../dashboard_controller.dart';

/// M13 "This week · 38 reports sent · 12% more than last week" with the 7-day bars.
class WeekSummary extends StatelessWidget {
  const WeekSummary({
    super.key,
    required this.total,
    required this.week,
    required this.trend,
    required this.trendText,
    required this.dayLetter,
  });

  final int total;
  final List<DayCountModel> week;
  final WeekTrend trend;
  final String trendText;
  final String Function(DateTime day) dayLetter;

  @override
  Widget build(BuildContext context) {
    final text = context.knText;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CustomBaseTextWidget(LangKeys.dashThisWeek.tr, style: text.label, color: KnPrimitive.cream400),
              const SizedBox(height: KnSize.space4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  CustomBaseTextWidget('$total', style: text.display, color: KnPrimitive.cream50),
                  const SizedBox(width: KnSize.space8),
                  Flexible(
                    child: CustomBaseTextWidget(
                      LangKeys.dashReportsSent.tr,
                      style: text.body,
                      color: KnPrimitive.cream400,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
              if (trend != WeekTrend.none) ...[
                const SizedBox(height: KnSize.space4),
                Container(
                  key: const ValueKey('week-trend'),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: KnSize.space4),
                  decoration: BoxDecoration(
                    color: KnPrimitive.sage500.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(KnSize.radiusFull),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        trend == WeekTrend.less ? LucideIcons.chevronDown : LucideIcons.chevronRight,
                        size: 14,
                        color: KnPrimitive.sage100,
                      ),
                      const SizedBox(width: KnSize.space4),
                      Flexible(
                        child: CustomBaseTextWidget(
                          trendText,
                          style: text.labelSm,
                          color: KnPrimitive.sage100,
                          maxLines: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: KnSize.space8),
        Padding(padding: const EdgeInsets.only(top: 6), child: _bars(context)),
      ],
    );
  }

  Widget _bars(BuildContext context) {
    final most = week.fold<int>(0, (m, d) => d.reportsSent > m ? d.reportsSent : m);
    return SizedBox(
      width: 134,
      child: Column(
        children: [
          SizedBox(
            height: 52,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < week.length; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  Container(
                    width: 14,
                    height: most == 0 ? 6 : (6 + 46 * week[i].reportsSent / most),
                    decoration: BoxDecoration(
                      color: i == week.length - 1
                          ? KnPrimitive.mocha300
                          : KnPrimitive.cream100.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(KnSize.space4),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              for (var i = 0; i < week.length; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                SizedBox(
                  width: 14,
                  child: CustomBaseTextWidget(
                    dayLetter(DateTime.parse(week[i].date)),
                    style: context.knText.caption,
                    color: KnPrimitive.cream400,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
