import 'package:flutter/material.dart';

import 'app.dart';
import 'core/config/email_config.dart';
import 'core/config/gemini_config.dart';
import 'core/config/turnstile_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EmailConfig.charger();
  await TurnstileConfig.charger();
  await GeminiConfig.charger();
  // TODO: initialiser Firebase ici une fois firebase_options.dart généré
  // await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const VitalWatchApp());
}
