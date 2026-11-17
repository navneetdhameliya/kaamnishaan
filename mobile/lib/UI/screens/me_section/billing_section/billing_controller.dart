import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../../infrastructure/commons/constants/app_routes.dart';
import '../../../../infrastructure/data_access_layer/api_repository/billing_api_repository.dart';
import '../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../../infrastructure/lang/translation_service.dart';
import '../../../../infrastructure/models/api_models.g.dart';
import '../../../../infrastructure/shared/money_text.dart';
import '../../../common_widgets/kn_toast.dart';

/// One "This month" tile: "Reports · 52 of 60" with a bar.
class UsageView {
  const UsageView({required this.key, required this.label, required this.value, this.fraction, this.full = false});

  final String key;
  final String label;
  final String value;

  /// null = no limit (no bar)
  final double? fraction;

  /// At or near the limit (the number turns amber).
  final bool full;
}

/// M41 Plan and billing (owner only): the plan and its price, when the month starts again, how much of
/// each limit is used, and the next plan up. Paying online isn't switched on yet.
class BillingController extends GetxController {
  BillingController({required this.billing, required this.translation});

  final IBillingApiRepository billing;
  final TranslationService translation;

  final Rxn<BillingOutModel> data = Rxn<BillingOutModel>();

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    final result = await billing.billing();
    final d = result.dataOrNull;
    if (d == null) {
      final e = result.errorOrNull!;
      if (!e.isNetwork) KnToast.error(e.message);
      return;
    }
    data.value = d;
  }

  String _day(DateTime t) => DateFormat('d MMM', translation.currentCode).format(t.toLocal());

  String get planName => data.value?.plan.name ?? '';

  /// "Renews 22 Nov", or "Trial ends 1 Dec" while on trial.
  String get periodChip {
    final b = data.value;
    if (b == null) return '';
    final trial = b.trialEndsAt;
    return b.status == 'trial' && trial != null
        ? LangKeys.billTrialEnds.trParams({'date': _day(trial)})
        : LangKeys.billRenews.trParams({'date': _day(b.renewsAt)});
  }

  /// "₹499 / month"
  String get price {
    final p = data.value?.plan.price;
    return p == null ? LangKeys.billContact.tr : LangKeys.billPerMonth.trParams({'price': MoneyText.format(p)});
  }

  String get company => data.value?.company ?? '';

  static String _label(String key) => switch (key) {
        'technicians' => LangKeys.billTechnicians.tr,
        'reports' => LangKeys.billReports.tr,
        'ai_questions' => LangKeys.billAiQuestions.tr,
        _ => LangKeys.billCredits.tr,
      };

  List<UsageView> get usage => [
        for (final u in data.value?.usage ?? const <UsageTileModel>[])
          UsageView(
            key: u.key,
            label: _label(u.key),
            value: u.limit == null
                ? LangKeys.billNoLimit.trParams({'a': '${u.used}'})
                : LangKeys.billOf.trParams({'a': '${u.used}', 'b': '${u.limit}'}),
            fraction: u.limit == null || u.limit == 0 ? null : (u.used / u.limit!).clamp(0.0, 1.0),
            full: u.limit != null && u.limit! > 0 && u.used / u.limit! >= 0.9,
          ),
      ];

  PlanOutModel? get upgrade => data.value?.upgrade;

  /// "₹1,299/mo · 10 techs · 300 reports"
  String upgradeLine(PlanOutModel p) {
    final price = p.price == null ? '' : MoneyText.format(p.price!);
    final techs = '${p.technicianLimit ?? '∞'}';
    final reports = p.reportLimitMonthly;
    return reports == null
        ? LangKeys.billPlanLineFair.trParams({'price': price, 'techs': techs})
        : LangKeys.billPlanLine.trParams({'price': price, 'techs': techs, 'reports': '$reports'});
  }

  /// Changing the plan needs online payment, which isn't switched on yet.
  void onUpgradeTap() => KnToast.info(LangKeys.billPaymentsSoon.tr);

  Future<void> onUsageTap(UsageView u) async {
    if (u.key == 'credits') await Get.toNamed<void>(RoutesConstants.creditsScreen);
    await load();
  }
}
