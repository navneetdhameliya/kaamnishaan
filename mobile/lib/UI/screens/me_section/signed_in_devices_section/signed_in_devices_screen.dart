import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../../infrastructure/models/api_models.g.dart';
import '../../../common_widgets/kn_back_button.dart';
import '../../../common_widgets/kn_custom_button.dart';
import '../../../common_widgets/kn_screen_footer.dart';
import '../../../commons/behaviour/behaviour.dart';
import '../../../commons/text_widgets/base/custom_base_text_widget.dart';
import '../../../theme/kn_app_theme.dart';
import '../../../theme/kn_tokens.g.dart';
import 'signed_in_devices_controller.dart';

/// Me → Signed-in devices (D-146).
class SignedInDevicesScreen extends GetView<SignedInDevicesController> {
  const SignedInDevicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final text = context.knText;
    return Scaffold(
      backgroundColor: kn.bgCanvas,
      bottomNavigationBar: Obx(
        () => controller.hasOthers
            ? KnScreenFooter(
                children: [
                  KnCustomButton(
                    key: const ValueKey('devices-sign-out-others'),
                    text: LangKeys.devicesOthers.tr,
                    icon: LucideIcons.logOut,
                    loading: controller.busy.value == 'others',
                    onTap: controller.onSignOutOthersTap,
                  ),
                ],
              )
            : const SizedBox.shrink(),
      ),
      body: SafeArea(
        bottom: false,
        child: ScrollConfiguration(
          behavior: const KnScrollBehavior(),
          child: RefreshIndicator(
            onRefresh: controller.load,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(KnSize.space16, 12, KnSize.space16, KnSize.space24),
              children: [
                Row(
                  children: [
                    const KnBackButton(),
                    const SizedBox(width: KnSize.space12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CustomBaseTextWidget(LangKeys.devicesTitle.tr, style: text.h3),
                          CustomBaseTextWidget(LangKeys.devicesSubtitle.tr, style: text.caption, color: kn.textSecondary),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: KnSize.space16),
                Obx(() {
                  final list = controller.devices.value;
                  if (list == null) {
                    return const Padding(
                      padding: EdgeInsets.all(KnSize.space24),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (controller.failed.value) {
                    return Padding(
                      key: const ValueKey('devices-failed'),
                      padding: const EdgeInsets.all(KnSize.space24),
                      child: Column(
                        children: [
                          CustomBaseTextWidget(LangKeys.devicesFailed.tr, style: text.body, textAlign: TextAlign.center),
                          const SizedBox(height: KnSize.space12),
                          KnCustomButton(text: LangKeys.devicesRetry.tr, onTap: controller.load),
                        ],
                      ),
                    );
                  }
                  return Column(
                    children: [for (final d in list) _DeviceCard(device: d, controller: controller)],
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DeviceCard extends StatelessWidget {
  const _DeviceCard({required this.device, required this.controller});

  final SignedInDeviceModel device;
  final SignedInDevicesController controller;

  IconData get _icon => switch (device.platform) {
        'web' || 'macos' => LucideIcons.monitor,
        'ipados' => LucideIcons.tablet,
        _ => LucideIcons.smartphone,
      };

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final text = context.knText;
    return Container(
      key: ValueKey('device-${device.id}'),
      margin: const EdgeInsets.only(bottom: KnSize.space8),
      padding: const EdgeInsets.all(KnSize.space12),
      decoration: BoxDecoration(
        color: kn.bgSurface,
        borderRadius: BorderRadius.circular(KnSize.radiusMd),
        border: Border.all(color: device.current ? kn.actionPrimary : kn.borderDefault),
      ),
      child: Row(
        children: [
          Icon(_icon, size: 24, color: kn.textSecondary),
          const SizedBox(width: KnSize.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CustomBaseTextWidget(controller.name(device), style: text.label),
                const SizedBox(height: 2),
                CustomBaseTextWidget(controller.line(device), style: text.caption, color: kn.textSecondary),
              ],
            ),
          ),
          if (!device.current)
            Obx(
              () => controller.busy.value == device.id
                  ? const SizedBox.square(dimension: 24, child: CircularProgressIndicator(strokeWidth: 2.5))
                  : TextButton(
                      key: ValueKey('device-sign-out-${device.id}'),
                      onPressed: () => controller.onSignOutTap(device),
                      child: CustomBaseTextWidget(LangKeys.devicesSignOut.tr, style: text.label, color: kn.statusDanger),
                    ),
            ),
        ],
      ),
    );
  }
}
