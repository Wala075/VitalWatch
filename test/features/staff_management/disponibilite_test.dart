// flutter_test exporte aussi une classe Evaluation (accessibilité).
import 'package:flutter_test/flutter_test.dart' hide Evaluation;

import 'package:projet/features/staff_management/domain/disponibilite.dart';
import 'package:projet/features/staff_management/domain/sante_simulee.dart';
import 'package:projet/models/medecin.dart';
import 'package:projet/models/patient.dart';

Medecin _medecin({bool disponible = true}) => Medecin(
      id: 1,
      nom: 'Ben Ali',
      prenom: 'Sami',
      matricule: 'MAT-1',
      specialite: 'Cardiologie',
      telephone: '+21622123456',
      email: 'sami@test.tn',
      disponible: disponible,
    );

Patient _patient(int id, {int age = 40}) => Patient(
      id: id,
      nom: 'Test',
      prenom: 'Patient$id',
      cin: '1234567$id',
      dateNaissance: DateTime(DateTime.now().year - age, 1, 1),
      sexe: 'M',
      telephone: '+21622123456',
    );

Constantes _constantes({
  int frequence = 75,
  int spo2 = 98,
  int systolique = 120,
  int diastolique = 78,
  double temperature = 36.8,
  double glycemie = 0.95,
}) =>
    Constantes(
      frequence: frequence,
      spo2: spo2,
      systolique: systolique,
      diastolique: diastolique,
      temperature: temperature,
      glycemie: glycemie,
    );

void main() {
  // Lundi 8 h – 14 h, mercredi 13 h – 19 h.
  const List<Creneau> horaires = [
    Creneau(medecinId: 1, jour: 1, debut: 8 * 60, fin: 14 * 60),
    Creneau(medecinId: 1, jour: 3, debut: 13 * 60, fin: 19 * 60),
  ];
  // 5 octobre 2026 = lundi.
  DateTime lundi(int h, [int m = 0]) => DateTime(2026, 10, 5, h, m);

  group('Disponibilité des médecins', () {
    test('En service pendant un créneau', () {
      final Disponibilite d =
          Disponibilite.calculer(_medecin(), horaires, lundi(10));
      expect(d.etat, EtatMedecin.enService);
      expect(d.jusqua, lundi(14));
      expect(d.libelle(lundi(10)), "En service jusqu'à 14:00");
    });

    test('Avant le créneau du jour : reprend aujourd\'hui', () {
      final Disponibilite d =
          Disponibilite.calculer(_medecin(), horaires, lundi(7, 30));
      expect(d.etat, EtatMedecin.horsHoraires);
      expect(d.libelle(lundi(7, 30)), 'Reprend à 08:00');
    });

    test("L'heure de fin est exclue", () {
      final Disponibilite d =
          Disponibilite.calculer(_medecin(), horaires, lundi(14));
      expect(d.etat, EtatMedecin.horsHoraires);
      expect(d.libelle(lundi(14)), 'Reprend mercredi à 13:00');
    });

    test('Prochain créneau le lendemain', () {
      final DateTime mardi = DateTime(2026, 10, 6, 9);
      final Disponibilite d = Disponibilite.calculer(_medecin(), horaires, mardi);
      expect(d.libelle(mardi), 'Reprend demain à 13:00');
    });

    test('Passage dimanche → lundi', () {
      final DateTime dimanche = DateTime(2026, 10, 11, 20);
      final Disponibilite d =
          Disponibilite.calculer(_medecin(), horaires, dimanche);
      expect(d.reprise, DateTime(2026, 10, 12, 8));
      expect(d.libelle(dimanche), 'Reprend demain à 08:00');
    });

    test('Un médecin en congé est absent, même pendant ses horaires', () {
      final Disponibilite d = Disponibilite.calculer(
        _medecin(disponible: false),
        horaires,
        lundi(10),
      );
      expect(d.etat, EtatMedecin.absent);
      expect(d.libelle(lundi(10)), 'En congé');
    });

    test('Sans horaires', () {
      final Disponibilite d = Disponibilite.calculer(_medecin(), const [], lundi(10));
      expect(d.etat, EtatMedecin.horsHoraires);
      expect(d.libelle(lundi(10)), 'Aucun horaire défini');
    });

    test('Résumé de la semaine', () {
      expect(Horaire.format(510), '08:30');
      expect(Horaire.heuresParSemaine(horaires), 12);
      expect(Horaire.joursTravailles(horaires), 2);
    });
  });

  group('Alertes de santé', () {
    test('Constantes normales : stable', () {
      final Evaluation e = SanteSimulee.evaluer(_constantes(), 40);
      expect(e.niveau, NiveauAlerte.stable);
      expect(e.motifs, isEmpty);
    });

    test('Seuils de fréquence cardiaque adulte / enfant', () {
      expect(SanteSimulee.niveauFrequence(130, 40), NiveauAlerte.critique);
      expect(SanteSimulee.niveauFrequence(130, 8), NiveauAlerte.surveiller);
      expect(SanteSimulee.niveauFrequence(105, 40), NiveauAlerte.surveiller);
      expect(SanteSimulee.niveauFrequence(105, 8), NiveauAlerte.stable);
    });

    test('Les alertes critiques passent en premier', () {
      final Evaluation e = SanteSimulee.evaluer(
        _constantes(systolique: 150, temperature: 39.8),
        40,
      );
      expect(e.niveau, NiveauAlerte.critique);
      expect(e.motifs, hasLength(2));
      expect(e.motifs.first, contains('fièvre'));
    });

    test('Mesures simulées reproductibles', () {
      final Patient p = _patient(1);
      expect(SanteSimulee.instant(p, tick: 4).frequence,
          SanteSimulee.instant(p, tick: 4).frequence);
    });

    test('Profils simulés : stable, à surveiller, critique', () {
      expect(SanteSimulee.evaluerPatient(_patient(1)).niveau, NiveauAlerte.stable);
      expect(SanteSimulee.evaluerPatient(_patient(2)).niveau, NiveauAlerte.surveiller);
      expect(SanteSimulee.evaluerPatient(_patient(3)).niveau, NiveauAlerte.critique);
      expect(
        SanteSimulee.evaluerPatient(_patient(3, age: 7)).niveau,
        NiveauAlerte.critique,
      );
    });
  });
}
