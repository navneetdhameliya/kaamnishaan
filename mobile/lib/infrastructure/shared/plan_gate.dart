import 'dart:async';

import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../UI/common_widgets/kn_confirm_dialog.dart';
import '../../UI/common_widgets/kn_toast.dart';
import '../commons/constants/app_routes.dart';
import '../lang/lang_keys.g.dart';
import '../services/session_service.dart';

/// D-147: what the company's plan switches on. The server checks too; this saves a wasted tap.
abstract final class PlanFeature {
  static const assistant = 'ai_assistant';
  static const ownChecklists = 'custom_checklists';
  static const brandedPdf = 'branded_pdf';
}

abstract final class PlanGate {
  /// True when the plan has [feature] (or it isn't known yet: then the server decides).
  static bool has(SessionService session, String feature) {
    final company = session.me.value?.company;
    return company?.features?.contains(feature) ?? true;
  }

  /// True when the plan has [feature]; otherwise tells the owner which plan has it ("See plans" opens
  /// Billing) and everyone else to ask the owner.
  static bool check(String feature, {SessionService? session}) {
    final s = session ?? (Get.isRegistered<SessionService>() ? Get.find<SessionService>() : null);
    if (s == null || has(s, feature)) return true;
    unawaited(_tell(s, feature));
    return false;
  }

  static String _what(String feature) => switch (feature) {
        PlanFeature.assistant => LangKeys.planAssistant.tr,
        PlanFeature.ownChecklists => LangKeys.planChecklists.tr,
        _ => LangKeys.planBranded.tr,
      };

  static Future<void> _tell(SessionService s, String feature) async {
    if (s.me.value?.role != 'owner') return KnToast.info('${_what(feature)} ${LangKeys.planAskOwner.tr}');
    final go = await showKnConfirmDialog(
      title: LangKeys.planNotIncluded.tr,
      body: _what(feature),
      action: LangKeys.planSeePlans.tr,
      icon: LucideIcons.star,
    );
    if (go) await Get.toNamed<void>(RoutesConstants.billingScreen);
  }
}
