/// Build-time configuration: flutter run --dart-define=KN_API_URL=https://...
abstract final class Env {
  static const apiUrl = String.fromEnvironment('KN_API_URL', defaultValue: 'http://10.0.2.2:8000');
  static const flavor = String.fromEnvironment('KN_FLAVOR', defaultValue: 'local');
}
