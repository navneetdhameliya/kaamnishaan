import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../../infrastructure/commons/constants/app_routes.dart';
import '../../../../infrastructure/data_access_layer/api_repository/company_api_repository.dart';
import '../../../../infrastructure/data_access_layer/api_repository/files_api_repository.dart';
import '../../../../infrastructure/data_access_layer/networks/api_result.dart';
import '../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../../infrastructure/lang/translation_service.dart';
import '../../../../infrastructure/models/api_models.g.dart';
import '../../../../infrastructure/services/config_service.dart';
import '../../../../infrastructure/services/image_picker_service.dart';
import '../../../../infrastructure/services/session_service.dart';
import '../../../../infrastructure/shared/money_text.dart';
import '../../../common_widgets/kn_photo_source_sheet.dart';
import '../../../common_widgets/kn_toast.dart';

/// M39 Company settings: trade, country, logo, plan, the phone for customers and "Technicians can share reports".
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

  /// The "Phone for customers" and "Company name" sheets' boxes.
  final TextEditingController phoneBox = TextEditingController();
  final TextEditingController nameBox = TextEditingController();

  @override
  void onInit() {
    super.onInit();
    loadPlan();
  }

  @override
  void onClose() {
    phoneBox.dispose();
    nameBox.dispose();
    super.onClose();
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
    final money = MoneyText.format(price);
    // keep "₹1,299/mo" together when the line wraps
    return LangKeys.settingsPlanPrice.trParams({'name': name, 'price': money}).replaceAll('/', '\u2060/\u2060');
  }

  /// "Trial ends 1 Dec" while on trial.
  String? get planLine {
    final c = company;
    final end = c?.trialEndsAt;
    if (c?.status != 'trial' || end == null) return null;
    return LangKeys.settingsTrialEnds.trParams({'date': DateFormat('d MMM', translation.currentCode).format(end.toLocal())});
  }

  /// Shown as Call on the customer's report page (D-145); '' when none is set.
  String get contactPhone => company?.settings.contactPhone ?? '';

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

  /// M41 Plan and billing (the owner only).
  Future<void> onPlanTap() async {
    if (!isOwner) return KnToast.info(LangKeys.billOwnerOnlyToast.tr);
    await Get.toNamed<void>(RoutesConstants.billingScreen);
  }

  String get companyName => company?.name ?? '';

  /// Opens the name sheet for the owner.
  bool onNameTap() {
    if (!_ownerOnly()) return false;
    nameBox.text = companyName;
    return true;
  }

  /// Saves the new name; nothing to send when it is empty or the same.
  Future<bool> onNameSave() async {
    final n = nameBox.text.trim();
    if (n.isEmpty) return false;
    if (n == companyName) return true;
    return _save(() => companies.rename(n), message: LangKeys.settingsNameSaved.tr);
  }

  /// Opens the phone sheet for the owner, with the number as it is.
  bool onPhoneTap() {
    if (!_ownerOnly()) return false;
    phoneBox.text = contactPhone;
    return true;
  }

  /// Saves the number ('' hides Call); the sheet closes when it is saved.
  Future<bool> onPhoneSave() =>
      _save(() => companies.setContactPhone(phoneBox.text.trim()), message: LangKeys.settingsContactPhoneSaved.tr);

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
