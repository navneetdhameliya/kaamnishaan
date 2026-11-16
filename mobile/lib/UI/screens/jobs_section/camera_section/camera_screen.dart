import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../../infrastructure/services/camera_service.dart';
import '../../../common_widgets/custom_inkwell.dart';
import '../../../common_widgets/kn_dashed_border.dart';
import '../../../commons/text_widgets/base/custom_base_text_widget.dart';
import '../../../theme/kn_app_theme.dart';
import '../../../theme/kn_tokens.g.dart';
import 'camera_controller.dart';
import 'custom_widgets/camera_controls.dart';
import 'custom_widgets/camera_off_view.dart';

/// M20 Camera (Figma 22:1136; camera off 22:1189).
class CameraScreen extends GetView<CameraScreenController> {
  const CameraScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final status = controller.status.value;
      if (status == CameraOpenResult.denied) {
        return CameraOffView(onOpenSettings: controller.onOpenSettingsTap, onNotNow: controller.onCloseTap);
      }
      return AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(backgroundColor: KnPrimitive.mocha950, body: _camera(context, status)),
      );
    });
  }

  Widget _round({required Key key, required IconData icon, required String label, required VoidCallback onTap}) =>
      CustomInkWell(
        key: key,
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        semanticLabel: label,
        child: Ink(
          width: 44,
          height: 44,
          decoration: BoxDecoration(color: KnPrimitive.mocha950.withValues(alpha: 0.6), shape: BoxShape.circle),
          child: Icon(icon, size: 22, color: KnPrimitive.cream50),
        ),
      );

  Widget _camera(BuildContext context, CameraOpenResult? status) {
    final text = context.knText;
    final top = MediaQuery.paddingOf(context).top;
    final prompt = controller.prompt;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (status == CameraOpenResult.ready)
          controller.camera.preview()
        else if (status == CameraOpenResult.unavailable)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(KnSize.space32),
              child: CustomBaseTextWidget(
                LangKeys.cameraUnavailable.tr,
                style: text.bodyLg,
                color: KnPrimitive.cream50,
                textAlign: TextAlign.center,
              ),
            ),
          ),
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: top + 88,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [KnPrimitive.mocha950.withValues(alpha: 0.6), KnPrimitive.mocha950.withValues(alpha: 0)],
              ),
            ),
          ),
        ),
        Positioned(
          left: KnSize.space16,
          right: KnSize.space16,
          top: top + 12,
          child: Row(
            children: [
              _round(
                key: const ValueKey('camera-close'),
                icon: LucideIcons.x,
                label: LangKeys.cameraClose.tr,
                onTap: controller.onCloseTap,
              ),
              Expanded(
                child: Center(
                  child: Container(
                    key: const ValueKey('stage-pill'),
                    padding: const EdgeInsets.symmetric(horizontal: KnSize.space12, vertical: KnSize.space8),
                    decoration: BoxDecoration(
                      color: KnPrimitive.green650,
                      borderRadius: BorderRadius.circular(KnSize.radiusFull),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(LucideIcons.camera, size: 16, color: KnPrimitive.cream100),
                        const SizedBox(width: 6),
                        CustomBaseTextWidget(controller.stageLabel, style: text.labelSm, color: KnPrimitive.cream100),
                      ],
                    ),
                  ),
                ),
              ),
              _round(
                key: const ValueKey('camera-guide'),
                icon: LucideIcons.sparkles,
                label: LangKeys.cameraHints.tr,
                onTap: controller.onToggleGuide,
              ),
            ],
          ),
        ),
        if (controller.showGuide.value && status == CameraOpenResult.ready)
          Align(
            alignment: const Alignment(0, -0.3),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                KnDashedBorder(
                  color: KnPrimitive.cream50.withValues(alpha: 0.9),
                  radius: 24,
                  dash: 12,
                  gap: 8,
                  strokeWidth: 2,
                  child: const SizedBox(width: 220, height: 220),
                ),
                if (prompt != null) ...[
                  const SizedBox(height: 24),
                  Container(
                    key: const ValueKey('shot-hint'),
                    padding: const EdgeInsets.symmetric(horizontal: KnSize.space12, vertical: KnSize.space8),
                    decoration: BoxDecoration(
                      color: KnPrimitive.mocha950.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(KnSize.radiusFull),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(LucideIcons.circleAlert, size: 16, color: KnPrimitive.cream50),
                        const SizedBox(width: 6),
                        Flexible(
                          child: CustomBaseTextWidget(prompt.prompt, style: text.labelSm, color: KnPrimitive.cream50),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: CameraControls(
            thumbs: controller.thumbs,
            total: controller.totalCount,
            busy: controller.busy.value,
            onShutter: controller.onShutterTap,
            onGallery: controller.onGalleryTap,
            onDone: controller.onDoneTap,
          ),
        ),
        IgnorePointer(
          child: AnimatedOpacity(
            opacity: controller.flash.value ? 0.7 : 0,
            duration: const Duration(milliseconds: 90),
            child: const ColoredBox(color: Colors.white),
          ),
        ),
      ],
    );
  }
}
