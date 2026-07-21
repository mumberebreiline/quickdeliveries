import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'app/app.dart';
import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'providers/location_provider.dart';
import 'providers/order_provider.dart';
import 'services/auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // So a customer can browse and order without ever seeing a login
  // screen — gives them a real, stable Firebase Auth UID quietly in the
  // background. If they later actually log in/register, that replaces
  // this with their real account.
  await AuthService().ensureSignedIn();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => OrderProvider()),
        ChangeNotifierProvider(create: (_) => LocationProvider()),
      ],
      child: const App(),
    ),
  );
}
