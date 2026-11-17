import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../../infrastructure/data_access_layer/api_repository/billing_api_repository.dart';
import '../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../../infrastructure/lang/translation_service.dart';
import '../../../../infrastructure/models/api_models.g.dart';
import '../../../../infrastructure/shared/money_text.dart';
import '../../../common_widgets/kn_toast.dart';

/// M41 Follow-up credits: what's left this month, what used it, and the top-up packs. Buying waits for
/// online payment.
class CreditsController extends GetxController {
  CreditsController({required this.billing, required this.translation});

  final IBillingApiRepository billing;
  final TranslationService translation;

  final Rxn<CreditsOutModel> data = Rxn<CreditsOutModel>();
  final RxnString picked = RxnString();

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    final result = await billing.credits();
    final d = result.dataOrNull;
    if (d == null) {
      final e = result.errorOrNull!;
      if (!e.isNetwork) KnToast.error(e.message);
      return;
    }
    data.value = d;
    picked.value ??= d.packs.isEmpty ? null : d.packs.first.id;
  }

  /// "Starter · resets on 22 Nov"
  String get subtitle {
    final d = data.value;
    if (d == null) return '';
    return LangKeys.credSub.trParams({
      'plan': d.plan,
      'date': DateFormat('d MMM', translation.currentCode).format(d.renewsAt.toLocal()),
    });
  }

  bool get noLimit => data.value?.balance == null;

  String get balance => '${data.value?.balance ?? '∞'}';

  /// "credits left of 300"
  String get leftLabel {
    final total = data.value?.planCredits;
    return total == null ? LangKeys.credNoLimit.tr : LangKeys.credLeftOf.trParams({'n': '$total'});
  }

  /// How much of this month's credits is left (the bar).
  double get fraction {
    final d = data.value;
    final total = d?.planCredits;
    if (d == null || total == null || total == 0) return d?.topupCredits == 0 ? 0 : 1;
    return ((total - d.planUsed) / total).clamp(0.0, 1.0);
  }

  String? get boughtLine {
    final n = data.value?.topupCredits ?? 0;
    return n == 0 ? null : LangKeys.credBoughtLeft.trParams({'n': '$n'});
  }

  CreditUseModel? _use(String kind) => data.value?.uses.firstWhereOrNull((u) => u.kind == kind);

  String get remindersValue => LangKeys.credN.trParams({'n': '${_use('reminders')?.credits ?? 0}'});

  String get callsLabel => LangKeys.credAiCalls.trParams({'n': '${_use('ai_calls')?.count ?? 0}'});

  String get callsValue => LangKeys.credN.trParams({'n': '${_use('ai_calls')?.credits ?? 0}'});

  bool get empty => !noLimit && (data.value?.balance ?? 1) == 0;

  List<CreditPackOutModel> get packs => data.value?.packs ?? const [];

  String price(CreditPackOutModel p) => MoneyText.format(p.price);

  /// "≈ 50 AI calls or 500 messages" for the first pack, "Save 12%" for bigger ones.
  String packHint(CreditPackOutModel p) {
    final rules = data.value?.rules;
    final first = packs.isEmpty ? null : packs.first;
    if (first != null && p.id != first.id && first.credits > 0 && p.credits > 0) {
      final save = (1 - (p.price.amount / p.credits) / (first.price.amount / first.credits)) * 100;
      if (save >= 1) return LangKeys.credSave.trParams({'n': '${save.floor()}'});
    }
    return LangKeys.credPackHint.trParams({
      'calls': '${p.credits ~/ (rules?.aiCall ?? 10)}',
      'msgs': '${p.credits ~/ (rules?.sms ?? 1)}',
    });
  }

  void onPick(String id) => picked.value = id;

  CreditPackOutModel? get pickedPack => packs.firstWhereOrNull((p) => p.id == picked.value);

  /// "Buy 500 credits · ₹799"
  String get buyLabel {
    final p = pickedPack;
    return p == null ? LangKeys.credTopUp.tr : LangKeys.credBuy.trParams({'n': '${p.credits}', 'price': price(p)});
  }

  bool get paymentsReady => data.value?.paymentsReady ?? false;

  void onBuyTap() => KnToast.info(LangKeys.credBuySoon.tr);
}
