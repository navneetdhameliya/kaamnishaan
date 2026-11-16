import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../../infrastructure/models/api_models.g.dart';
import '../../../common_widgets/common_shimmer.dart';
import '../../../common_widgets/custom_inkwell.dart';
import '../../../common_widgets/kn_back_button.dart';
import '../../../common_widgets/kn_cover_image.dart';
import '../../../common_widgets/kn_custom_button.dart';
import '../../../common_widgets/kn_screen_footer.dart';
import '../../../common_widgets/kn_select_card.dart';
import '../../../commons/behaviour/behaviour.dart';
import '../../../commons/text_widgets/base/custom_base_text_widget.dart';
import '../../../theme/kn_app_theme.dart';
import '../../../theme/kn_tokens.g.dart';
import 'checklist_question_controller.dart';
import 'custom_widgets/answer_widgets.dart';

/// M25 Checklist question (Figma 27:1246; photo required 27:1302).
class ChecklistQuestionScreen extends GetView<ChecklistQuestionController> {
  const ChecklistQuestionScreen({super.key});

  Widget _round(BuildContext context, {required Key key, required IconData icon, required String label, required VoidCallback onTap}) =>
      CustomInkWell(
        key: key,
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        semanticLabel: label,
        child: Ink(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: context.kn.bgSurface,
            shape: BoxShape.circle,
            border: Border.all(color: context.kn.borderDefault),
          ),
          child: Icon(icon, size: 22, color: context.kn.textPrimary),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final text = context.knText;
    return Scaffold(
      backgroundColor: kn.bgCanvas,
      bottomNavigationBar: Obx(() => _footer() ?? const SizedBox.shrink()),
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(KnSize.space16, 12, KnSize.space16, 0),
              child: Row(
                children: [
                  KnBackButton(onTap: controller.onBackTap),
                  const SizedBox(width: KnSize.space12),
                  Expanded(
                    child: Obx(
                      () => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CustomBaseTextWidget(controller.submission.value?.name ?? '', style: text.h3, maxLines: 1),
                          CustomBaseTextWidget(controller.args.customer, style: text.caption, color: kn.textSecondary, maxLines: 1),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: KnSize.space12),
                  _round(
                    context,
                    key: const ValueKey('close-checklist'),
                    icon: LucideIcons.x,
                    label: LangKeys.commonClose.tr,
                    onTap: controller.onCloseTap,
                  ),
                ],
              ),
            ),
            Expanded(
              child: ScrollConfiguration(
                behavior: const KnScrollBehavior(),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(KnSize.space16, KnSize.space16, KnSize.space16, KnSize.space24),
                  child: Obx(() => _body(context)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    final kn = context.kn;
    final text = context.knText;
    final q = controller.current;
    if (q == null) {
      return const Column(
        children: [
          CommonShimmer(height: 24, radius: 12),
          SizedBox(height: 16),
          CommonShimmer(height: 176, radius: KnSize.radiusLg),
          SizedBox(height: 16),
          CommonShimmer(height: 112, radius: KnSize.radiusLg),
        ],
      );
    }
    final total = controller.shown.length;
    return Column(
      key: ValueKey('question-${q.id}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: CustomBaseTextWidget(
                LangKeys.questionOf.trParams({'n': '${controller.position}', 'total': '$total'}),
                style: text.label,
              ),
            ),
            CustomBaseTextWidget('${controller.percent}%', style: text.caption, color: kn.textSecondary),
          ],
        ),
        const SizedBox(height: KnSize.space8),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: controller.percent / 100,
            minHeight: 6,
            backgroundColor: kn.bgSubtle,
            color: kn.actionPrimary,
          ),
        ),
        const SizedBox(height: KnSize.space16),
        if (controller.locked) ...[
          _banner(context, LucideIcons.lock, LangKeys.questionLocked.tr, kn.bgSubtle, kn.textSecondary),
          const SizedBox(height: KnSize.space16),
        ],
        if (q.referenceImageUrl != null) ...[
          SizedBox(
            height: 176,
            child: Stack(
              fit: StackFit.expand,
              children: [
                KnCoverImage(url: q.referenceImageUrl, height: 176, radius: KnSize.radiusLg, placeholderIcon: LucideIcons.image),
                Positioned(
                  left: 12,
                  top: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: KnSize.space4),
                    decoration: BoxDecoration(
                      color: KnPrimitive.mocha950.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(KnSize.radiusFull),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(LucideIcons.image, size: 14, color: KnPrimitive.cream50),
                        const SizedBox(width: 6),
                        CustomBaseTextWidget(LangKeys.questionLook.tr, style: text.labelSm, color: KnPrimitive.cream50),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: CustomBaseTextWidget(q.text, style: text.h1)),
            const SizedBox(width: KnSize.space12),
            CustomInkWell(
              key: const ValueKey('read-question'),
              onTap: controller.onSpeakTap,
              borderRadius: BorderRadius.circular(22),
              semanticLabel: LangKeys.jobReadAloud.tr,
              child: Ink(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: kn.bgSubtle, shape: BoxShape.circle),
                child: Icon(LucideIcons.volume2, size: 22, color: kn.textPrimary),
              ),
            ),
          ],
        ),
        if (q.help != null && q.help!.isNotEmpty) ...[
          const SizedBox(height: KnSize.space4),
          CustomBaseTextWidget(q.help!, style: text.body, color: kn.textSecondary),
        ],
        const SizedBox(height: 20),
        _answers(context, q),
        const SizedBox(height: KnSize.space16),
        if (controller.photoNeeded.value)
          _banner(context, LucideIcons.circleAlert, LangKeys.questionNeedsPhoto.tr, kn.statusWarningBg, kn.statusWarning)
        else if (controller.hasPhoto(q))
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(LucideIcons.camera, size: 16, color: kn.statusSuccess),
              const SizedBox(width: 6),
              CustomBaseTextWidget(LangKeys.questionPhotoAdded.tr, style: text.captionStrong, color: kn.statusSuccess),
            ],
          )
        else
          CustomInkWell(
            onTap: controller.onNotSureTap,
            borderRadius: BorderRadius.circular(KnSize.radiusSm),
            child: Padding(
              padding: const EdgeInsets.all(KnSize.space4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(LucideIcons.circleAlert, size: 16, color: kn.textSecondary),
                  const SizedBox(width: 6),
                  Flexible(
                    child: CustomBaseTextWidget(LangKeys.questionNotSure.tr, style: text.caption, color: kn.textSecondary),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _banner(BuildContext context, IconData icon, String message, Color bg, Color fg) => Container(
        key: ValueKey('banner-$message'),
        padding: const EdgeInsets.symmetric(horizontal: KnSize.space16, vertical: KnSize.space12),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(KnSize.radiusMd)),
        child: Row(
          children: [
            Icon(icon, size: 20, color: fg),
            const SizedBox(width: KnSize.space12),
            Expanded(child: CustomBaseTextWidget(message, style: context.knText.captionStrong, color: fg)),
          ],
        ),
      );

  Widget _answers(BuildContext context, QuestionOutModel q) {
    final value = '${controller.valueOf(q)}'.toLowerCase();
    final enabled = !controller.locked;
    switch (q.type) {
      case 'yes_no':
      case 'pass_fail':
        final yes = q.type == 'yes_no' ? 'yes' : 'pass';
        final no = q.type == 'yes_no' ? 'no' : 'fail';
        return Row(
          children: [
            Expanded(
              child: BigAnswerCard(
                key: const ValueKey('answer-good'),
                label: q.type == 'yes_no' ? LangKeys.questionYes.tr : LangKeys.questionPass.tr,
                good: true,
                selected: value == yes,
                enabled: enabled,
                onTap: () => controller.onChoose(yes),
              ),
            ),
            const SizedBox(width: KnSize.space16),
            Expanded(
              child: BigAnswerCard(
                key: const ValueKey('answer-bad'),
                label: q.type == 'yes_no' ? LangKeys.questionNo.tr : LangKeys.questionFail.tr,
                good: false,
                selected: value == no,
                enabled: enabled,
                onTap: () => controller.onChoose(no),
              ),
            ),
          ],
        );
      case 'choice':
        return Column(
          children: [
            for (final o in q.options) ...[
              if (o != q.options.first) const SizedBox(height: KnSize.space8),
              KnSelectCard(
                key: ValueKey('option-${o.key}'),
                title: o.label,
                selected: value == o.key.toLowerCase(),
                onTap: () => enabled ? controller.onChoose(o.key) : null,
              ),
            ],
          ],
        );
      case 'number':
      case 'text':
        final number = q.type == 'number';
        return TextField(
          key: const ValueKey('typed-answer'),
          controller: controller.textController,
          enabled: enabled,
          keyboardType: number ? const TextInputType.numberWithOptions(decimal: true, signed: true) : TextInputType.text,
          inputFormatters: number ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,\-]'))] : null,
          maxLines: number ? 1 : 4,
          minLines: 1,
          style: number ? context.knText.h2 : context.knText.body,
          onSubmitted: (_) => controller.onSubmitTyped(),
          decoration: InputDecoration(
            filled: true,
            fillColor: context.kn.bgSurface,
            hintText: number ? LangKeys.questionNumberHint.tr : LangKeys.questionTextHint.tr,
            suffixText: q.unit,
            helperText: number && (q.minValue != null || q.maxValue != null)
                ? LangKeys.questionRange.trParams({'min': '${q.minValue ?? ''}', 'max': '${q.maxValue ?? ''}'})
                : null,
            contentPadding: const EdgeInsets.all(KnSize.space16),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(KnSize.radiusLg)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(KnSize.radiusLg),
              borderSide: BorderSide(color: context.kn.borderStrong),
            ),
          ),
        );
      case 'signature':
        return SignaturePad(saving: controller.saving.value, onSave: controller.onSignature);
      default: // photo: the footer button takes it
        return const SizedBox.shrink();
    }
  }

  Widget? _footer() {
    final q = controller.current;
    if (q == null || controller.locked) return null;
    if (controller.photoNeeded.value || (q.type == 'photo' && !controller.hasPhoto(q))) {
      return KnScreenFooter(
        children: [
          KnCustomButton(
            key: const ValueKey('question-photo'),
            text: LangKeys.galleryTakePhoto.tr,
            icon: LucideIcons.camera,
            onTap: controller.onTakePhotoTap,
          ),
        ],
      );
    }
    if (q.type == 'number' || q.type == 'text') {
      return KnScreenFooter(
        children: [
          KnCustomButton(
            key: const ValueKey('question-next'),
            text: q.requiredValue ? LangKeys.questionNext.tr : '${LangKeys.questionNext.tr} / ${LangKeys.questionSkip.tr}',
            icon: LucideIcons.chevronRight,
            onTap: controller.onSubmitTyped,
          ),
        ],
      );
    }
    if (q.type == 'photo' && controller.hasPhoto(q)) {
      return KnScreenFooter(
        children: [
          KnCustomButton(
            key: const ValueKey('question-next'),
            text: LangKeys.questionNext.tr,
            icon: LucideIcons.chevronRight,
            onTap: controller.onNextTap,
          ),
        ],
      );
    }
    return null;
  }
}
