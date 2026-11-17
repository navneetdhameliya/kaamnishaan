import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../../infrastructure/data_access_layer/api_repository/company_api_repository.dart';
import '../../../../infrastructure/data_access_layer/api_repository/files_api_repository.dart';
import '../../../../infrastructure/data_access_layer/networks/api_result.dart';
import '../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../../infrastructure/lang/translation_service.dart';
import '../../../../infrastructure/models/api_models.g.dart';
import '../../../../infrastructure/services/config_service.dart';
import '../../../../infrastructure/services/image_picker_service.dart';
import '../../../../infrastructure/services/session_service.dart';
import '../../../common_widgets/kn_photo_source_sheet.dart';
import '../../../common_widgets/kn_toast.dart';

/// M39 Company settings: trade, country, logo, plan and "Technicians can share reports".
/// Everyone in the office can look; only the owner can change (the server checks too).
class CompanySettingsController extends GetxController {
  CompanySettingsController({
    required this.companies,
    required this.files,
    required this.session,
    required this.config,
    required this.picker,
    required this.translation,
  });

  final ICompanyApiRepository companies;
  final IFilesApiRepository files;
  final SessionService session;
  final ConfigService config;
  final IImagePickerService picker;
  final TranslationService translation;

  final Rxn<PlanOutModel> plan = Rxn<PlanOutModel>();
  final RxBool savingLogo = false.obs;
  final RxBool saving = false.obs;

  @override
  void onInit() {
    super.onInit();
    loadPlan();
  }

  Future<void> loadPlan() async {
    final c = company;
    if (c == null) return;
    final list = (await companies.plans(currency: c.currency, locale: translation.currentCode)).dataOrNull;
    plan.value = list?.plans.firstWhereOrNull((p) => p.code == c.plan);
  }

  // ---- what it shows -----------------------------------------------------------------------

  CompanyOutModel? get company => session.me.value?.company;

  bool get isOwner => session.me.value?.role == 'owner';

  String get name => company?.name ?? '';

  String get tradeName {
    final key = company?.trade;
    return config.trades.firstWhereOrNull((t) => t.key == key)?.name ?? (key ?? '');
  }

  String get countryName {
    final code = company?.country;
    return config.countries.firstWhereOrNull((c) => c.code == code)?.name ?? (code ?? '');
  }

  /// "HVAC · United States"
  String get meta => [tradeName, countryName].where((s) => s.isNotEmpty).join(' · ');

  String? get logoUrl => company?.logoUrl;

  /// "Professional · ₹1,299/mo"; the plan's name alone when it has no price.
  String get planValue {
    final p = plan.value;
    final code = company?.plan ?? '';
    final name = p?.name ?? (code.isEmpty ? '' : code[0].toUpperCase() + code.substring(1));
    final price = p?.price;
    if (price == null) return name;
    final money = NumberFormat.simpleCurrency(
      locale: price.currency == 'INR' ? 'en_IN' : 'en_US',
      name: price.currency,
      decimalDigits: price.amount % 100 == 0 ? 0 : 2,
    ).format(price.amount / 100);
    return LangKeys.settingsPlanPrice.trParams({'name': name, 'price': money});
  }

  /// "Trial ends 1 Dec" while on trial.
  String? get planLine {
    final c = company;
    final end = c?.trialEndsAt;
    if (c?.status != 'trial' || end == null) return null;
    return LangKeys.settingsTrialEnds.trParams({'date': DateFormat('d MMM', translation.currentCode).format(end.toLocal())});
  }

  bool get techniciansCanShare => company?.settings.techniciansCanShare ?? false;

  // ---- actions -----------------------------------------------------------------------------

  bool _ownerOnly() {
    if (isOwner) return true;
    KnToast.info(LangKeys.settingsOwnerOnlyToast.tr);
    return false;
  }

  bool onTradeTap() => _ownerOnly() && config.trades.isNotEmpty;

  Future<void> onTradePicked(TradeOutModel t) async {
    Get.back<void>();
    if (t.key == company?.trade) return;
    await _save(() => companies.setTrade(t.key));
  }

  /// The country sets prices and phone numbers, so it stays as it was set up.
  void onCountryTap() => KnToast.info(LangKeys.settingsCountryFixed.tr);

  Future<void> onLogoTap() async {
    if (!_ownerOnly()) return;
    final source = await showKnPhotoSourceSheet(title: LangKeys.settingsLogo.tr);
    if (source == null) return;
    final picked = await picker.pick(source, maxSide: 1200);
    if (picked == null) return;
    savingLogo.value = true;
    final upload = await files.upload(kind: UploadKind.logo, bytes: picked.bytes, contentType: picked.contentType);
    final uploadId = upload.dataOrNull;
    if (uploadId == null) {
      savingLogo.value = false;
      return KnToast.error(upload.errorOrNull!.message);
    }
    await _save(() => companies.setLogo(uploadId), message: LangKeys.settingsLogoSaved.tr);
    savingLogo.value = false;
  }

  /// Plans and billing (M41) come with their own step.
  void onPlanTap() => KnToast.info(LangKeys.commonComingSoon.tr);

  Future<void> onShareChanged(bool on) async {
    if (!_ownerOnly()) return;
    await _save(() => companies.setTechniciansCanShare(on));
  }

  Future<bool> _save(Future<ApiResult<CompanyOutModel>> Function() call, {String? message}) async {
    saving.value = true;
    final result = await call();
    saving.value = false;
    final c = result.dataOrNull;
    if (c == null) {
      KnToast.error(result.errorOrNull!.message);
      return false;
    }
    session.setCompany(c);
    KnToast.success(message ?? LangKeys.settingsSaved.tr);
    return true;
  }
}
