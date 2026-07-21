import 'package:intl/intl.dart';

String formatUgx(num amount) {
  final formatter = NumberFormat('#,###', 'en_US');
  return 'UGX ${formatter.format(amount)}';
}

String formatTime(DateTime time) => DateFormat('h:mm a').format(time);

String formatDayTime(DateTime time) => DateFormat('EEE, h:mm a').format(time);
