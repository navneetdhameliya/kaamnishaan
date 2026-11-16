import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../../../infrastructure/data_access_layer/api_repository/company_api_repository.dart';
import '../../../../infrastructure/data_access_layer/api_repository/files_api_repository.dart';
import '../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../../infrastructure/lang/translation_service.dart';
import '../../../../infrastructure/models/api_models.g.dart';
import '../../../../infrastructure/services/config_service.dart';
import '../../../../infrastructure/services/image_picker_service.dart';
import '../../../../infrastructure/services/session_service.dart';
import '../../../../infrastructure/services/speech_service.dart';
import '../../../../infrastructure/shared/text_utils.dart';
import '../../../common_widgets/kn_photo_source_sheet.dart';
import '../../../common_widgets/kn_toast.dart';

/// M07 step 2: company name, trade, country and an optional logo. Creates the company
/// (the owner gets a 14-day trial), uploads the logo, then opens the app.
class CompanySetupController extends GetxController {
  CompanySetupController({
    required this.companies,
    required this.files,
    required this.session,
    required this.config,
    required this.picker,
    required this.speech,
    required this.translation,
  });

  final ICompanyApiRepository companies;
  final IFilesApiRepository files;
  final SessionService session;
  final ConfigService config;
  final IImagePickerService picker;
  final ISpeechService speech;
  final TranslationService translation;

  /// The company's starting time zone; the owner can change it later in Settings.
  static const timezones = {
    'IN': 'Asia/Kolkata',
    'US': 'America/New_York',
    'MX': 'America/Mexico_City',
    'ES': 'Europe/Madrid',
    'FR': 'Europe/Paris',
    'GB': 'Europe/London',
    'AE': 'Asia/Dubai',
  };

  final TextEditingController nameController = TextEditingController();
  final RxString name = ''.obs;
  final Rxn<TradeOutModel> trade = Rxn<TradeOutModel>();
  late final Rx<CountryOutModel> country = config.defaultCountry.obs;
  final Rxn<PickedImage> logo = Rxn<PickedImage>();
  final RxBool showNameError = false.obs;
  final RxBool showTradeError = false.obs;
  final RxBool apiCallLoader = false.obs;

  @override
  void onInit() {
    super.onInit();
    final trades = config.trades;
    if (trades.length == 1) trade.value = trades.first; // nothing to choose yet
  }

  bool get canSubmit => name.value.trim().isNotEmpty && trade.value != null;

  String get ownerFirstName => TextUtils.firstName(session.me.value?.name ?? '');

  String get previewMeta => LangKeys.companyPreviewMeta.trParams({
        'trade': trade.value?.name ?? 'HVAC',
        'country': country.value.name,
        'name': ownerFirstName,
      });

  String get timezone => timezones[country.value.code] ?? 'UTC';

  void onNameChanged(String value) {
    name.value = value;
    if (value.trim().isNotEmpty) showNameError.value = false;
  }

  void onTradeSelected(TradeOutModel value) {
    trade.value = value;
    showTradeError.value = false;
    Get.back<void>();
  }

  void onCountrySelected(CountryOutModel value) {
    country.value = value;
    Get.back<void>();
  }

  Future<void> onLogoTap() async {
    final source = await showKnPhotoSourceSheet(title: LangKeys.companyLogoTitle.tr);
    if (source == null) return;
    final picked = await picker.pick(source, maxSide: 1200);
    if (picked != null) logo.value = picked;
  }

  void onDisabledCreateTap() {
    showNameError.value = name.value.trim().isEmpty;
    showTradeError.value = trade.value == null;
  }

  void onHearNameErrorTap() => speech.speak(LangKeys.companyNameMissing.tr, languageCode: translation.currentCode);

  void onHearTradeErrorTap() => speech.speak(LangKeys.companyTradeMissing.tr, languageCode: translation.currentCode);

  Future<void> callCreateCompanyAPI() async {
    if (!canSubmit) return onDisabledCreateTap();
    apiCallLoader.value = true;
    final result = await companies.createCompany(
      name: name.value,
      trade: trade.value!.key,
      country: country.value.code,
      timezone: timezone,
    );
    if (!result.isSuccess) {
      apiCallLoader.value = false;
      final error = result.errorOrNull!;
      if (error.fields.containsKey('name')) {
        showNameError.value = true;
      } else if (error.fields.containsKey('trade')) {
        showTradeError.value = true;
      } else {
        KnToast.error(error.message);
      }
      return;
    }
    // the session now works in the new company; renew the token so it carries it
    final route = await session.refreshAndRoute();
    final picked = logo.value;
    if (picked != null && !await _uploadLogo(picked)) KnToast.info(LangKeys.companyLogoFailed.tr);
    apiCallLoader.value = false;
    Get.offAllNamed(route);
  }

  Future<bool> _uploadLogo(PickedImage image) async {
    final upload = await files.upload(kind: UploadKind.logo, bytes: image.bytes, contentType: image.contentType);
    final uploadId = upload.dataOrNull;
    if (uploadId == null) return false;
    return (await companies.setLogo(uploadId)).isSuccess;
  }

  @override
  void onClose() {
    nameController.dispose();
    super.onClose();
  }
}
