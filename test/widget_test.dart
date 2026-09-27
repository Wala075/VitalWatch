import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:projet/app.dart';

void main() {
  testWidgets('L\'application démarre sur le tableau de bord',
      (WidgetTester tester) async {
    await tester.pumpWidget(const VitalWatchApp());

    expect(find.text('VitalWatch'), findsOneWidget);
    expect(find.text('Services & Personnel'), findsOneWidget);
    expect(find.byIcon(Icons.monitor_heart), findsOneWidget);
  });
}
