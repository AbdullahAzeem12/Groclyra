import 'package:intl/intl.dart';

class CurrencyFormatter {
  static final NumberFormat _formatter = NumberFormat.currency(
    symbol: 'Rs. ',
    decimalDigits: 0,
    locale: 'en_PK',
  );

  static String format(num amount) {
    return _formatter.format(amount);
  }

  static String formatCompact(num amount) {
    final compact = NumberFormat.compactCurrency(
      symbol: 'Rs. ',
      decimalDigits: 1,
      locale: 'en_PK',
    );
    return compact.format(amount);
  }
}
