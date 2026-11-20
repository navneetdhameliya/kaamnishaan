/// Keys for saved values. Tokens go to secure storage, the rest to shared preferences.
abstract final class StorageConstants {
  // secure storage
  static const String accessToken = 'kn.access_token';
  static const String refreshToken = 'kn.refresh_token';

  // shared preferences
  static const String languageCode = 'kn.language';
  static const String onboardingSeen = 'kn.onboarding_seen';
  static const String deviceId = 'kn.device_id';

  /// Texts staff changed in the admin panel (A25), so they show even when the app starts offline.
  static const String changedTexts = 'kn.changed_texts';

  /// The last Today screen (per person), shown when there is no internet.
  static String today(String userId) => 'kn.today.$userId';
}
