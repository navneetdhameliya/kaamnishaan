import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../lang/lang_keys.g.dart';

/// Times and dates as the home screens show them, in the app language.
abstract final class TimeUtils {
  /// "Good morning" before noon, "Good afternoon" until 5 PM, then "Good evening".
  static String greeting(DateTime now) {
    if (now.hour < 12) return LangKeys.homeGoodMorning.tr;
    if (now.hour < 17) return LangKeys.homeGoodAfternoon.tr;
    return LangKeys.homeGoodEvening.tr;
  }

  /// "Sat 31 Oct"
  static String shortDate(DateTime d, String locale) => DateFormat('EEE d MMM', locale).format(d);

  /// "11:30 AM" in the phone's time zone.
  static String clock(DateTime t, String locale) => DateFormat.jm(locale).format(t.toLocal());

  /// "M", "T", "W"… for the week chart.
  static String dayLetter(DateTime d, String locale) => DateFormat('EEEEE', locale).format(d);

  /// "just now", "10 min ago", "3 h ago", "2 days ago".
  static String ago(DateTime from, DateTime now) {
    final d = now.difference(from.toLocal());
    if (d.inMinutes < 1) return LangKeys.timeJustNow.tr;
    if (d.inMinutes < 60) return LangKeys.timeMinutesAgo.trParams({'count': '${d.inMinutes}'});
    if (d.inHours < 24) return LangKeys.timeHoursAgo.trParams({'count': '${d.inHours}'});
    return LangKeys.timeDaysAgo.trParams({'count': '${d.inDays}'});
  }
}
