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

  test('nouveau seuil : les 2 dernières mesures récentes déclenchent l\'alerte', () {
    final AnalyseurCardiaque a = AnalyseurCardiaque();
    final List<MesureCardiaque> mesures = [m(70, 0), m(72, 5), m(74, 10)];
    for (final MesureCardiaque x in mesures) {
      expect(a.analyser(x), isNull); // normal avec 45–120
    }
    a.seuils = const SeuilsCardiaques(min: 45, max: 65);
    final AlerteCardiaque? alerte = a.reevaluer(mesures, maintenant: t0.add(const Duration(minutes: 11)));
    expect(alerte, isNotNull);
    expect(alerte?.mesure.bpm, 74);
    expect(alerte?.etat, EtatRythme.eleve);
  });

  test('nouveau seuil : mesures trop anciennes ignorées', () {
    final AnalyseurCardiaque a = AnalyseurCardiaque(seuils: const SeuilsCardiaques(max: 65));
    final List<MesureCardiaque> mesures = [m(72, 0), m(74, 5)];
    expect(a.reevaluer(mesures, maintenant: t0.add(const Duration(minutes: 40))), isNull);
  });

  test('nouveau seuil : 1 mesure récente anormale + 1 nouvelle → alerte', () {
    final AnalyseurCardiaque a = AnalyseurCardiaque(seuils: const SeuilsCardiaques(max: 65));
    expect(a.reevaluer([m(60, 0), m(72, 5)], maintenant: t0.add(const Duration(minutes: 6))), isNull);
    expect(a.anomaliesEnCours, 1);
    expect(a.analyser(m(73, 10)), isNotNull);
  });

  test('reprendre lève la pause', () {
    final AnalyseurCardiaque a = AnalyseurCardiaque(seuils: const SeuilsCardiaques(max: 65));
    a.suspendre();
    expect(a.finPause, isNotNull);
    a.reprendre();
    expect(a.enPause, isFalse);
    expect(a.reevaluer([m(72, 0), m(74, 5)], maintenant: t0.add(const Duration(minutes: 6))), isNotNull);
  });
}
