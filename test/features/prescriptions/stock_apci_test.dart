import 'package:flutter_test/flutter_test.dart';

import 'package:projet/features/prescriptions/domain/couverture_apci.dart';
import 'package:projet/features/prescriptions/domain/models/medicament.dart';
import 'package:projet/features/prescriptions/domain/regles_stock.dart';

void main() {
  group('Stock de la pharmacie', () {
    test('niveau : rupture, faible (≤ 5), normal', () {
      expect(ReglesStock.niveau(0), NiveauStock.rupture);
      expect(ReglesStock.niveau(1), NiveauStock.faible);
      expect(ReglesStock.niveau(5), NiveauStock.faible);
      expect(ReglesStock.niveau(6), NiveauStock.normal);
    });

    test('boîtes délivrables : reste à délivrer limité au stock', () {
      expect(ReglesStock.delivrable(3, 2), 2);
      expect(ReglesStock.delivrable(2, 10), 2);
      expect(ReglesStock.delivrable(2, 0), 0);
      expect(ReglesStock.delivrable(0, 10), 0);
    });

    test('entrée de stock entre 1 et 1000 boîtes', () {
      expect(ReglesStock.verifierEntree(null), isNotNull);
      expect(ReglesStock.verifierEntree(0), isNotNull);
      expect(ReglesStock.verifierEntree(10), isNull);
      expect(ReglesStock.verifierEntree(1001), isNotNull);
    });

    test('le stock est lu mais jamais écrit par toMap', () {
      final Medicament m = Medicament.fromMap({
        'id': 1,
        'nom_commercial': 'Tahor',
        'dci': 'atorvastatine',
        'forme': 'comprimé',
        'dosage': '20 mg',
        'unites_par_boite': 30,
        'prix_public': 32.0,
        'categorie': 'essentiel',
        'stock': 2,
      });
      expect(m.stock, 2);
      expect(m.toMap().containsKey('stock'), isFalse);
    });
  });

  group('APCI : ligne du médecin × liste du pharmacien', () {
    const Set<String> e11 = {'metformine', 'insuline glargine'};

    test('ligne non liée : taux normal', () {
      expect(
        CouvertureApci.statut(lienApci: false, codeApci: 'E11', dcisCouvertes: e11, dci: 'metformine'),
        StatutApci.nonDemandee,
      );
    });

    test('patient sans APCI : taux normal', () {
      expect(
        CouvertureApci.statut(lienApci: true, codeApci: null, dcisCouvertes: const {}, dci: 'metformine'),
        StatutApci.sansApci,
      );
    });

    test('médicament hors liste : taux normal', () {
      expect(
        CouvertureApci.statut(lienApci: true, codeApci: 'E11', dcisCouvertes: e11, dci: 'atorvastatine'),
        StatutApci.horsListe,
      );
    });

    test('médicament de la liste (princeps ou générique) : 100 %', () {
      final StatutApci s =
          CouvertureApci.statut(lienApci: true, codeApci: 'E11', dcisCouvertes: e11, dci: ' Metformine ');
      expect(s, StatutApci.couverte);
      expect(s.aCent, isTrue);
    });
  });
}
