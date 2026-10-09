import 'package:flutter_test/flutter_test.dart';

import 'package:projet/features/prescriptions/domain/formats_prescriptions.dart';
import 'package:projet/features/prescriptions/domain/models/assurance.dart';
import 'package:projet/features/prescriptions/domain/models/medicament.dart';
import 'package:projet/features/prescriptions/domain/models/taux_couverture.dart';
import 'package:projet/features/prescriptions/domain/regles_referentiels.dart';
import 'package:projet/features/prescriptions/domain/saisie.dart';

void main() {
  const Medicament amlor = Medicament(
    nomCommercial: 'Amlor',
    dci: 'amlodipine',
    forme: 'gélule',
    dosage: '5 mg',
    unitesParBoite: 30,
    prixPublic: 12.5,
    prixReference: 9,
    categorie: CategorieMedicament.essentiel,
  );

  group('Saisie', () {
    test('montants à la tunisienne : virgule ou point', () {
      expect(Saisie.decimal('12,500'), 12.5);
      expect(Saisie.decimal('12.5'), 12.5);
      expect(Saisie.decimal(' 1 200,5 '), 1200.5);
      expect(Saisie.decimal(''), isNull);
      expect(Saisie.decimal('abc'), isNull);
      expect(Saisie.montant('-3', champ: 'Le prix'), 'Le prix ne peut pas être négatif');
      expect(Saisie.montant('', obligatoire: false), isNull);
    });

    test('pourcentage entre 0 et 100, vide permis', () {
      expect(Saisie.pourcentage('85'), isNull);
      expect(Saisie.pourcentage(''), isNull);
      expect(Saisie.pourcentage('120'), isNotNull);
    });

    test('code CIM-10', () {
      expect(Saisie.codeCim10('E11'), isNull);
      expect(Saisie.codeCim10('e11.9'), isNull);
      expect(Saisie.codeCim10('11E'), isNotNull);
      expect(Saisie.codeCim10(''), isNotNull);
    });
  });

  group('Formats', () {
    test('dinars au millime et taux', () {
      expect(FormatsPrescriptions.dt(12.5), '12,500 DT');
      expect(FormatsPrescriptions.taux(0.85), '85 %');
      expect(FormatsPrescriptions.pourcent(0.335), '33,5');
    });
  });

  group('Contrôles du catalogue', () {
    test('médicament correct', () {
      expect(ReglesReferentiels.medicament(amlor), isNull);
    });

    test('prix de référence supérieur au prix public : refusé', () {
      const Medicament faux = Medicament(
        nomCommercial: 'Amlor',
        dci: 'amlodipine',
        forme: 'gélule',
        dosage: '5 mg',
        unitesParBoite: 30,
        prixPublic: 9,
        prixReference: 12.5,
        categorie: CategorieMedicament.essentiel,
      );
      expect(
        ReglesReferentiels.medicament(faux),
        'Le prix de référence ne peut pas dépasser le prix public',
      );
    });

    test('boîte vide : refusée', () {
      const Medicament vide = Medicament(
        nomCommercial: 'X',
        dci: 'x',
        forme: 'comprimé',
        dosage: '1 mg',
        unitesParBoite: 0,
        prixPublic: 1,
        categorie: CategorieMedicament.vital,
      );
      expect(ReglesReferentiels.medicament(vide), isNotNull);
    });
  });

  group('Contrôles des assurances', () {
    const Assurance cnam = Assurance(nom: 'CNAM', type: TypeAssurance.cnam, plafondAnnuel: 600);
    const Assurance mutuelle = Assurance(nom: 'Mutuelle', type: TypeAssurance.mutuelle);

    test('au moins un taux', () {
      expect(ReglesReferentiels.assurance(cnam, []), 'Indiquez au moins un taux de prise en charge');
    });

    test('la CNAM rembourse par catégorie, pas « tous »', () {
      expect(
        ReglesReferentiels.assurance(cnam, const [
          TauxCouverture(assuranceId: 1, categorie: TauxCouverture.tous, taux: 0.8),
        ]),
        isNotNull,
      );
    });

    test('mutuelle à 80 % sur tous les médicaments', () {
      expect(
        ReglesReferentiels.assurance(mutuelle, const [
          TauxCouverture(assuranceId: 2, categorie: TauxCouverture.tous, taux: 0.8),
        ]),
        isNull,
      );
    });

    test('taux hors de 0–100 % ou catégorie en double : refusés', () {
      expect(
        ReglesReferentiels.assurance(cnam, const [
          TauxCouverture(assuranceId: 1, categorie: 'vital', taux: 1.5),
        ]),
        isNotNull,
      );
      expect(
        ReglesReferentiels.assurance(cnam, const [
          TauxCouverture(assuranceId: 1, categorie: 'vital', taux: 1),
          TauxCouverture(assuranceId: 1, categorie: 'vital', taux: 0.85),
        ]),
        isNotNull,
      );
    });
  });
}
