import 'package:intl/intl.dart';

/// Formats a number as Ugandan Shillings, e.g. 8000 -> "UGX 8,000".
String formatUgx(num amount) {
  final formatter = NumberFormat('#,###', 'en_US');
  return 'UGX ${formatter.format(amount)}';
}

/// Formats a DateTime as a friendly time, e.g. "1:30 PM".
String formatTime(DateTime time) {
  return DateFormat('h:mm a').format(time);
}

/// Formats a DateTime as a friendly date + time, e.g. "Mon, 1:30 PM".
String formatDayTime(DateTime time) {
  return DateFormat('EEE, h:mm a').format(time);
}
