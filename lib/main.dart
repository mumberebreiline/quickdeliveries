import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'app/app.dart';
import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'providers/location_provider.dart';
import 'providers/order_provider.dart';
import 'providers/route_savings_provider.dart'; 

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => OrderProvider()),
        ChangeNotifierProvider(create: (_) => LocationProvider()),
        ChangeNotifierProvider(create: (_) => RouteSavingsProvider()),
      ],
      child: const App(),
    ),
  );
}
