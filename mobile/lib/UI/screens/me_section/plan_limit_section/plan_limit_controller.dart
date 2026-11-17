import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../../infrastructure/commons/constants/app_routes.dart';
import '../../../../infrastructure/data_access_layer/api_repository/billing_api_repository.dart';
import '../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../../infrastructure/lang/translation_service.dart';
import '../../../../infrastructure/models/api_models.g.dart';
import '../../../../infrastructure/shared/money_text.dart';
import '../../../common_widgets/kn_toast.dart';

/// M41 Plan limit reached: this month's reports are used up. Everything captured stays saved. The owner
/// is offered the next plan; others are asked to tell the owner.
class PlanLimitController extends GetxController {
  PlanLimitController({required this.billing, required this.translation});

  final IBillingApiRepository billing;
  final TranslationService translation;

  final Rxn<PlanStatusModel> data = Rxn<PlanStatusModel>();

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    final result = await billing.plan();
    final d = result.dataOrNull;
    if (d == null) {
      final e = result.errorOrNull!;
      if (!e.isNetwork) KnToast.error(e.message);
      return;
    }
    data.value = d;
  }

  bool get canUpgrade => data.value?.canUpgrade ?? false;

  /// "You used 60 of 60 reports"
  String get title {
    final r = data.value?.reports;
    return LangKeys.plTitle.trParams({'a': '${r?.used ?? 0}', 'b': '${r?.limit ?? 0}'});
  }

  String get body => canUpgrade ? LangKeys.plBodyOwner.tr : LangKeys.plBodyTeam.tr;

  /// "Starter · resets on 22 Nov"
  String get resets {
    final d = data.value;
    if (d == null) return '';
    return LangKeys.plResets.trParams({
      'plan': d.plan.name,
      'date': DateFormat('d MMM', translation.currentCode).format(d.renewsAt.toLocal()),
    });
  }

  double get fraction {
    final r = data.value?.reports;
    final l = r?.limit;
    return r == null || l == null || l == 0 ? 1 : (r.used / l).clamp(0.0, 1.0);
  }

  /// "₹499 / mo"
  /// The price stays on one line ("₹1,299 / mo" never breaks at the slash).
  String price(PlanOutModel p) => p.price == null
      ? LangKeys.billContact.tr
      : LangKeys.plPerMonth.trParams({'price': MoneyText.format(p.price!)}).replaceAll(' / ', '\u00A0/\u00A0');

  /// "60 reports · 3 techs"
  String limits(PlanOutModel p) {
    final techs = '${p.technicianLimit ?? '∞'}';
    return p.reportLimitMonthly == null
        ? LangKeys.plFairUse.trParams({'techs': techs})
        : LangKeys.plLimits.trParams({'reports': '${p.reportLimitMonthly}', 'techs': techs});
  }

  /// "Upgrade to Professional · ₹1,299"
  String get upgradeLabel {
    final u = data.value?.upgrade;
    if (u == null) return '';
    return LangKeys.plUpgrade.trParams({'name': u.name, 'price': u.price == null ? '' : MoneyText.format(u.price!)});
  }

  /// Plans change once online payment is on; for now the owner sees Plan and billing.
  Future<void> onUpgradeTap() async {
    await Get.offNamed<void>(RoutesConstants.billingScreen);
  }

  void onLaterTap() => Get.back<void>();
}
