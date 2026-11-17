import 'package:intl/intl.dart';

import '../models/api_models.g.dart';

/// Prices from the server (minor units) as people read them: "₹499", "$9", "$9.50".
abstract final class MoneyText {
  static String format(MoneyModel m) => NumberFormat.simpleCurrency(
        locale: m.currency == 'INR' ? 'en_IN' : 'en_US',
        name: m.currency,
        decimalDigits: m.amount % 100 == 0 ? 0 : 2,
      ).format(m.amount / 100);
}
