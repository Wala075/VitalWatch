import 'package:flutter_test/flutter_test.dart';
import 'package:projet/features/ambulance_dispatch/domain/suivi_cardiaque.dart';
import 'package:projet/features/ambulance_dispatch/domain/surveillance_cardiaque.dart';

void main() {
  final DateTime maintenant = DateTime(2026, 10, 6, 15);

  SuiviPatient p(String nom, {int? bpm, int minutes = 0, int max = 120}) => SuiviPatient(
        patientId: nom.hashCode,
        nom: nom,
        seuils: SeuilsCardiaques(min: 45, max: max),
        derniere: bpm == null
            ? null
            : MesureCardiaque(bpm: bpm, date: maintenant.subtract(Duration(minutes: minutes))),
      );

  test('état, montre active et alerte', () {
    expect(p('A', bpm: 130, minutes: 5).enAlerte(maintenant), isTrue);
    expect(p('B', bpm: 130, minutes: 90).enAlerte(maintenant), isFalse); // mesure ancienne
    expect(p('C', bpm: 72, minutes: 5).enAlerte(maintenant), isFalse);
    expect(p('D', bpm: 72, minutes: 5, max: 65).etat, EtatRythme.eleve); // seuil du médecin
    expect(p('E').etat, isNull);
    expect(p('E').estActif(maintenant), isFalse);
  });

  test('tri : alertes, montres actives, anciennes mesures, sans mesure', () {
    final List<SuiviPatient> tries = SuiviPatient.trier([
      p('Zied'),
      p('Amal', bpm: 80, minutes: 200),
      p('Sami', bpm: 75, minutes: 10),
      p('Rim', bpm: 140, minutes: 3),
      p('Ali', bpm: 70, minutes: 2),
      p('Bilel'),
    ], maintenant: maintenant);
    final List<String> noms = [for (final SuiviPatient s in tries) s.nom];
    expect(noms, ['Rim', 'Ali', 'Sami', 'Amal', 'Bilel', 'Zied']);
  });

  test('statistiques : moyenne, min, max, hors seuils', () {
    final List<MesureCardiaque> mesures = [
      for (final int b in [60, 70, 80, 130])
        MesureCardiaque(bpm: b, date: maintenant),
    ];
    final StatsRythme s = StatsRythme.de(mesures, const SeuilsCardiaques(min: 45, max: 120));
    expect(s.nombre, 4);
    expect(s.moyenne, 85);
    expect(s.min, 60);
    expect(s.max, 130);
    expect(s.horsSeuils, 1);
    expect(StatsRythme.de([], const SeuilsCardiaques()).nombre, 0);
  });
}
