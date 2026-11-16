import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../infrastructure/lang/lang_keys.g.dart';
import '../../infrastructure/services/image_picker_service.dart';
import 'kn_bottom_sheet.dart';
import 'kn_custom_button.dart';

/// Asks "Take a photo" or "Choose from gallery" and returns the choice (null if closed).
Future<PickSource?> showKnPhotoSourceSheet({required String title}) => showKnBottomSheet<PickSource>(
      title: title,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          KnCustomButton(
            key: const ValueKey('photo-camera'),
            text: LangKeys.profileTakePhoto.tr,
            icon: LucideIcons.camera,
            onTap: () => Get.back<PickSource>(result: PickSource.camera),
          ),
          const SizedBox(height: 8),
          KnCustomButton(
            key: const ValueKey('photo-gallery'),
            text: LangKeys.profileChoosePhoto.tr,
            icon: LucideIcons.image,
            variant: KnButtonVariant.secondary,
            onTap: () => Get.back<PickSource>(result: PickSource.gallery),
          ),
        ],
      ),
    );
