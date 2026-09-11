import 'package:intl/intl.dart';

class Formatters {
  static String currency(num amount, {String currencyCode = 'KES', bool withCents = false}) {
    try {
      if (currencyCode == 'KES' || currencyCode == 'KSh') {
        final pattern = withCents ? '#,##0.00' : '#,##0';
        final formatted = NumberFormat(pattern).format(amount);
        return 'KSh $formatted/=';
      }

      final symbol = currencyCode == 'USD'
          ? '\$'
          : currencyCode == 'EUR'
              ? '€'
              : currencyCode == 'GBP'
                  ? '£'
                  : '$currencyCode ';
      final format = NumberFormat.currency(
        symbol: symbol,
        decimalDigits: 2,
      );
      return format.format(amount);
    } catch (_) {
      return 'KSh ${amount.toStringAsFixed(0)}/=';
    }
  }

  static String date(dynamic dateValue) {
    if (dateValue == null) return 'N/A';
    try {
      final DateTime dt = dateValue is DateTime
          ? dateValue
          : DateTime.parse(dateValue.toString());
      return DateFormat('dd/MM/yyyy').format(dt);
    } catch (_) {
      return dateValue.toString();
    }
  }

  static String shortDate(dynamic dateValue) {
    if (dateValue == null) return '';
    try {
      final DateTime dt = dateValue is DateTime
          ? dateValue
          : DateTime.parse(dateValue.toString());
      return DateFormat('dd/MM/yy').format(dt);
    } catch (_) {
      return dateValue.toString();
    }
  }
}
