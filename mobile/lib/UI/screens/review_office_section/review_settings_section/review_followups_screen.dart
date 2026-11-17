import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../common_widgets/common_shimmer.dart';
import '../../../common_widgets/kn_switch_row.dart';
import '../../../common_widgets/kn_title_bar.dart';
import '../../../commons/behaviour/behaviour.dart';
import '../../../commons/text_widgets/base/custom_base_text_widget.dart';
import '../../../theme/kn_app_theme.dart';
import '../../../theme/kn_tokens.g.dart';
import 'custom_widgets/settings_parts.dart';
import 'review_settings_controller.dart';

/// M46 Review follow-ups (Figma 274:2569): Day 0 with the report, the Day 2 reminder, the Day 5 AI
/// call, and whether technicians may ask.
class ReviewFollowupsScreen extends GetView<ReviewSettingsController> {
  const ReviewFollowupsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final text = context.knText;
    return Scaffold(
      backgroundColor: kn.bgCanvas,
      body: SafeArea(
        bottom: false,
        child: ScrollConfiguration(
          behavior: const KnScrollBehavior(),
          child: Obx(() {
            final c = controller;
            return ListView(
              padding: const EdgeInsets.fromLTRB(KnSize.space16, 12, KnSize.space16, KnSize.space24),
              children: [
                KnTitleBar(title: LangKeys.crevFollowups.tr, subtitle: LangKeys.rsetSubtitle.tr),
                const SizedBox(height: KnSize.space16),
                if (!c.loaded)
                  const CommonShimmer(height: 420, radius: KnSize.radiusLg)
                else ...[
                  _Step(
                    day: c.day(0),
                    title: LangKeys.rfuWithReport.tr,
                    subtitle: LangKeys.rfuWithReportSub.tr,
                    trailing: Padding(
                      padding: const EdgeInsets.only(top: 4, right: 4),
                      child: Icon(LucideIcons.lock, size: 20, color: kn.textSecondary),
                    ),
                    chips: [
                      for (final ch in ReviewSettingsController.channels) SoftChip(label: c.channelLabel(ch)),
                    ],
                  ),
                  const SizedBox(height: KnSize.space12),
                  _Step(
                    day: c.day(c.reminderDay),
                    title: LangKeys.rfuReminder.tr,
                    subtitle: LangKeys.rfuReminderSub.tr,
                    value: c.reminderEnabled.value,
                    enabled: c.canEdit,
                    onChanged: (v) => c.toggle(c.reminderEnabled, v),
                    chips: [
                      for (final ch in ReviewSettingsController.channels)
                        SoftChip(
                          key: ValueKey('rfu-channel-$ch'),
                          label: c.channelLabel(ch),
                          selected: c.reminderChannels.contains(ch),
                          onTap: c.reminderEnabled.value ? () => c.onChannelTap(ch) : null,
                        ),
                    ],
                  ),
                  const SizedBox(height: KnSize.space12),
                  _Step(
                    day: c.day(c.aiCallDay),
                    title: LangKeys.rfuAi.tr,
                    subtitle: c.aiSub,
                    value: c.aiCallEnabled.value,
                    enabled: c.canEdit,
                    onChanged: (v) => c.toggle(c.aiCallEnabled, v),
                    chips: [SoftChip(label: LangKeys.rfuAiLang.tr), SoftChip(label: LangKeys.rfuAiRecorded.tr)],
                    note: LangKeys.rfuAiNotLive.tr,
                  ),
                  const SizedBox(height: KnSize.space12),
                  Container(
                    padding: const EdgeInsets.all(KnSize.space12),
                    decoration: BoxDecoration(color: kn.actionSecondary, borderRadius: BorderRadius.circular(KnSize.radiusMd)),
                    child: CustomBaseTextWidget(LangKeys.rfuStops.tr, style: text.labelSm),
                  ),
                  const SizedBox(height: KnSize.space12),
                  SettingsCard(
                    children: [
                      KnSwitchRow(
                        key: const ValueKey('rfu-techs'),
                        title: LangKeys.rfuTechs.tr,
                        subtitle: LangKeys.rfuTechsSub.tr,
                        value: c.techsCanRequest.value,
                        enabled: c.canEdit,
                        onChanged: (v) => c.toggle(c.techsCanRequest, v),
                      ),
                    ],
                  ),
                ],
              ],
            );
          }),
        ),
      ),
      bottomNavigationBar: SettingsSaveFooter(controller: controller),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.day,
    required this.title,
    required this.subtitle,
    required this.chips,
    this.value,
    this.enabled = true,
    this.onChanged,
    this.trailing,
    this.note,
  });

  final String day;
  final String title;
  final String subtitle;
  final List<Widget> chips;
  final bool? value;
  final bool enabled;
  final ValueChanged<bool>? onChanged;
  final Widget? trailing;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final text = context.knText;
    final on = value;
    final small = note;
    return SettingsCard(
      padding: const EdgeInsets.all(KnSize.space16),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DayBadge(label: day),
            const SizedBox(width: KnSize.space12),
            Expanded(
              child: on == null
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CustomBaseTextWidget(title, style: text.label),
                        const SizedBox(height: 2),
                        CustomBaseTextWidget(subtitle, style: text.caption, color: kn.textSecondary),
                      ],
                    )
                  : KnSwitchRow(
                      title: title,
                      subtitle: subtitle,
                      value: on,
                      enabled: enabled,
                      onChanged: onChanged ?? (_) {},
                      padding: EdgeInsets.zero,
                    ),
            ),
            ?trailing,
          ],
        ),
        const SizedBox(height: KnSize.space12),
        Wrap(spacing: KnSize.space8, runSpacing: KnSize.space8, children: chips),
        if (small != null) ...[
          const SizedBox(height: KnSize.space8),
          CustomBaseTextWidget(small, style: text.caption, color: kn.textSecondary),
        ],
      ],
    );
  }
}
