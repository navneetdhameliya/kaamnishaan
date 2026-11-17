import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../../infrastructure/models/api_models.g.dart';
import '../../../../infrastructure/shared/text_utils.dart';
import '../../../common_widgets/common_shimmer.dart';
import '../../../common_widgets/custom_inkwell.dart';
import '../../../common_widgets/kn_cover_image.dart';
import '../../../common_widgets/kn_initials_avatar.dart';
import '../../../common_widgets/kn_title_bar.dart';
import '../../../commons/behaviour/behaviour.dart';
import '../../../commons/text_widgets/base/custom_base_text_widget.dart';
import '../../../theme/kn_app_theme.dart';
import '../../../theme/kn_tokens.g.dart';
import '../../jobs_section/job_list_section/custom_widgets/job_list_parts.dart';
import 'review_requests_controller.dart';

/// M45 Review requests (Figma 274:2744).
class ReviewRequestsScreen extends GetView<ReviewRequestsController> {
  const ReviewRequestsScreen({super.key});

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
          child: RefreshIndicator(
            onRefresh: controller.load,
            child: Obx(
              () => ListView(
                padding: const EdgeInsets.fromLTRB(KnSize.space16, 12, KnSize.space16, KnSize.space24),
                children: [
                  KnTitleBar(title: LangKeys.crevRequests.tr, subtitle: LangKeys.rreqSubtitle.tr),
                  const SizedBox(height: KnSize.space16),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final t in ReviewRequestsController.tabs) ...[
                          JobFilterChip(
                            key: ValueKey('requests-tab-$t'),
                            label: controller.label(t),
                            selected: controller.tab.value == t,
                            onTap: () => controller.onTab(t),
                          ),
                          const SizedBox(width: KnSize.space8),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: KnSize.space12),
                  if (controller.loading.value && controller.page.value == null)
                    for (var i = 0; i < 4; i++) ...[
                      const CommonShimmer(height: 96, radius: KnSize.radiusLg),
                      const SizedBox(height: KnSize.space12),
                    ]
                  else if (controller.items.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: KnSize.space16),
                      child: Column(
                        children: [
                          CustomBaseTextWidget(LangKeys.rreqEmpty.tr, style: text.h3, textAlign: TextAlign.center),
                          const SizedBox(height: 4),
                          CustomBaseTextWidget(
                            LangKeys.rreqEmptyBody.tr,
                            style: text.body,
                            color: kn.textSecondary,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  else
                    for (final r in controller.items) ...[
                      _RequestCard(
                        key: ValueKey('request-${r.id}'),
                        request: r,
                        chip: controller.chip(r),
                        line: controller.line(r),
                        tone: controller.tone(r),
                        onTap: () => controller.onTap(r),
                      ),
                      const SizedBox(height: KnSize.space12),
                    ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    super.key,
    required this.request,
    required this.chip,
    required this.line,
    required this.tone,
    required this.onTap,
  });

  final RequestItemModel request;
  final String chip;
  final String line;
  final RequestTone tone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final text = context.knText;
    final radius = BorderRadius.circular(KnSize.radiusLg);
    final tech = request.technician;
    final (bg, fg) = switch (tone) {
      RequestTone.good => (kn.statusSuccessBg, kn.statusSuccess),
      RequestTone.soon => (kn.statusWarningBg, kn.statusWarning),
      RequestTone.plain => (kn.bgSubtle, kn.textPrimary),
    };
    return CustomInkWell(
      onTap: onTap,
      borderRadius: radius,
      semanticLabel: request.customer,
      child: Ink(
        padding: const EdgeInsets.all(KnSize.space12),
        decoration: BoxDecoration(color: kn.bgSurface, borderRadius: radius, border: Border.all(color: kn.borderDefault)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            KnCoverImage(url: request.coverUrl, width: 48, height: 48, radius: KnSize.radiusMd, placeholderIcon: LucideIcons.wrench),
            const SizedBox(width: KnSize.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CustomBaseTextWidget(request.customer, style: text.label, maxLines: 1),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(KnSize.radiusFull)),
                    child: CustomBaseTextWidget(chip, style: text.labelSm, color: fg),
                  ),
                  const SizedBox(height: 4),
                  CustomBaseTextWidget(line, style: text.caption, color: kn.textSecondary, maxLines: 2),
                ],
              ),
            ),
            if (tech != null) ...[
              const SizedBox(width: KnSize.space8),
              KnInitialsAvatar(initials: TextUtils.initials(tech.name), size: 24, url: tech.avatarUrl, borderWidth: 0),
            ],
          ],
        ),
      ),
    );
  }
}
