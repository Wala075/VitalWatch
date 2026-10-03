import 'package:flutter_test/flutter_test.dart';

import 'package:projet/core/utils/password_hasher.dart';
import 'package:projet/core/utils/validators.dart';

void main() {
  group('Contrôle de saisie', () {
    test('CIN : exactement 8 chiffres', () {
      expect(Validators.cin('12345678'), isNull);
      expect(Validators.cin('1234567'), isNotNull);
      expect(Validators.cin('12345a78'), isNotNull);
      expect(Validators.cin(''), isNotNull);
    });

    test('Téléphone au format +216', () {
      expect(Validators.telephone('+216 22 123 456'), isNull);
      expect(Validators.telephone('22123456'), isNull);
      expect(Validators.telephone('0021622123456'), isNull);
      expect(Validators.telephone('+33612345678'), isNotNull);
      expect(Validators.telephone('1234'), isNotNull);
      expect(Validators.normaliserTelephone('22 123 456'), '+21622123456');
      expect(Validators.normaliserTelephone('0021622123456'), '+21622123456');
    });

    test('Date de naissance cohérente', () {
      final DateTime demain = DateTime.now().add(const Duration(days: 1));
      expect(Validators.dateNaissance(DateTime(1990, 5, 14)), isNull);
      expect(Validators.dateNaissance(demain), isNotNull);
      expect(Validators.dateNaissance(DateTime(1850)), isNotNull);
      expect(Validators.dateNaissance(null), isNotNull);
    });

    test('Email', () {
      expect(Validators.email('a.b@vitalwatch.tn'), isNull);
      expect(Validators.email('pas-un-email'), isNotNull);
      expect(Validators.emailOptionnel(''), isNull);
    });
  });

  group('Mot de passe temporaire haché', () {
    test('hachage salé et vérification', () {
      final String mdp = PasswordHasher.genererMotDePasseTemporaire();
      expect(mdp.length, 10);

      final String h1 = PasswordHasher.hacher(mdp);
      final String h2 = PasswordHasher.hacher(mdp);
      expect(h1, isNot(equals(h2))); // sel différent
      expect(h1.contains(mdp), isFalse); // jamais en clair
      expect(PasswordHasher.verifier(mdp, h1), isTrue);
      expect(PasswordHasher.verifier('mauvais', h1), isFalse);
    });
  });
}
