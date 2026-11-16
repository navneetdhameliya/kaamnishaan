import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../../common_widgets/custom_inkwell.dart';
import '../../../../common_widgets/kn_dashed_border.dart';
import '../../../../commons/text_widgets/base/custom_base_text_widget.dart';
import '../../../../theme/kn_app_theme.dart';
import '../../../../theme/kn_tokens.g.dart';

/// M07 "Add company logo · Shows on every report PDF." with an Upload button (Figma "Logo upload").
class LogoUploadCard extends StatelessWidget {
  const LogoUploadCard({super.key, required this.onTap, this.logo});

  final VoidCallback onTap;
  final Uint8List? logo;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final text = context.knText;
    final radius = BorderRadius.circular(KnSize.radiusLg);
    return KnDashedBorder(
      color: kn.borderStrong,
      child: CustomInkWell(
        onTap: onTap,
        borderRadius: radius,
        semanticLabel: LangKeys.companyLogoTitle.tr,
        child: Ink(
          padding: const EdgeInsets.all(KnSize.space12),
          decoration: BoxDecoration(color: kn.bgSurface, borderRadius: radius),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(color: kn.bgSubtle, borderRadius: BorderRadius.circular(KnSize.radiusMd)),
                child: logo == null
                    ? Icon(LucideIcons.upload, size: 24, color: kn.textPrimary)
                    : Image.memory(logo!, fit: BoxFit.contain),
              ),
              const SizedBox(width: KnSize.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CustomBaseTextWidget(LangKeys.companyLogoTitle.tr, style: text.label),
                    const SizedBox(height: KnSize.space2),
                    CustomBaseTextWidget(LangKeys.companyLogoBody.tr, style: text.caption, color: kn.textSecondary),
                  ],
                ),
              ),
              const SizedBox(width: KnSize.space12),
              Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: KnSize.space16),
                alignment: Alignment.center,
                decoration: BoxDecoration(color: kn.actionSecondary, borderRadius: radius),
                child: CustomBaseTextWidget(
                  logo == null ? LangKeys.companyUpload.tr : LangKeys.companyChangeLogo.tr,
                  style: text.label,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
