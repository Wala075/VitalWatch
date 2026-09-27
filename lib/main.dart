import 'package:flutter/material.dart';

import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // TODO: initialiser Firebase ici une fois firebase_options.dart généré
  // await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const VitalWatchApp());
}
