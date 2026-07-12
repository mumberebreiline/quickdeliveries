import 'package:flutter/material.dart';

import '../screens/splash/splash_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/order/order_screen.dart';
import '../screens/vendor/vendor_login_screen.dart';
import '../screens/vendor/dashboard_screen.dart';
import '../screens/vendor/incoming_orders_screen.dart';
import '../screens/vendor/route_map_screen.dart';
import '../screens/vendor/delivery_history_screen.dart';

/// Every route name lives here. Add one line here + one in [appRoutes]
/// whenever a new screen is ready to be linked in.
///
/// Note: OrderStatusScreen isn't in this map — it needs an orderId passed
/// in, and a plain named-routes map can't carry that cleanly. It's opened
/// directly with MaterialPageRoute wherever it's needed (see order_screen.dart
/// after checkout). Everything else follows the usual
/// Navigator.pushNamed(context, AppRoutes.x) pattern.
class AppRoutes {
  AppRoutes._();

  static const String splash = '/';
  static const String home = '/home';
  static const String order = '/order';
  static const String vendorLogin = '/vendor-login';
  static const String vendorDashboard = '/vendor-dashboard';
  static const String vendorIncoming = '/vendor-incoming';
  static const String vendorRouteMap = '/vendor-route-map';
  static const String vendorHistory = '/vendor-history';
}

/// Maps each route name to the screen that should be shown.
/// Each teammate only touches the ONE line for the screen they own.
final Map<String, WidgetBuilder> appRoutes = {
  AppRoutes.splash: (context) => const SplashScreen(),
  AppRoutes.home: (context) => const HomeScreen(),
  AppRoutes.order: (context) => const OrderScreen(),
  AppRoutes.vendorLogin: (context) => const VendorLoginScreen(),
  AppRoutes.vendorDashboard: (context) => const VendorDashboardScreen(),
  AppRoutes.vendorIncoming: (context) => const IncomingOrdersScreen(),
  AppRoutes.vendorRouteMap: (context) => const RouteMapScreen(),
  AppRoutes.vendorHistory: (context) => const DeliveryHistoryScreen(),
};
