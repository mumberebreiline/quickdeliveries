import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Fires a system notification banner while the app is running — open,
/// backgrounded, or minimized. This is genuinely different from a true
/// server push (which would still arrive if the app were fully force-
/// closed or the phone rebooted) — that would need Cloud Functions,
/// which needs Firebase's paid Blaze plan. This approach needs neither:
/// no server component, no billing account, and it covers the realistic
/// case well — someone who placed an order or is actively vending
/// usually has the app open or recently backgrounded, not force-quit.
class LocalNotificationService {
  static final LocalNotificationService _instance =
      LocalNotificationService._internal();
  factory LocalNotificationService() => _instance;
  LocalNotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(initSettings);

    // Android 13+ requires this to be granted at runtime, not just
    // declared in the manifest — without it, notifications are silently
    // never shown, no error thrown.
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();

    const channel = AndroidNotificationChannel(
      'order_updates',
      'Order Updates',
      description: 'Notifies about new orders and order status changes',
      importance: Importance.high,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);

    _isInitialized = true;
  }

  Future<void> show({required String title, required String body}) async {
    if (!_isInitialized) await initialize();

    const androidDetails = AndroidNotificationDetails(
      'order_updates',
      'Order Updates',
      channelDescription: 'Notifies about new orders and order status changes',
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Unique-ish id so multiple notifications don't overwrite each other
    // in the system tray.
    final id = DateTime.now().millisecondsSinceEpoch.remainder(100000);
    await _plugin.show(id, title, body, details);
  }
}
