import 'package:flutter_test/flutter_test.dart';

import 'package:projet/features/prescriptions/domain/authenticite_ordonnance.dart';
import 'package:projet/features/prescriptions/domain/calcul_prise_en_charge.dart';
import 'package:projet/features/prescriptions/domain/contrat_manager.dart';
import 'package:projet/features/prescriptions/domain/models/contrat_assurance.dart';
import 'package:projet/features/prescriptions/domain/models/dossier_remboursement.dart';
import 'package:projet/features/prescriptions/domain/models/ligne_ordonnance.dart';
import 'package:projet/features/prescriptions/domain/models/ordonnance.dart';
import 'package:projet/features/prescriptions/domain/models/vues_traitement.dart';
import 'package:projet/features/prescriptions/domain/service_cnam_simule.dart';
import 'package:projet/features/prescriptions/domain/substitution_generique.dart';

void main() {
  group('Métier 8 : exemple du cahier des charges (CNAM 85 %, mutuelle 80 %, 2 boîtes)', () {
    test('princeps à 12,500 DT : reste 1,940 DT', () {
      final DetailLigne d = CalculPriseEnCharge.calculerLigne(
        libelle: 'Amlor 5 mg',
        prixPublic: 12.5,
        prixReference: 9,
        boites: 2,
        tauxCnam: 0.85,
        apci: false,
        tauxMutuelle: 0.8,
      );
      expect(d.montant, 25);
      expect(d.base, 18);
      expect(d.partCnam, 15.3);
      expect(d.partMutuelle, 7.76);
      expect(d.resteACharge, 1.94);
    });

    test('générique à 9,000 DT : reste 0,540 DT', () {
      final DetailLigne d = CalculPriseEnCharge.calculerLigne(
        libelle: 'Amlodipine Générique 5 mg',
        prixPublic: 9,
        prixReference: 9,
        boites: 2,
        tauxCnam: 0.85,
        apci: false,
        tauxMutuelle: 0.8,
      );
      expect(d.montant, 18);
      expect(d.partCnam, 15.3);
      expect(d.partMutuelle, 2.16);
      expect(d.resteACharge, 0.54);
    });

    test('APCI : 100 % sur la base remboursable', () {
      final DetailLigne d = CalculPriseEnCharge.calculerLigne(
        libelle: 'Glucophage 850 mg',
        prixPublic: 6.5,
        prixReference: 4.2,
        boites: 2,
        tauxCnam: 0.85,
        apci: true,
      );
      expect(d.partCnam, 8.4);
      expect(d.resteACharge, 4.6);
    });

    test('part CNAM limitée au plafond restant', () {
      final DetailLigne d = CalculPriseEnCharge.calculerLigne(
        libelle: 'Tahor 20 mg',
        prixPublic: 32,
        boites: 1,
        tauxCnam: 0.85,
        apci: false,
        plafondRestant: 10,
      );
      expect(d.partCnam, 10);
      expect(d.resteACharge, 22);
    });
  });

  group('Métier 9 : service CNAM simulé', () {
    const DossierRemboursement dossier = DossierRemboursement(
      numero: 'REM-2026-0001',
      ordonnanceId: 1,
      contratId: 1,
      montantTotal: 25,
      partObligatoire: 15.3,
      partComplementaire: 7.76,
      resteACharge: 1.94,
      statut: StatutDossier.soumis,
    );

    test('contrat expiré → refusé avec motif', () {
      final ReponseCnam r = ServiceCnamSimule.repondre(dossier: dossier, contratActif: false);
      expect(r.statut, StatutDossier.refuse);
      expect(r.motifRefus, isNotNull);
    });

    test('part supérieure au plafond restant → partiel', () {
      final ReponseCnam r =
          ServiceCnamSimule.repondre(dossier: dossier, contratActif: true, plafondRestant: 10);
      expect(r.statut, StatutDossier.partiel);
      expect(r.partObligatoire, 10);
      expect(r.resteACharge, 7.24);
    });

    test('sinon accepté', () {
      final ReponseCnam r =
          ServiceCnamSimule.repondre(dossier: dossier, contratActif: true, plafondRestant: 500);
      expect(r.statut, StatutDossier.accepte);
      expect(r.partObligatoire, 15.3);
    });

    test('issue forcée pour la démo', () {
      final ReponseCnam r = ServiceCnamSimule.repondre(
        dossier: dossier,
        contratActif: true,
        issue: IssueCnam.refuser,
        motif: 'Ordonnance illisible',
      );
      expect(r.statut, StatutDossier.refuse);
      expect(r.motifRefus, 'Ordonnance illisible');
    });
  });

  group('Métier 4 : fin de stock', () {
    test('2 boîtes de 8, 13 prises faites, 3 par jour → 1 jour, alerte', () {
      final StockTraitement s = StockTraitement(
        ordonnance: Ordonnance(
          numero: 'ORD-2026-0001',
          patientId: 1,
          medecinId: 1,
          dateEmission: DateTime(2026, 10, 1),
          dateExpiration: DateTime(2026, 12, 30),
          statut: StatutOrdonnance.delivree,
        ),
        ligne: const LigneOrdonnance(
          ordonnanceId: 1,
          medicamentId: 1,
          dosePrise: 1,
          prisesParJour: 3,
          moments: ['matin', 'midi', 'soir'],
          dureeJours: 5,
          quantiteBoites: 2,
          quantiteDelivree: 2,
        ),
        medicament: 'Doliprane 1000 mg',
        forme: 'comprimé',
        unitesParBoite: 8,
        prisesFaites: 13,
      );
      expect(s.stock, 3);
      expect(s.joursRestants, 1);
      expect(s.alerte, isTrue);
    });
  });

  group('Métier 5 et 6', () {
    test('QR code lu ou numéro saisi', () {
      final QrOrdonnance? qr = AuthenticiteOrdonnance.lire('VITALWATCH|ORD-2026-0002|abc123');
      expect(qr?.numero, 'ORD-2026-0002');
      expect(qr?.hash, 'abc123');
      expect(AuthenticiteOrdonnance.lire(' ord-2026-0002 ')?.numero, 'ORD-2026-0002');
      expect(AuthenticiteOrdonnance.lire('   '), isNull);
    });

    test('dosage au format RxNorm', () {
      expect(SubstitutionGenerique.dosageRxNorm('5 mg'), '5 MG');
      expect(SubstitutionGenerique.dosageRxNorm('1 g'), '1000 MG');
      expect(SubstitutionGenerique.nomAnglais('Paracétamol'), 'acetaminophen');
    });

    test("numéro d'adhérent : 8 chiffres", () {
      ContratAssurance contrat(String numero) => ContratAssurance(
            patientId: 1,
            assuranceId: 1,
            numeroAdherent: numero,
            dateDebut: DateTime(2024, 1, 1),
          );
      expect(ContratManager.verifier(contrat('12345678')), isNull);
      expect(ContratManager.verifier(contrat('1234')), isNotNull);
      expect(ContratManager.verifier(contrat('1234567a')), isNotNull);
    });
  });
}
