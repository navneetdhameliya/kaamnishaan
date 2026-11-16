import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../commons/constants/storage_constants.dart';

/// Small saved settings (not secrets).
class PreferencesService {
  PreferencesService(this._prefs);

  final SharedPreferences _prefs;

  static Future<PreferencesService> create() async => PreferencesService(await SharedPreferences.getInstance());

  String? get languageCode => _prefs.getString(StorageConstants.languageCode);
  Future<void> setLanguageCode(String code) => _prefs.setString(StorageConstants.languageCode, code);

  bool get onboardingSeen => _prefs.getBool(StorageConstants.onboardingSeen) ?? false;
  Future<void> setOnboardingSeen() => _prefs.setBool(StorageConstants.onboardingSeen, true);

  /// A random id for this install, sent as X-Device-Id (not the phone's hardware id).
  Future<String> deviceId() async {
    final saved = _prefs.getString(StorageConstants.deviceId);
    if (saved != null) return saved;
    final id = const Uuid().v4();
    await _prefs.setString(StorageConstants.deviceId, id);
    return id;
  }
}
