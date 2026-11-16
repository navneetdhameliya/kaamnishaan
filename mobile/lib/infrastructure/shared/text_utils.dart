/// Small text helpers shared by screens.
abstract final class TextUtils {
  /// "Suresh Shah" → "SS", "priya" → "P", "" → "".
  static String initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    return parts.take(2).map((p) => p[0].toUpperCase()).join();
  }

  /// "Suresh Shah" → "Suresh".
  static String firstName(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    return parts.isEmpty ? '' : parts.first;
  }

  static final _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]{2,}$');

  /// A light check (the backend checks properly): something@something.xx
  static bool isValidEmail(String value) => _email.hasMatch(value.trim());
}
