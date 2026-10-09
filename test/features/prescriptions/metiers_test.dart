import 'package:flutter_test/flutter_test.dart';

import 'package:projet/features/prescriptions/domain/authenticite_ordonnance.dart';
import 'package:projet/features/prescriptions/domain/calcul_boites.dart';
import 'package:projet/features/prescriptions/domain/models/ligne_ordonnance.dart';
import 'package:projet/features/prescriptions/domain/models/ordonnance.dart';
import 'package:projet/features/prescriptions/domain/models/prise.dart';
import 'package:projet/features/prescriptions/domain/planning_prises.dart';

void main() {
  group('Métier 2 : calcul des boîtes', () {
    test('exemple du cahier des charges : 1 × 3 × 10 ÷ 20 = 1,5 → 2 boîtes', () {
      expect(
        CalculBoites.calculer(dosePrise: 1, prisesParJour: 3, dureeJours: 10, unitesParBoite: 20),
        2,
      );
    });

    test('compte juste : 1 × 1 × 30 ÷ 30 = 1 boîte', () {
      expect(
        CalculBoites.calculer(dosePrise: 1, prisesParJour: 1, dureeJours: 30, unitesParBoite: 30),
        1,
      );
    });

    test("pas de boîte en trop à cause d'un arrondi (0,1 × 3 × 10 ÷ 3)", () {
      expect(
        CalculBoites.calculer(dosePrise: 0.1, prisesParJour: 3, dureeJours: 10, unitesParBoite: 3),
        1,
      );
    });

    test('au moins une boîte', () {
      expect(
        CalculBoites.calculer(dosePrise: 0.5, prisesParJour: 1, dureeJours: 1, unitesParBoite: 30),
        1,
      );
    });
  });

  group('Métier 3 : planning des prises', () {
    test("une prise par jour et par moment, dans l'ordre de la journée", () {
      final List<Prise> p = PlanningPrises.generer(
        ligneId: 1,
        momentsLigne: ['soir', 'matin'],
        dureeJours: 2,
        debut: DateTime(2026, 10, 9),
      );
      expect(p.length, 4);
      expect(p[0].heurePrevue, DateTime(2026, 10, 9, 8));
      expect(p[1].heurePrevue, DateTime(2026, 10, 9, 20));
      expect(p[3].heurePrevue, DateTime(2026, 10, 10, 20));
      expect(p[0].statut, StatutPrise.prevue);
    });

    test('validée à 14 h : le matin est sauté mais le total est conservé', () {
      final List<Prise> p = PlanningPrises.generer(
        ligneId: 1,
        momentsLigne: ['matin', 'soir'],
        dureeJours: 3,
        debut: DateTime(2026, 10, 9, 14),
      );
      expect(p.length, 6);
      expect(p.first.heurePrevue, DateTime(2026, 10, 9, 20));
      expect(p.last.heurePrevue, DateTime(2026, 10, 12, 8));
    });
  });

  group('Métier 5 : signature anti-fraude', () {
    final Ordonnance o = Ordonnance(
      numero: 'ORD-2026-0001',
      patientId: 1,
      medecinId: 1,
      dateEmission: DateTime(2026, 10, 9),
      dateExpiration: DateTime(2027, 1, 7),
    );
    const LigneOrdonnance a = LigneOrdonnance(
      ordonnanceId: 1,
      medicamentId: 7,
      dosePrise: 1,
      prisesParJour: 1,
      moments: ['matin'],
      dureeJours: 30,
      quantiteBoites: 1,
    );
    const LigneOrdonnance b = LigneOrdonnance(
      ordonnanceId: 1,
      medicamentId: 1,
      dosePrise: 1,
      prisesParJour: 3,
      moments: ['matin', 'midi', 'soir'],
      dureeJours: 5,
      quantiteBoites: 2,
    );

    test("le hash ne dépend pas de l'ordre des lignes", () {
      expect(AuthenticiteOrdonnance.signer(o, [a, b]), AuthenticiteOrdonnance.signer(o, [b, a]));
      expect(AuthenticiteOrdonnance.signer(o, [a, b]).length, 64);
    });

    test('une dose modifiée → « Ordonnance modifiée »', () {
      final Ordonnance signee = o.copyWith(hashSignature: AuthenticiteOrdonnance.signer(o, [a, b]));
      expect(AuthenticiteOrdonnance.verifier(signee, [a, b]), isTrue);

      const LigneOrdonnance falsifiee = LigneOrdonnance(
        ordonnanceId: 1,
        medicamentId: 1,
        dosePrise: 2,
        prisesParJour: 3,
        moments: ['matin', 'midi', 'soir'],
        dureeJours: 5,
        quantiteBoites: 2,
      );
      expect(AuthenticiteOrdonnance.verifier(signee, [a, falsifiee]), isFalse);
      expect(AuthenticiteOrdonnance.verifier(o, [a, b]), isFalse); // pas signée
    });
  });

  group('Modèles', () {
    test('ligne : les moments passent par la base sans changer', () {
      const LigneOrdonnance l = LigneOrdonnance(
        ordonnanceId: 3,
        medicamentId: 4,
        dosePrise: 0.5,
        prisesParJour: 2,
        moments: ['matin', 'soir'],
        dureeJours: 10,
        quantiteBoites: 1,
        lienApci: true,
      );
      final Map<String, Object?> map = l.toMap();
      expect(map['moments'], 'matin,soir');
      final LigneOrdonnance relue = LigneOrdonnance.fromMap({...map, 'id': 9});
      expect(relue.id, 9);
      expect(relue.moments, ['matin', 'soir']);
      expect(relue.lienApci, isTrue);
      expect(relue.resteADelivrer, 1);
    });

    test('ordonnance : statuts et dates relus depuis la base', () {
      final Ordonnance relue = Ordonnance.fromMap({
        'id': 1,
        'numero': 'ORD-2026-0001',
        'patient_id': 1,
        'medecin_id': 2,
        'date_emission': '2026-10-09',
        'date_expiration': '2027-01-07',
        'statut': 'partiellement_delivree',
      });
      expect(relue.statut, StatutOrdonnance.partiellementDelivree);
      expect(relue.statut.estActive, isTrue);
      expect(relue.estModifiable, isFalse);
      expect(relue.toMap()['date_emission'], '2026-10-09');
    });
  });
}
