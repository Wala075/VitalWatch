import 'package:flutter_test/flutter_test.dart';

import 'package:projet/features/prescriptions/domain/models/ligne_ordonnance.dart';
import 'package:projet/features/prescriptions/domain/models/medicament.dart';
import 'package:projet/features/prescriptions/domain/models/ordonnance.dart';
import 'package:projet/features/prescriptions/domain/ordonnance_manager.dart';
import 'package:projet/features/prescriptions/domain/planning_prises.dart';
import 'package:projet/features/prescriptions/domain/posologie.dart';
import 'package:projet/features/prescriptions/domain/regles_ordonnance.dart';

void main() {
  const Medicament doliprane = Medicament(
    nomCommercial: 'Doliprane',
    dci: 'paracétamol',
    forme: 'comprimé',
    dosage: '1000 mg',
    unitesParBoite: 8,
    doseMaxJour: 4,
    prixPublic: 2.4,
    categorie: CategorieMedicament.intermediaire,
  );

  group("Contrôles de saisie d'une ligne", () {
    test('ligne correcte', () {
      expect(
        ReglesOrdonnance.ligne(
          medicament: doliprane,
          dosePrise: 1,
          moments: ['matin', 'midi', 'soir'],
          dureeJours: 5,
        ),
        isNull,
      );
    });

    test('dose journalière maximale dépassée (max 4)', () {
      expect(
        ReglesOrdonnance.ligne(
          medicament: doliprane,
          dosePrise: 2,
          moments: ['matin', 'midi', 'soir'],
          dureeJours: 5,
        ),
        'Dose journalière maximale dépassée (max 4 comprimés)',
      );
    });

    test('durée entre 1 et 365 jours', () {
      expect(
        ReglesOrdonnance.ligne(medicament: doliprane, dosePrise: 1, moments: ['matin'], dureeJours: 400),
        'Durée entre 1 et 365 jours',
      );
    });

    test('entre 1 et 6 prises par jour', () {
      expect(
        ReglesOrdonnance.ligne(medicament: doliprane, dosePrise: 1, moments: [], dureeJours: 5),
        'Entre 1 et 6 prises par jour',
      );
    });

    test("motif d'annulation : au moins 10 caractères", () {
      expect(ReglesOrdonnance.motifAnnulation('erreur'), isNotNull);
      expect(ReglesOrdonnance.motifAnnulation('erreur de posologie'), isNull);
    });

    test("expiration avant l'émission : refusée", () {
      expect(ReglesOrdonnance.dates(DateTime(2026, 10, 10), DateTime(2026, 10, 9)), isNotNull);
      expect(ReglesOrdonnance.dates(DateTime(2026, 10, 10), DateTime(2027, 1, 8)), isNull);
    });
  });

  group('Posologie lisible', () {
    test('« 1 comprimé · matin, midi, soir · 5 jours »', () {
      const LigneOrdonnance l = LigneOrdonnance(
        ordonnanceId: 1,
        medicamentId: 1,
        dosePrise: 1,
        prisesParJour: 3,
        moments: ['soir', 'matin', 'midi'],
        dureeJours: 5,
        quantiteBoites: 2,
      );
      expect(Posologie.texte(l, doliprane), '1 comprimé · matin, midi, soir · 5 jours');
    });

    test('unités selon la forme', () {
      expect(Posologie.unite('sirop', 10), 'ml');
      expect(Posologie.unite('aérosol doseur', 2), 'bouffées');
      expect(Posologie.unite('gélule', 0.5), 'gélule');
      expect(Posologie.boites(1), '1 boîte');
    });

    test("moments remis dans l'ordre de la journée, jusqu'à 6", () {
      expect(PlanningPrises.trier(['coucher', 'matin', 'inconnu']), ['matin', 'coucher']);
      expect(PlanningPrises.moments.length, 6);
    });
  });

  group('Cycle de vie', () {
    Ordonnance avec(StatutOrdonnance statut, int renouvellements) {
      return Ordonnance(
        numero: 'ORD-2026-0001',
        patientId: 1,
        medecinId: 1,
        dateEmission: DateTime(2026, 10, 1),
        dateExpiration: DateTime(2026, 12, 30),
        statut: statut,
        nbRenouvellements: renouvellements,
      );
    }

    test("seules les ordonnances validées ou en délivrance s'annulent", () {
      expect(OrdonnanceManager.estAnnulable(StatutOrdonnance.validee), isTrue);
      expect(OrdonnanceManager.estAnnulable(StatutOrdonnance.partiellementDelivree), isTrue);
      expect(OrdonnanceManager.estAnnulable(StatutOrdonnance.brouillon), isFalse);
      expect(OrdonnanceManager.estAnnulable(StatutOrdonnance.annulee), isFalse);
    });

    test('renouvelable : délivrée ou expirée, avec des renouvellements restants', () {
      expect(OrdonnanceManager.estRenouvelable(avec(StatutOrdonnance.delivree, 2)), isTrue);
      expect(OrdonnanceManager.estRenouvelable(avec(StatutOrdonnance.expiree, 1)), isTrue);
      expect(OrdonnanceManager.estRenouvelable(avec(StatutOrdonnance.delivree, 0)), isFalse);
      expect(OrdonnanceManager.estRenouvelable(avec(StatutOrdonnance.validee, 2)), isFalse);
    });
  });
}
