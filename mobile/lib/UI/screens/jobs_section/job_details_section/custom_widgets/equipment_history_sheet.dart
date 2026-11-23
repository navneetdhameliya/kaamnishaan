import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../../common_widgets/custom_inkwell.dart';
import '../../../../common_widgets/kn_bottom_sheet.dart';
import '../../../../common_widgets/kn_job_status_pill.dart';
import '../../../../commons/text_widgets/base/custom_base_text_widget.dart';
import '../../../../theme/kn_app_theme.dart';
import '../../../../theme/kn_tokens.g.dart';
import '../job_details_controller.dart';

/// M15 Equipment card: earlier jobs on the same machine, newest first; tap one to open it (D-142).
Future<void> showEquipmentHistorySheet(JobDetailsController c) => showKnBottomSheet<void>(
      title: LangKeys.historyTitle.tr,
      child: Builder(
        builder: (context) {
          final kn = context.kn;
          final text = context.knText;
          return Obx(() {
            final list = c.history.value;
            if (list == null) {
              return const Padding(
                padding: EdgeInsets.all(KnSize.space24),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (list.isEmpty) {
              return Padding(
                key: const ValueKey('history-empty'),
                padding: const EdgeInsets.symmetric(vertical: KnSize.space24),
                child: CustomBaseTextWidget(
                  LangKeys.historyEmpty.tr,
                  style: text.body,
                  color: kn.textSecondary,
                  textAlign: TextAlign.center,
                ),
              );
            }
            return ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.6),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: list.length,
                separatorBuilder: (_, _) => Divider(height: 1, color: kn.borderDefault),
                itemBuilder: (_, i) {
                  final j = list[i];
                  return CustomInkWell(
                    key: ValueKey('history-${j.id}'),
                    onTap: () => c.onHistoryJobTap(j),
                    borderRadius: BorderRadius.circular(KnSize.radiusMd),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: KnSize.space12, horizontal: KnSize.space4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CustomBaseTextWidget(j.title, style: text.label),
                                const SizedBox(height: 2),
                                CustomBaseTextWidget(c.historyLine(j), style: text.caption, color: kn.textSecondary),
                              ],
                            ),
                          ),
                          const SizedBox(width: KnSize.space8),
                          KnJobStatusPill(status: j.status),
                          const SizedBox(width: KnSize.space4),
                          Icon(LucideIcons.chevronRight, size: 18, color: kn.textSecondary),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          });
        },
      ),
    );
