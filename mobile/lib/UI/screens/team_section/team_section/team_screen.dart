import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../common_widgets/common_shimmer.dart';
import '../../../common_widgets/custom_inkwell.dart';
import '../../../common_widgets/kn_custom_button.dart';
import '../../../common_widgets/kn_screen_footer.dart';
import '../../../common_widgets/kn_title_bar.dart';
import '../../../commons/behaviour/behaviour.dart';
import '../../../commons/text_widgets/base/custom_base_text_widget.dart';
import '../../../theme/kn_app_theme.dart';
import '../../../theme/kn_tokens.g.dart';
import '../../jobs_section/job_list_section/custom_widgets/job_list_parts.dart';
import 'custom_widgets/member_row.dart';
import 'team_controller.dart';

/// M40 Team (Figma 40:837).
class TeamScreen extends GetView<TeamController> {
  const TeamScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final text = context.knText;
    return Scaffold(
      backgroundColor: kn.bgCanvas,
      bottomNavigationBar: KnScreenFooter(
        children: [
          KnCustomButton(
            key: const ValueKey('team-invite'),
            text: LangKeys.teamInvitePerson.tr,
            icon: LucideIcons.plus,
            onTap: controller.onInviteTap,
          ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: Obx(() {
          final active = controller.active;
          final waiting = controller.waiting;
          return RefreshIndicator(
            onRefresh: controller.load,
            child: ScrollConfiguration(
              behavior: const KnScrollBehavior(),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(KnSize.space16, 12, KnSize.space16, KnSize.space24),
                children: [
                  Row(
                    children: [
                      Expanded(child: KnTitleBar(title: LangKeys.teamTitle.tr, subtitle: controller.subtitle)),
                      const SizedBox(width: KnSize.space12),
                      CustomInkWell(
                        key: const ValueKey('team-search'),
                        onTap: controller.onSearchTap,
                        borderRadius: BorderRadius.circular(22),
                        semanticLabel: LangKeys.teamSearch.tr,
                        child: Ink(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: kn.bgSurface,
                            border: Border.all(color: kn.borderDefault),
                          ),
                          child: Icon(
                            controller.searching.value ? LucideIcons.x : LucideIcons.search,
                            size: 22,
                            color: kn.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: KnSize.space16),
                  if (controller.searching.value) ...[
                    TextField(
                      key: const ValueKey('team-search-field'),
                      controller: controller.search,
                      autofocus: true,
                      onChanged: controller.onSearchChanged,
                      style: text.body,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: kn.bgSurface,
                        hintText: LangKeys.teamSearch.tr,
                        prefixIcon: Icon(LucideIcons.search, size: 20, color: kn.textSecondary),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(KnSize.radiusMd),
                          borderSide: BorderSide(color: kn.borderStrong),
                        ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(KnSize.radiusMd)),
                      ),
                    ),
                    const SizedBox(height: KnSize.space12),
                  ],
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    clipBehavior: Clip.none,
                    child: Row(
                      children: [
                        for (final f in TeamFilter.values) ...[
                          JobFilterChip(
                            key: ValueKey('team-filter-${f.name}'),
                            label: controller.chipLabel(f),
                            selected: controller.filter.value == f,
                            onTap: () => controller.onFilterTap(f),
                            dense: true,
                          ),
                          const SizedBox(width: 6),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: KnSize.space12),
                  if (controller.loading.value)
                    const CommonShimmer(height: 220, radius: KnSize.radiusLg)
                  else ...[
                    if (active.isNotEmpty)
                      Container(
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          color: kn.bgSurface,
                          borderRadius: BorderRadius.circular(KnSize.radiusLg),
                          border: Border.all(color: kn.borderDefault),
                          boxShadow: KnShadow.sm,
                        ),
                        child: Material(
                          type: MaterialType.transparency,
                          child: Column(
                            children: [
                              for (final (i, m) in active.indexed)
                                MemberRow(
                                  key: ValueKey('member-${m.id}'),
                                  name: controller.name(m),
                                  initials: controller.initials(m),
                                  avatarUrl: m.avatarUrl,
                                  line: controller.line(m),
                                  state: controller.state(m),
                                  tone: controller.tone(m),
                                  divider: i < active.length - 1,
                                  onTap: () => controller.onMemberTap(m),
                                ),
                            ],
                          ),
                        ),
                      ),
                    if (active.isEmpty && waiting.isEmpty && controller.query.value.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.all(KnSize.space24),
                        child: CustomBaseTextWidget(
                          LangKeys.teamNoResults.trParams({'q': controller.query.value.trim()}),
                          style: text.body,
                          color: kn.textSecondary,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    if (waiting.isNotEmpty) ...[
                      const SizedBox(height: KnSize.space16),
                      CustomBaseTextWidget(LangKeys.teamWaiting.tr, style: text.label, color: kn.textSecondary),
                      const SizedBox(height: KnSize.space12),
                      for (final m in waiting) ...[
                        WaitingCard(
                          key: ValueKey('waiting-${m.id}'),
                          name: m.name,
                          initials: controller.initials(m),
                          avatarUrl: m.avatarUrl,
                          line: controller.line(m),
                          sending: controller.resending.contains(m.inviteId),
                          onResend: () => controller.onResendTap(m),
                        ),
                        const SizedBox(height: KnSize.space12),
                      ],
                    ],
                    if (controller.onlyMe) ...[
                      const SizedBox(height: KnSize.space24),
                      Icon(LucideIcons.users, size: 40, color: kn.textSecondary),
                      const SizedBox(height: KnSize.space12),
                      CustomBaseTextWidget(LangKeys.teamEmptyTitle.tr, style: text.h3, textAlign: TextAlign.center),
                      const SizedBox(height: KnSize.space8),
                      CustomBaseTextWidget(
                        LangKeys.teamEmptyBody.tr,
                        style: text.body,
                        color: kn.textSecondary,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}
