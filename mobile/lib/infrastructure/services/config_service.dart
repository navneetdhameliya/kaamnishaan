import 'dart:convert';

import 'package:get/get.dart';

import '../data_access_layer/api_repository/config_api_repository.dart';
import '../lang/changed_texts.dart';
import '../models/api_models.g.dart';
import 'preferences_service.dart';

/// Server settings used before login (countries for the phone field, trades for the profile).
class ConfigService extends GetxService {
  ConfigService(this._repository, {this.prefs});

  final IConfigApiRepository _repository;
  /// Keeps the changed texts for offline starts (not needed in tests).
  final PreferencesService? prefs;
  final Rxn<ConfigOutModel> config = Rxn<ConfigOutModel>();

  /// Used when the server can't be reached yet; the full list arrives with the config.
  static const fallbackCountries = [
    CountryOutModel(code: 'IN', name: 'India', dialCode: '+91', flag: '🇮🇳'),
    CountryOutModel(code: 'US', name: 'United States', dialCode: '+1', flag: '🇺🇸'),
  ];

  List<CountryOutModel> get countries => config.value?.countries ?? fallbackCountries;
  List<TradeOutModel> get trades => config.value?.trades ?? const [];

  CountryOutModel get defaultCountry {
    final code = config.value?.defaultCountry ?? 'IN';
    return countries.firstWhere((c) => c.code == code, orElse: () => countries.first);
  }

  @override
  void onInit() {
    super.onInit();
    // the texts from the last time the server was reached, so an offline start still shows them
    final saved = prefs?.changedTexts;
    if (saved == null) return;
    try {
      ChangedTexts.apply(Map<String, dynamic>.from(jsonDecode(saved) as Map));
    } on Object catch (_) {
      // a damaged copy is ignored; the next load replaces it
    }
  }

  Future<void> load() async {
    final result = await _repository.getConfig();
    if (result.dataOrNull != null) config.value = result.dataOrNull;
    await loadTexts();
  }

  /// A25: texts staff changed in the admin panel go on top of the built-in ones.
  Future<void> loadTexts() async {
    final texts = (await _repository.getTexts()).dataOrNull?.texts;
    if (texts == null) return;
    ChangedTexts.apply(texts);
    await prefs?.setChangedTexts(jsonEncode(texts));
  }
}
