import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:projet/core/theme/app_theme.dart';
import 'package:projet/features/auth/presentation/screens/login_screen.dart';

Widget _app() => MaterialApp(theme: AppTheme.light, home: const LoginScreen());

void main() {
  testWidgets('La page de connexion s\'affiche', (WidgetTester tester) async {
    await tester.pumpWidget(_app());

    expect(find.text('VitalWatch'), findsOneWidget);
    expect(find.text('Connexion'), findsOneWidget);
    expect(find.text('Se connecter'), findsOneWidget);
  });

  testWidgets('Champs vides : messages de validation',
      (WidgetTester tester) async {
    await tester.pumpWidget(_app());

    await tester.ensureVisible(find.text('Se connecter'));
    await tester.tap(find.text('Se connecter'));
    await tester.pump();

    expect(find.text("L'email est obligatoire"), findsOneWidget);
    expect(find.text('Le mot de passe est obligatoire'), findsOneWidget);
  });
}
