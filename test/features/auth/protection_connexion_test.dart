import 'package:flutter_test/flutter_test.dart';

import 'package:projet/features/auth/domain/protection_connexion.dart';

void main() {
  final DateTime t0 = DateTime(2026, 10, 22, 10);

  group('Protection contre la force brute', () {
    test('Pas de blocage avant le 5e échec', () {
      TentativesConnexion t = const TentativesConnexion();
      for (int i = 0; i < 3; i++) {
        t = ProtectionConnexion.apresEchec(t, t0);
      }
      expect(ProtectionConnexion.essaisAvantBlocage(t), 2);
      expect(ProtectionConnexion.attente(t, t0), isNull);
    });

    test('Blocage de 5 min au 5e échec', () {
      const TentativesConnexion t = TentativesConnexion(echecs: 4);
      final TentativesConnexion apres = ProtectionConnexion.apresEchec(t, t0);
      expect(apres.bloqueJusqua, t0.add(const Duration(minutes: 5)));
      expect(
        ProtectionConnexion.attente(apres, t0.add(const Duration(minutes: 2))),
        const Duration(minutes: 3),
      );
      expect(
        ProtectionConnexion.attente(apres, t0.add(const Duration(minutes: 5))),
        isNull,
      );
    });

    test('Blocage progressif, 1 heure au maximum', () {
      expect(ProtectionConnexion.dureeBlocage(4), Duration.zero);
      expect(ProtectionConnexion.dureeBlocage(5), const Duration(minutes: 5));
      expect(ProtectionConnexion.dureeBlocage(6), const Duration(minutes: 10));
      expect(ProtectionConnexion.dureeBlocage(7), const Duration(minutes: 20));
      expect(ProtectionConnexion.dureeBlocage(20), const Duration(hours: 1));
    });

    test('Affichage du temps restant', () {
      expect(ProtectionConnexion.formater(const Duration(seconds: 45)), '45 s');
      expect(ProtectionConnexion.formater(const Duration(seconds: 61)), '2 min');
    });
  });

  group('Réponse de l\'API Turnstile', () {
    test('Jeton valide', () {
      final VerificationCaptcha v = VerificationCaptcha.depuisJson({
        'success': true,
        'error-codes': <String>[],
      });
      expect(v.valide, isTrue);
      expect(v.message, isEmpty);
    });

    test('Jeton déjà utilisé ou expiré', () {
      final VerificationCaptcha v = VerificationCaptcha.depuisJson({
        'success': false,
        'error-codes': ['timeout-or-duplicate'],
      });
      expect(v.valide, isFalse);
      expect(v.message, contains('expirée'));
    });
  });
}
