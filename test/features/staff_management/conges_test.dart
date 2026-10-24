import 'package:flutter_test/flutter_test.dart';

import 'package:projet/features/staff_management/domain/conges.dart';
import 'package:projet/models/utilisateur.dart';

void main() {
  final DateTime aujourdHui = DateTime(2026, 10, 22);

  group('Dates', () {
    test('Nombre de jours, fin incluse', () {
      expect(RegleConges.nbJours(DateTime(2026, 11, 2), DateTime(2026, 11, 6)), 5);
      expect(RegleConges.nbJours(DateTime(2026, 11, 2), DateTime(2026, 11, 2)), 1);
      // Changement d'heure (fin octobre) sans effet.
      expect(RegleConges.nbJours(DateTime(2026, 10, 24), DateTime(2026, 10, 27)), 4);
    });

    test('Chevauchement', () {
      final DateTime a1 = DateTime(2026, 11, 2), a2 = DateTime(2026, 11, 6);
      expect(RegleConges.chevauchent(a1, a2, DateTime(2026, 11, 6), DateTime(2026, 11, 9)), isTrue);
      expect(RegleConges.chevauchent(a1, a2, DateTime(2026, 11, 7), DateTime(2026, 11, 9)), isFalse);
      expect(RegleConges.chevauchent(a1, a2, DateTime(2026, 10, 30), DateTime(2026, 11, 1)), isFalse);
    });

    test('Contrôle des dates', () {
      expect(RegleConges.verifierDates(DateTime(2026, 11, 2), DateTime(2026, 11, 6), aujourdHui), isNull);
      expect(RegleConges.verifierDates(DateTime(2026, 10, 21), DateTime(2026, 10, 25), aujourdHui), isNotNull);
      expect(RegleConges.verifierDates(DateTime(2026, 11, 6), DateTime(2026, 11, 2), aujourdHui), isNotNull);
      expect(RegleConges.verifierDates(DateTime(2026, 11, 1), DateTime(2027, 3, 1), aujourdHui), isNotNull);
    });

    test('Jours répartis sur deux années', () {
      expect(
        RegleConges.joursParAnnee(DateTime(2026, 12, 29), DateTime(2027, 1, 3)),
        {2026: 3, 2027: 3},
      );
    });
  });

  group('Solde de congé annuel (30 jours)', () {
    test('Dans le solde', () {
      expect(
        RegleConges.verifierSolde(DateTime(2026, 11, 2), DateTime(2026, 11, 11), {2026: 20}),
        isNull,
      );
    });

    test('Solde dépassé', () {
      final String? erreur = RegleConges.verifierSolde(
        DateTime(2026, 11, 2),
        DateTime(2026, 11, 12),
        {2026: 20},
      );
      expect(erreur, contains('10 jour(s) restant(s)'));
    });
  });

  group('Effectif minimum du service', () {
    final DateTime debut = DateTime(2026, 11, 2);
    final DateTime fin = DateTime(2026, 11, 6);

    test('Un collègue présent : accepté', () {
      expect(
        RegleConges.joursEnSousEffectif(
          debut: debut,
          fin: fin,
          collegues: const [Collegue(disponible: true)],
        ),
        isEmpty,
      );
    });

    test('Seul dans le service : tous les jours refusés', () {
      expect(
        RegleConges.joursEnSousEffectif(debut: debut, fin: fin, collegues: const []),
        hasLength(5),
      );
    });

    test('Collègue en congé une partie de la période', () {
      final List<DateTime> jours = RegleConges.joursEnSousEffectif(
        debut: debut,
        fin: fin,
        collegues: [
          Collegue(
            disponible: true,
            conges: [(DateTime(2026, 11, 5), DateTime(2026, 11, 10))],
          ),
          const Collegue(disponible: false),
        ],
      );
      expect(jours, [DateTime.utc(2026, 11, 5), DateTime.utc(2026, 11, 6)]);
      expect(RegleConges.resumerJours(jours), '05/11, 06/11');
    });
  });

  test('Lecture / écriture en base', () {
    final Conge c = Conge(
      role: Role.infirmier,
      demandeurId: 4,
      debut: DateTime(2026, 11, 2),
      fin: DateTime(2026, 11, 6),
      type: TypeConge.formation,
      motif: 'Congrès',
    );
    final Conge lu = Conge.fromMap({...c.toMap(), 'id': 1});
    expect(lu.role, Role.infirmier);
    expect(lu.type, TypeConge.formation);
    expect(lu.statut, StatutConge.enAttente);
    expect(lu.nbJours, 5);
    expect(c.toMap()['date_debut'], '2026-11-02');
  });
}
