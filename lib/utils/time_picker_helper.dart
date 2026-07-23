import 'package:flutter/material.dart';

/// Opens the standard time picker, then rejects anything earlier than
/// right now.
///
/// Flutter's built-in time picker has no way to grey out or disable
/// past times while picking — there's no minimum-time parameter — so
/// the only honest way to enforce "no times in the past" is to validate
/// *after* the customer picks one, and reject it outright if it's
/// already passed today, rather than silently rolling it over to
/// tomorrow. That silent-rollover behavior is what this replaces: it
/// was technically harmless but meant the customer never actually knew
/// their selection got moved to a different day.
///
/// One shared implementation, used everywhere a delivery time gets
/// picked — so this rule only has to be written (and gotten right)
/// once, not copy-pasted into every screen that needs it.
Future<TimeOfDay?> pickFutureDeliveryTime(BuildContext context) async {
  final now = TimeOfDay.now();
  final picked = await showTimePicker(context: context, initialTime: now);
  if (picked == null) return null;

  final nowDateTime = DateTime.now();
  final pickedDateTime = DateTime(
    nowDateTime.year,
    nowDateTime.month,
    nowDateTime.day,
    picked.hour,
    picked.minute,
  );

  if (pickedDateTime.isBefore(nowDateTime)) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'That time has already passed today — please choose a later time',
          ),
        ),
      );
    }
    return null;
  }

  return picked;
}
