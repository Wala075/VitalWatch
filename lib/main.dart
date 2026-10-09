import 'package:flutter/material.dart';

import 'app.dart';
import 'core/config/email_config.dart';
import 'features/prescriptions/data/prescriptions_schema.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EmailConfig.charger();
  // Module 5 : tables Ordonnances & Assurance, compte pharmacien de démo,
  // expiration des ordonnances périmées. Sans effet sur le démarrage en cas d'erreur.
  await PrescriptionsSchema.initialiserAuDemarrage();
  // TODO: initialiser Firebase ici une fois firebase_options.dart généré
  // await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const VitalWatchApp());
}
