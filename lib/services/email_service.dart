import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Sends real emails directly from the app — no server, no Cloud
/// Functions, no billing plan — using EmailJS
/// (https://www.emailjs.com), which is free up to 200 emails/month.
///
/// This needs a one-time, free setup on emailjs.com before it'll
/// actually send anything:
///   1. Create a free account at emailjs.com
///   2. Add an "Email Service" — connect a real inbox (e.g. Gmail) as
///      the sender. This gives you a Service ID.
///   3. Create an "Email Template" with variables like {{to_name}} and
///      {{message}} in the body. This gives you a Template ID.
///   4. Account → General → find your Public Key.
///   5. Paste all three below.
///
/// The public key is genuinely meant to be embedded in client code —
/// unlike an SMS gateway's secret key, EmailJS's public key can't be
/// used to do anything except send through the specific template you
/// configured, so this is safe to ship inside the app.
class EmailService {
  static const _serviceId = 'service_p2acu9e';
  static const _templateId = 'template_nhy7hds';
  static const _publicKey = 'INhu0icEdA-gZpKaO';

  static const _endpoint = 'https://api.emailjs.com/api/v1.0/email/send';

  /// Sends the "you've been assigned a delivery" email. Returns true on
  /// success — failures are logged, not thrown, so a delivery guy
  /// missing an email address (or EmailJS not being set up yet) never
  /// blocks the actual assignment itself, which already happened in
  /// Firestore regardless of whether this email goes out.
  Future<bool> sendDeliveryAssignmentEmail({
    required String toEmail,
    required String toName,
    required String destinationName,
    required int stopCount,
  }) {
    return _send(
      toEmail: toEmail,
      toName: toName,
      message:
          'You\'ve been assigned $stopCount delivery${stopCount == 1 ? '' : 's'}, '
          'starting with $destinationName. Open Quick Deliveries to get started.',
    );
  }

  /// Same idea, for the admin — a real-time email backup to her in-app
  /// "New order!" notification, reaching her even if the app isn't
  /// currently open. Uses the exact same "is this a genuinely new
  /// order" detection already built for the local notification —
  /// this is just a second thing that fires alongside it, not a
  /// separate detection system.
  Future<bool> sendVendorNewOrderEmail({
    required String toEmail,
    required String toName,
    required String customerName,
    required String destinationName,
  }) {
    return _send(
      toEmail: toEmail,
      toName: toName,
      message:
          '$customerName just placed a new order, delivering to '
          '$destinationName. Open Quick Deliveries to assign it.',
    );
  }

  Future<bool> _send({
    required String toEmail,
    required String toName,
    required String message,
  }) async {
    if (_serviceId == 'YOUR_EMAILJS_SERVICE_ID') {
      debugPrint('EmailJS not configured yet — skipping email.');
      return false;
    }
    if (toEmail.isEmpty) {
      debugPrint('No email on file for this recipient — skipping email.');
      return false;
    }

    try {
      final response = await http
          .post(
            Uri.parse(_endpoint),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'service_id': _serviceId,
              'template_id': _templateId,
              'user_id': _publicKey,
              'template_params': {
                'to_name': toName,
                'to_email': toEmail,
                'message': message,
              },
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) return true;
      debugPrint(
        'EmailJS send failed (${response.statusCode}): ${response.body}',
      );
      return false;
    } catch (e) {
      debugPrint('EmailJS send failed: $e');
      return false;
    }
  }
}
