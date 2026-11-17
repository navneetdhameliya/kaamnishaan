import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../../common_widgets/custom_inkwell.dart';
import '../../../../common_widgets/kn_custom_button.dart';
import '../../../../commons/text_widgets/base/custom_base_text_widget.dart';
import '../../../../theme/kn_app_theme.dart';
import '../../../../theme/kn_tokens.g.dart';

/// M14 search: a round field with a magnifier, and an X to clear it once something is typed.
class JobSearchField extends StatelessWidget {
  const JobSearchField({super.key, required this.controller, required this.onChanged, required this.onClear, required this.active});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final radius = BorderRadius.circular(KnSize.radiusFull);
    OutlineInputBorder border(Color c, double w) =>
        OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: c, width: w));
    return TextField(
      key: const ValueKey('job-search'),
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      style: context.knText.body,
      decoration: InputDecoration(
        filled: true,
        fillColor: kn.bgSurface,
        hintText: LangKeys.jobsSearch.tr,
        hintStyle: context.knText.body.copyWith(color: kn.textSecondary),
        prefixIcon: Icon(LucideIcons.search, size: 20, color: kn.textSecondary),
        suffixIcon: active
            ? Padding(
                padding: const EdgeInsets.only(right: KnSize.space12),
                child: CustomInkWell(
                  key: const ValueKey('clear-search'),
                  onTap: onClear,
                  borderRadius: BorderRadius.circular(12),
                  semanticLabel: LangKeys.jobsClearSearch.tr,
                  child: Ink(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(color: kn.bgSubtle, shape: BoxShape.circle),
                    child: Icon(LucideIcons.x, size: 14, color: kn.textPrimary),
                  ),
                ),
              )
            : null,
        suffixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 24),
        contentPadding: const EdgeInsets.symmetric(vertical: 13),
        enabledBorder: border(active ? kn.textLink : kn.borderDefault, active ? 2 : 1),
        focusedBorder: border(kn.focusRing, 2),
        border: border(kn.borderDefault, 1),
      ),
    );
  }
}

/// M14 filter chip ("Today 6", "Tomorrow", "Unassigned").
class JobFilterChip extends StatelessWidget {
  const JobFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.dense = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// Smaller words and sides, so four chips fit on a phone (M30).
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final radius = BorderRadius.circular(KnSize.radiusFull);
    return CustomInkWell(
      onTap: onTap,
      borderRadius: radius,
      semanticLabel: label,
      child: Ink(
        padding: EdgeInsets.symmetric(horizontal: dense ? 10 : KnSize.space12, vertical: KnSize.space8),
        decoration: BoxDecoration(
          color: selected ? kn.actionPrimary : kn.bgSurface,
          borderRadius: radius,
          border: Border.all(color: selected ? kn.actionPrimary : kn.borderDefault),
        ),
        child: CustomBaseTextWidget(
          label,
          style: dense ? context.knText.labelSm : context.knText.label,
          color: selected ? kn.textOnAction : kn.textPrimary,
        ),
      ),
    );
  }
}

/// M14 "No jobs for “Riverside”" (Figma 43:1089), also used when a day simply has no jobs.
class JobListEmpty extends StatelessWidget {
  const JobListEmpty({super.key, required this.title, required this.body, this.onClear});

  final String title;
  final String body;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final text = context.knText;
    return Padding(
      key: const ValueKey('jobs-empty'),
      padding: const EdgeInsets.only(top: 72),
      child: Column(
        children: [
          Container(
            width: 120,
            height: 120,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: kn.bgSubtle, shape: BoxShape.circle),
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(color: kn.bgSurface, shape: BoxShape.circle),
              child: Icon(LucideIcons.search, size: 32, color: kn.textPrimary),
            ),
          ),
          const SizedBox(height: KnSize.space16),
          CustomBaseTextWidget(title, style: text.h2, textAlign: TextAlign.center),
          const SizedBox(height: KnSize.space8),
          CustomBaseTextWidget(body, style: text.body, color: kn.textSecondary, textAlign: TextAlign.center),
          if (onClear != null) ...[
            const SizedBox(height: KnSize.space16),
            IntrinsicWidth(
              child: KnCustomButton(
                key: const ValueKey('clear-filters'),
                text: LangKeys.jobsClearFilters.tr,
                icon: LucideIcons.rotateCw,
                variant: KnButtonVariant.secondary,
                onTap: onClear,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
