import 'package:get/get.dart';

import '../data_access_layer/api_repository/config_api_repository.dart';
import '../models/api_models.g.dart';

/// Server settings used before login (countries for the phone field, trades for the profile).
class ConfigService extends GetxService {
  ConfigService(this._repository);

  final IConfigApiRepository _repository;
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

  Future<void> load() async {
    final result = await _repository.getConfig();
    if (result.dataOrNull != null) config.value = result.dataOrNull;
  }
}
