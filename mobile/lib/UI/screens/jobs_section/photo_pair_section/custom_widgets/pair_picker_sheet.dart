import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../../../infrastructure/models/api_models.g.dart';
import '../../../../common_widgets/custom_inkwell.dart';
import '../../../../common_widgets/kn_bottom_sheet.dart';
import '../../../../common_widgets/kn_cover_image.dart';
import '../../../../common_widgets/kn_custom_button.dart';
import '../../../../commons/text_widgets/base/custom_base_text_widget.dart';
import '../../../../theme/kn_app_theme.dart';
import '../../../../theme/kn_tokens.g.dart';
import '../photo_pair_controller.dart';

/// M22 "Choose photos": one row of before photos and one of after photos; tap one in each (D-144).
Future<void> showPairPickerSheet(PhotoPairController c) => showKnBottomSheet<void>(
      title: LangKeys.pairChoose.tr,
      child: Builder(
        builder: (context) {
          final text = context.knText;
          Widget row(String stage, String label, Rxn<EvidenceOutModel> picked) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CustomBaseTextWidget(label, style: text.label),
                  const SizedBox(height: KnSize.space8),
                  SizedBox(
                    height: 88,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: c.choices(stage).length,
                      separatorBuilder: (_, _) => const SizedBox(width: KnSize.space8),
                      itemBuilder: (_, i) {
                        final e = c.choices(stage)[i];
                        return Obx(() => _Thumb(photo: e, selected: picked.value?.id == e.id, onTap: () => c.onPick(e)));
                      },
                    ),
                  ),
                ],
              );
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              row('before', LangKeys.pairChooseBefore.tr, c.before),
              const SizedBox(height: KnSize.space16),
              row('after', LangKeys.pairChooseAfter.tr, c.after),
              const SizedBox(height: KnSize.space24),
              KnCustomButton(
                key: const ValueKey('pair-choose-done'),
                text: LangKeys.pairChooseDone.tr,
                onTap: () => Get.back<void>(),
              ),
            ],
          );
        },
      ),
    );

class _Thumb extends StatelessWidget {
  const _Thumb({required this.photo, required this.selected, required this.onTap});

  final EvidenceOutModel photo;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    return CustomInkWell(
      key: ValueKey('pick-${photo.id}'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(KnSize.radiusMd),
      child: Container(
        width: 88,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(KnSize.radiusMd),
          border: Border.all(color: selected ? kn.brandPrimary : kn.borderDefault, width: selected ? 3 : 1),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(KnSize.radiusMd - 1),
          child: Stack(
            fit: StackFit.expand,
            children: [
              KnCoverImage(url: photo.thumbUrl ?? photo.url, placeholderIcon: LucideIcons.image),
              if (selected)
                Positioned(
                  right: 4,
                  top: 4,
                  child: CircleAvatar(
                    radius: 11,
                    backgroundColor: kn.brandPrimary,
                    child: Icon(LucideIcons.check, size: 14, color: kn.textOnBrand),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
