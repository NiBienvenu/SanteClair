import 'package:intl/intl.dart';

String formatMoney(int amount, [String currency = 'FBU']) {
  final digits = amount.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(' ');
    buffer.write(digits[i]);
  }
  return '$buffer $currency';
}

String _capitalize(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

/// "Mardi 24 Octobre"
String formatDayLong(DateTime date) => DateFormat('EEEE d MMMM', 'fr_FR')
    .format(date)
    .split(' ')
    .map(_capitalize)
    .join(' ');

/// "24 octobre 2024"
String formatDateFull(DateTime date) =>
    DateFormat('d MMMM yyyy', 'fr_FR').format(date);

/// "24 oct. 2024"
String formatDateShort(DateTime date) =>
    DateFormat('d MMM yyyy', 'fr_FR').format(date);

/// "14 mai 1992"
String formatBirthDate(DateTime date) =>
    DateFormat('d MMMM yyyy', 'fr_FR').format(date);

String formatTimeOfDay(int hour, int minute) =>
    '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

int minutesOf(String hhmm) {
  final parts = hhmm.split(':');
  return int.parse(parts[0]) * 60 + int.parse(parts[1]);
}

/// "1 92 05 75 112 045" -> "1 92 •• •• ••• 045"
String maskSecret(String value) {
  if (value.length <= 7) return value;
  final middle = value
      .substring(4, value.length - 3)
      .replaceAll(RegExp(r'\d'), '•');
  return '${value.substring(0, 4)}$middle${value.substring(value.length - 3)}';
}
