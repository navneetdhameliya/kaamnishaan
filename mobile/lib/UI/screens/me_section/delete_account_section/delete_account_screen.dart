import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../../infrastructure/models/api_models.g.dart';
import '../../../common_widgets/common_shimmer.dart';
import '../../../common_widgets/kn_checkbox_tile.dart';
import '../../../common_widgets/kn_custom_button.dart';
import '../../../common_widgets/kn_inline_error.dart';
import '../../../common_widgets/kn_page_scaffold.dart';
import '../../../common_widgets/kn_screen_footer.dart';
import '../../../common_widgets/kn_select_card.dart';
import '../../../common_widgets/kn_text_box.dart';
import '../../../commons/text_widgets/base/custom_base_text_widget.dart';
import '../../../theme/kn_app_theme.dart';
import '../../../theme/kn_tokens.g.dart';
import 'delete_account_controller.dart';

/// Me → Delete account (D-130).
class DeleteAccountScreen extends GetView<DeleteAccountController> {
  const DeleteAccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final text = context.knText;
    return KnPageScaffold(
      body: Obx(() {
        final c = controller.check.value;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: KnSize.space16),
            CustomBaseTextWidget(LangKeys.delTitle.tr, style: text.h2),
            const SizedBox(height: KnSize.space4),
            CustomBaseTextWidget(LangKeys.delBody.tr, style: text.body, color: kn.textSecondary),
            const SizedBox(height: KnSize.space24),
            if (controller.loading.value && c == null)
              const CommonShimmer(height: 220)
            else if (c == null) ...[
              KnInlineError(message: controller.loadError.value ?? LangKeys.delErrGeneric.tr),
              const SizedBox(height: KnSize.space12),
              KnCustomButton(text: LangKeys.commonRetry.tr, variant: KnButtonVariant.secondary, onTap: controller.load),
            ] else ...[
              _Facts(check: c),
              for (final co in c.companies.where((x) => x.closes || x.needsNewOwner)) ...[
                const SizedBox(height: KnSize.space16),
                co.needsNewOwner ? _PickOwner(company: co) : _Closes(company: co),
              ],
              const SizedBox(height: KnSize.space24),
              CustomBaseTextWidget(LangKeys.delReason.tr, style: text.label),
              const SizedBox(height: KnSize.space8),
              KnTextBox(
                fieldKey: const ValueKey('del-reason'),
                controller: controller.reason,
                hint: LangKeys.delReasonHint.tr,
                minLines: 2,
                maxLines: 4,
                maxLength: 300,
              ),
              const SizedBox(height: KnSize.space16),
              KnCheckboxTile(
                key: const ValueKey('del-understood'),
                value: controller.understood.value,
                label: LangKeys.delUnderstood.tr,
                onChanged: (v) => controller.understood.value = v,
              ),
            ],
            if (controller.error.value != null) ...[
              const SizedBox(height: KnSize.space12),
              KnInlineError(message: controller.error.value!),
            ],
            const SizedBox(height: KnSize.space24),
          ],
        );
      }),
      footer: KnScreenFooter(
        children: [
          Obx(
            () => KnCustomButton(
              key: const ValueKey('del-confirm'),
              text: LangKeys.delButton.tr,
              icon: LucideIcons.trash2,
              variant: KnButtonVariant.danger,
              loading: controller.deleting.value,
              enabled: controller.ready,
              onTap: controller.onDelete,
              onDisabledTap: controller.onDisabledTap,
            ),
          ),
        ],
      ),
    );
  }
}

class _Facts extends StatelessWidget {
  const _Facts({required this.check});

  final DeletionCheckModel check;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final text = context.knText;
    final left = check.companies.where((c) => !c.closes).map((c) => c.name).join(', ');
    final jobs = check.openJobs ?? 0;
    final rows = <(IconData, String)>[
      (LucideIcons.userX, LangKeys.delFactDetails.tr),
      (LucideIcons.logOut, LangKeys.delFactLogout.tr),
      if (left.isNotEmpty) (LucideIcons.fileCheck, LangKeys.delFactWork.trParams({'company': left})),
      if (jobs > 0) (LucideIcons.briefcase, LangKeys.delFactJobs.trParams({'n': '$jobs'})),
      (LucideIcons.triangleAlert, LangKeys.delFactForever.tr),
    ];
    return Container(
      padding: const EdgeInsets.all(KnSize.space16),
      decoration: BoxDecoration(
        color: kn.bgSurface,
        borderRadius: BorderRadius.circular(KnSize.radiusLg),
        border: Border.all(color: kn.borderDefault),
      ),
      child: Column(
        children: [
          for (final (icon, line) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: KnSize.space8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, size: 20, color: kn.textSecondary),
                  const SizedBox(width: KnSize.space12),
                  Expanded(child: CustomBaseTextWidget(line, style: text.body)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Closes extends StatelessWidget {
  const _Closes({required this.company});

  final DeletionCompanyModel company;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    return Container(
      padding: const EdgeInsets.all(KnSize.space16),
      decoration: BoxDecoration(color: kn.statusWarningBg, borderRadius: BorderRadius.circular(KnSize.radiusLg)),
      child: CustomBaseTextWidget(
        LangKeys.delCloses.trParams({'company': company.name}),
        style: context.knText.label,
        color: kn.statusWarning,
      ),
    );
  }
}

class _PickOwner extends GetView<DeleteAccountController> {
  const _PickOwner({required this.company});

  final DeletionCompanyModel company;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final text = context.knText;
    final here = controller.canHandOver(company);
    return Container(
      key: ValueKey('del-owner-${company.companyId}'),
      padding: const EdgeInsets.all(KnSize.space16),
      decoration: BoxDecoration(
        color: kn.bgSurface,
        borderRadius: BorderRadius.circular(KnSize.radiusLg),
        border: Border.all(color: kn.statusWarning),
      ),
      child: Obx(
        () => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CustomBaseTextWidget(LangKeys.delOwnerTitle.trParams({'company': company.name}), style: text.h3),
            const SizedBox(height: KnSize.space4),
            CustomBaseTextWidget(
              here ? LangKeys.delOwnerBody.tr : LangKeys.delOwnerSwitch.tr,
              style: text.body,
              color: kn.textSecondary,
            ),
            if (here) ...[
              const SizedBox(height: KnSize.space12),
              for (final p in company.candidates ?? const <OwnerCandidateModel>[]) ...[
                KnSelectCard(
                  key: ValueKey('del-candidate-${p.userId}'),
                  title: p.name,
                  subtitle: controller.roleLabel(p.role),
                  selected: controller.newOwner[company.companyId] == p.userId,
                  onTap: () => controller.newOwner[company.companyId] = p.userId,
                ),
                const SizedBox(height: KnSize.space8),
              ],
              KnCustomButton(
                key: const ValueKey('del-make-owner'),
                text: LangKeys.delOwnerButton.tr,
                icon: LucideIcons.userCheck,
                variant: KnButtonVariant.secondary,
                loading: controller.handing.value == company.companyId,
                enabled: controller.newOwner[company.companyId] != null,
                onTap: () => controller.onHandOver(company),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
