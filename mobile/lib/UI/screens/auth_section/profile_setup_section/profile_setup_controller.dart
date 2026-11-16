import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../../../infrastructure/data_access_layer/api_repository/auth_api_repository.dart';
import '../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../../infrastructure/lang/translation_service.dart';
import '../../../../infrastructure/models/api_models.g.dart';
import '../../../../infrastructure/services/config_service.dart';
import '../../../../infrastructure/services/session_service.dart';
import '../../../../infrastructure/services/speech_service.dart';
import '../../../common_widgets/kn_toast.dart';
import '../phone_section/phone_controller.dart';

/// M11 About you: name (required), work and photo.
/// The backend saves the name today; work and photo are saved from a later step (see the PR notes).
class ProfileSetupController extends GetxController {
  ProfileSetupController({
    required this.repository,
    required this.session,
    required this.config,
    required this.speech,
    required this.translation,
  });

  final IAuthApiRepository repository;
  final SessionService session;
  final ConfigService config;
  final ISpeechService speech;
  final TranslationService translation;

  final TextEditingController nameController = TextEditingController();
  final FocusNode nameFocusNode = FocusNode();
  final RxBool showNameError = false.obs;
  final RxBool apiCallLoader = false.obs;
  final Rxn<TradeOutModel> trade = Rxn<TradeOutModel>();
  final RxString name = ''.obs;

  @override
  void onInit() {
    super.onInit();
    nameController.text = session.me.value?.name ?? '';
    name.value = nameController.text;
    final trades = config.trades;
    trade.value = trades.firstWhereOrNull((t) => t.key == 'hvac') ?? trades.firstOrNull;
  }

  bool get isValid => name.value.trim().isNotEmpty;

  String get initials {
    final parts = name.value.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    return parts.take(2).map((p) => p[0].toUpperCase()).join();
  }

  String get phoneText {
    final phone = session.me.value?.phone ?? '';
    final country = config.countries.firstWhereOrNull((c) => phone.startsWith(c.dialCode));
    if (country == null) return phone;
    return '${country.dialCode} ${PhoneController.formatNumber(country.dialCode, phone.substring(country.dialCode.length))}';
  }

  void onNameChanged(String value) {
    name.value = value;
    if (value.trim().isNotEmpty) showNameError.value = false;
  }

  /// No phone keyboard voice button needed: focusing the field shows the keyboard, whose mic types speech.
  void onMicTap() => nameFocusNode.requestFocus();

  void onChangePhotoTap() => KnToast.info(LangKeys.profilePhotoSoon.tr);

  void onTradeSelected(TradeOutModel value) {
    trade.value = value;
    Get.back<void>();
  }

  void onDisabledSaveTap() => showNameError.value = true;

  void onHearErrorTap() => speech.speak(LangKeys.profileNameMissing.tr, languageCode: translation.currentCode);

  Future<void> callSaveProfileAPI() async {
    if (!isValid) return onDisabledSaveTap();
    apiCallLoader.value = true;
    final result = await repository.updateName(name.value.trim());
    if (!result.isSuccess) {
      apiCallLoader.value = false;
      return KnToast.error(result.errorOrNull!.message);
    }
    session.me.value = result.dataOrNull;
    final route = await session.refreshAndRoute();
    apiCallLoader.value = false;
    Get.offAllNamed(route);
  }

  @override
  void onClose() {
    nameController.dispose();
    nameFocusNode.dispose();
    super.onClose();
  }
}
