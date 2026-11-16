/// Keys for saved values. Tokens go to secure storage, the rest to shared preferences.
abstract final class StorageConstants {
  // secure storage
  static const String accessToken = 'kn.access_token';
  static const String refreshToken = 'kn.refresh_token';

  // shared preferences
  static const String languageCode = 'kn.language';
  static const String onboardingSeen = 'kn.onboarding_seen';
  static const String deviceId = 'kn.device_id';
}
