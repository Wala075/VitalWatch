import 'package:flutter_test/flutter_test.dart';

import 'package:projet/features/appointments/domain/rdv_models.dart';
import 'package:projet/features/appointments/domain/rdv_regles.dart';
import 'package:projet/features/appointments/services/calendrier_service.dart';
import 'package:projet/features/appointments/services/resume_ia_service.dart';

void main() {
  // Lundi 5 octobre 2026, 8h00
  final DateTime lundi8h = DateTime(2026, 10, 5, 8);

  RendezVous rdv(
    DateTime d, {
    int duree = 30,
    StatutRdv statut = StatutRdv.confirme,
    PrioriteRdv priorite = PrioriteRdv.normale,
  }) {
    return RendezVous(
      id: d.millisecondsSinceEpoch,
      patientId: 1,
      medecinId: 1,
      dateHeure: d,
      duree: duree,
      type: TypeRdv.presentiel,
      motif: 'Contrôle',
      statut: statut,
      priorite: priorite,
    );
  }

  const Creneau matinLundi = Creneau(
    medecinId: 1,
    jour: 1,
    heureDebut: 9 * 60,
    heureFin: 11 * 60,
  );

  group('Créneaux et conflits', () {
    test('horaires libres : découpage en 30 min, RDV pris retiré', () {
      final List<DateTime> libres = RdvRegles.horairesLibres(
        jour: lundi8h,
        creneaux: [matinLundi],
        occupes: [rdv(DateTime(2026, 10, 5, 9, 30))],
        maintenant: lundi8h,
      );
      expect(libres, [
        DateTime(2026, 10, 5, 9),
        DateTime(2026, 10, 5, 10),
        DateTime(2026, 10, 5, 10, 30),
      ]);
    });

    test('un RDV annulé libère le créneau', () {
      final List<DateTime> libres = RdvRegles.horairesLibres(
        jour: lundi8h,
        creneaux: [matinLundi],
        occupes: [rdv(DateTime(2026, 10, 5, 9, 30), statut: StatutRdv.annule)],
        maintenant: lundi8h,
      );
      expect(libres.length, 4);
    });

    test('les horaires déjà passés ne sont pas proposés', () {
      final List<DateTime> libres = RdvRegles.horairesLibres(
        jour: lundi8h,
        creneaux: [matinLundi],
        occupes: const [],
        maintenant: DateTime(2026, 10, 5, 10, 10),
      );
      expect(libres, [DateTime(2026, 10, 5, 10, 30)]);
    });

    test('créneau récurrent : seulement le bon jour', () {
      final List<DateTime> mardi = RdvRegles.horairesLibres(
        jour: DateTime(2026, 10, 6),
        creneaux: [matinLundi],
        occupes: const [],
        maintenant: lundi8h,
      );
      expect(mardi, isEmpty);
    });

    test('chevauchement détecté (y compris partiel)', () {
      final List<RendezVous> occupes = [rdv(DateTime(2026, 10, 5, 9), duree: 45)];
      expect(RdvRegles.conflit(DateTime(2026, 10, 5, 9, 30), 30, occupes), isNotNull);
      expect(RdvRegles.conflit(DateTime(2026, 10, 5, 9, 45), 30, occupes), isNull);
    });

    test('RDV hors créneau refusé', () {
      expect(
        RdvRegles.creneauContenant(DateTime(2026, 10, 5, 10, 30), 30, [matinLundi]),
        isNotNull,
      );
      expect(
        RdvRegles.creneauContenant(DateTime(2026, 10, 5, 10, 45), 30, [matinLundi]),
        isNull,
      );
      expect(
        RdvRegles.creneauContenant(DateTime(2026, 10, 5, 14), 30, [matinLundi]),
        isNull,
      );
    });

    test('validation et chevauchement des créneaux', () {
      expect(RdvRegles.validerCreneau(matinLundi), isNull);
      expect(
        RdvRegles.validerCreneau(
          const Creneau(medecinId: 1, jour: 1, heureDebut: 600, heureFin: 540),
        ),
        isNotNull,
      );
      const Creneau chevauche =
          Creneau(medecinId: 1, jour: 1, heureDebut: 10 * 60, heureFin: 12 * 60);
      const Creneau autreJour =
          Creneau(medecinId: 1, jour: 2, heureDebut: 10 * 60, heureFin: 12 * 60);
      expect(RdvRegles.creneauxSeChevauchent(matinLundi, chevauche), isTrue);
      expect(RdvRegles.creneauxSeChevauchent(matinLundi, autreJour), isFalse);
    });
  });

  group('Priorité et file d\'attente', () {
    RdvDetail detail(RendezVous r, {bool alerte = false}) => RdvDetail(
          rdv: r,
          patientNom: 'P',
          medecinNom: 'M',
          alerteRecente: alerte,
        );

    test('priorité initiale', () {
      expect(
        RdvRegles.prioriteInitiale(urgent: true, alerteRecente: false),
        PrioriteRdv.urgente,
      );
      expect(
        RdvRegles.prioriteInitiale(urgent: false, alerteRecente: true),
        PrioriteRdv.haute,
      );
      expect(
        RdvRegles.prioriteInitiale(urgent: false, alerteRecente: false),
        PrioriteRdv.normale,
      );
    });

    test('urgent > alerte récente > normal, puis par heure', () {
      final RdvDetail normal9h = detail(rdv(DateTime(2026, 10, 5, 9)));
      final RdvDetail alerte11h = detail(rdv(DateTime(2026, 10, 5, 11)), alerte: true);
      final RdvDetail urgent12h =
          detail(rdv(DateTime(2026, 10, 5, 12), priorite: PrioriteRdv.urgente));
      final RdvDetail normal8h = detail(rdv(DateTime(2026, 10, 5, 8)));

      final List<RdvDetail> file =
          RdvRegles.trierFile([normal9h, alerte11h, urgent12h, normal8h]);
      expect(file, [urgent12h, alerte11h, normal8h, normal9h]);
    });

    test('la consultation en cours reste en tête', () {
      final RdvDetail enCours =
          detail(rdv(DateTime(2026, 10, 5, 9), statut: StatutRdv.enCours));
      final RdvDetail urgent =
          detail(rdv(DateTime(2026, 10, 5, 10), priorite: PrioriteRdv.urgente));
      expect(RdvRegles.trierFile([urgent, enCours]).first, enCours);
    });
  });

  group('Annulation, absence, rappels', () {
    final DateTime rdv10h = DateTime(2026, 10, 5, 10);

    test('le patient ne peut plus annuler moins de 2 h avant', () {
      expect(RdvRegles.patientPeutAnnuler(rdv(rdv10h), lundi8h), isTrue);
      expect(
        RdvRegles.patientPeutAnnuler(rdv(rdv10h), DateTime(2026, 10, 5, 8, 30)),
        isFalse,
      );
    });

    test('absent seulement 15 min après l\'heure', () {
      expect(RdvRegles.peutMarquerAbsent(rdv(rdv10h), DateTime(2026, 10, 5, 10, 10)), isFalse);
      expect(RdvRegles.peutMarquerAbsent(rdv(rdv10h), DateTime(2026, 10, 5, 10, 20)), isTrue);
    });

    test('rappels J-1 et H-1', () {
      expect(RdvRegles.rappelPour(rdv(rdv10h), DateTime(2026, 10, 3, 10)), isNull);
      expect(RdvRegles.rappelPour(rdv(rdv10h), DateTime(2026, 10, 4, 18)), startsWith('J-1'));
      expect(RdvRegles.rappelPour(rdv(rdv10h), DateTime(2026, 10, 5, 9, 20)), startsWith('H-1'));
      expect(
        RdvRegles.rappelPour(
          rdv(rdv10h, statut: StatutRdv.annule),
          DateTime(2026, 10, 5, 9, 20),
        ),
        isNull,
      );
    });

    test('urgence : arrondi aux 5 minutes suivantes', () {
      expect(
        RdvRegles.prochainesCinqMinutes(DateTime(2026, 10, 5, 9, 12, 40)),
        DateTime(2026, 10, 5, 9, 15),
      );
    });
  });

  group('Services', () {
    test('format Google Calendar en UTC', () {
      final String f = CalendrierService.formatGoogle(DateTime.utc(2026, 10, 7, 9, 30));
      expect(f, '20261007T093000Z');
    });

    test('résumé local sans IA', () {
      final String r = ResumeIaService.resumeLocal(
        motif: 'Tension',
        diagnostic: 'HTA grade 1',
        compteRendu: 'TA 150/95. Régime pauvre en sel. Contrôle dans 1 mois.',
      );
      expect(r, contains('Motif : Tension'));
      expect(r, contains('HTA grade 1'));
      expect(r, contains('TA 150/95.'));
      expect(r, isNot(contains('Contrôle dans 1 mois')));
    });
  });
}
