import 'package:flutter/material.dart';

import '../screens/splash/splash_screen.dart';
import '../screens/home/home_screen.dart';

/// Every route name lives here. Add one line here + one in [appRoutes
/// whenever a new screen is ready to be linked in.
class AppRoutes {
  AppRoutes._();

  static const String splash = '/';
  static const String home = '/home';
}

/// Maps each route name to the screen that should be shown.
/// Each teammate only touches the ONE line for the screen they own.
final Map<String, WidgetBuilder> appRoutes = {
  AppRoutes.splash: (context) => const SplashScreen(),
  AppRoutes.home: (context) =>  HomeScreen(),
};