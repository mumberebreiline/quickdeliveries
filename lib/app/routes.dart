import 'package:flutter/material.dart';

import '../screens/splash/splash_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/order/order_screen.dart';
import '../screens/vendor/vendor_login_screen.dart';
import '../screens/vendor/vendor_home_shell.dart';

class AppRoutes {
  AppRoutes._();

  static const String splash = '/';
  static const String home = '/home';
  static const String order = '/order';
  static const String vendorLogin = '/vendor-login';
  static const String vendorDashboard = '/vendor-dashboard';
}

final Map<String, WidgetBuilder> appRoutes = {
  AppRoutes.splash: (context) => const SplashScreen(),
  AppRoutes.home: (context) => const HomeScreen(),
  AppRoutes.order: (context) => const OrderScreen(),
  AppRoutes.vendorLogin: (context) => const VendorLoginScreen(),
  AppRoutes.vendorDashboard: (context) => const VendorHomeShell(),
};