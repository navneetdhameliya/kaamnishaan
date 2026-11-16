/// Build-time settings. Nothing secret lives here.
///
///   flutter run --dart-define=KN_API_URL=http://10.0.2.2:8000 --dart-define=KN_FLAVOR=local
///
/// Without flags the app talks to the live test server.
abstract final class Env {
  static const apiUrl = String.fromEnvironment('KN_API_URL', defaultValue: 'https://kaamnishaan-api.onrender.com');
  static const flavor = String.fromEnvironment('KN_FLAVOR', defaultValue: 'staging');

  static bool get isProduction => flavor == 'production';
}
