import 'package:flutter_test/flutter_test.dart';
import 'package:projet/features/ambulance_dispatch/domain/models/intervention.dart';
import 'package:projet/features/ambulance_dispatch/domain/surveillance_cardiaque.dart';

void main() {
  final DateTime t0 = DateTime(2026, 10, 3, 14);

  MesureCardiaque m(int bpm, int minute) =>
      MesureCardiaque(bpm: bpm, date: t0.add(Duration(minutes: minute)));

  test('seuils : normal, élevé, bas', () {
    const SeuilsCardiaques s = SeuilsCardiaques(min: 45, max: 120);
    expect(s.evaluer(80), EtatRythme.normal);
    expect(s.evaluer(121), EtatRythme.eleve);
    expect(s.evaluer(44), EtatRythme.bas);
  });

  test('une seule mesure anormale ne déclenche pas d\'alerte', () {
    final AnalyseurCardiaque a = AnalyseurCardiaque();
    expect(a.analyser(m(140, 0)), isNull);
    expect(a.analyser(m(80, 1)), isNull);
    expect(a.analyser(m(140, 2)), isNull);
  });

  test('deux mesures anormales de suite déclenchent l\'alerte', () {
    final AnalyseurCardiaque a = AnalyseurCardiaque();
    expect(a.analyser(m(130, 0)), isNull);
    final AlerteCardiaque? alerte = a.analyser(m(135, 1));
    expect(alerte, isNotNull);
    expect(alerte?.etat, EtatRythme.eleve);
    expect(alerte?.gravite, Gravite.urgente);
  });

  test('une mesure déjà analysée est ignorée', () {
    final AnalyseurCardiaque a = AnalyseurCardiaque();
    expect(a.analyser(m(160, 5)), isNull);
    expect(a.analyser(m(160, 5)), isNull);
    expect(a.analyser(m(160, 4)), isNull);
  });

  test('gravité critique au-delà de 150 bpm ou sous 40 bpm', () {
    expect(AnalyseurCardiaque.graviteDe(155), Gravite.critique);
    expect(AnalyseurCardiaque.graviteDe(38), Gravite.critique);
    expect(AnalyseurCardiaque.graviteDe(130), Gravite.urgente);
  });

  test('pause après « Je vais bien »', () {
    final AnalyseurCardiaque a = AnalyseurCardiaque();
    a.suspendre();
    expect(a.analyser(m(170, 0)), isNull);
    expect(a.analyser(m(170, 1)), isNull);
    expect(a.enPause, isTrue);
  });
}
