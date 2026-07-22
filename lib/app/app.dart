import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_user_profile.dart';
import '../providers/auth_provider.dart';
import '../providers/notification_watcher_provider.dart';
import 'routes.dart';
import 'theme.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quick Deliveries',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.themeData,
      initialRoute: AppRoutes.splash,
      routes: appRoutes,
      builder: (context, child) =>
          _NotificationGate(child: child ?? const SizedBox.shrink()),
    );
  }
}

/// Decides which notification watchers should be running, based on the
/// signed-in account's actual role — never guessed from which screen
/// someone's on. The vendor watcher only ever starts for role: vendor,
/// so a customer's phone can never end up buzzing about a stranger's
/// order. The customer watcher (their own orders only) is safe to run
/// for anyone who's signed in, vendor included.
class _NotificationGate extends StatefulWidget {
  final Widget child;
  const _NotificationGate({required this.child});

  @override
  State<_NotificationGate> createState() => _NotificationGateState();
}

class _NotificationGateState extends State<_NotificationGate> {
  UserRole? _lastRole;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final watcher = context.read<NotificationWatcherProvider>();

    if (auth.role != _lastRole) {
      _lastRole = auth.role;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (auth.role == UserRole.vendor) {
          watcher.startVendorWatcher();
        } else {
          watcher.stopVendorWatcher();
        }
      });
    }

    if (auth.isLoggedIn && !watcher.isWatchingCustomerOrders) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        watcher.startCustomerWatcher();
      });
    }

    return widget.child;
  }
}
