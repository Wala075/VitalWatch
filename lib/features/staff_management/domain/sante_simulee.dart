import 'dart:math' as math;

import '../../../models/patient.dart';

enum NiveauAlerte { stable, surveiller, critique }

class Constantes {
  const Constantes({
    required this.frequence,
    required this.spo2,
    required this.systolique,
    required this.diastolique,
    required this.temperature,
    required this.glycemie,
  });

  final int frequence; // bpm
  final int spo2; // %
  final int systolique; // mmHg
  final int diastolique; // mmHg
  final double temperature; // °C
  final double glycemie; // g/L

  String get tension => '$systolique/$diastolique';

  String get temperatureTexte => temperature.toStringAsFixed(1).replaceAll('.', ',');

  String get glycemieTexte => glycemie.toStringAsFixed(2).replaceAll('.', ',');
}

class Evaluation {
  const Evaluation(this.niveau, this.motifs);

  final NiveauAlerte niveau;
  final List<String> motifs;
}

/// Constantes vitales SIMULÉES, en attendant le module 2 « Suivi vital ».
/// Chaque patient a un profil reproductible (calculé à partir de son id) :
/// la plupart sont stables, certains à surveiller, quelques-uns critiques.
class SanteSimulee {
  SanteSimulee._();

  static int _profil(Patient p) => (p.id ?? 0) % 6;

  static Constantes instant(Patient p, {int tick = 0}) {
    final int id = p.id ?? p.cin.hashCode;
    final math.Random r = math.Random(id * 7919 + tick);
    int bruit(int amplitude) => r.nextInt(2 * amplitude + 1) - amplitude;
    final bool enfant = p.age < 12;

    switch (_profil(p)) {
      case 2: // hypertension
        return Constantes(
          frequence: 96 + bruit(3),
          spo2: 95 + r.nextInt(2),
          systolique: 148 + bruit(3),
          diastolique: 94 + bruit(2),
          temperature: 37.1 + bruit(1) / 10,
          glycemie: 1.5 + bruit(5) / 100,
        );
      case 3: // infection
        return Constantes(
          frequence: (enfant ? 146 : 126) + bruit(3),
          spo2: 91 + r.nextInt(2),
          systolique: 104 + bruit(3),
          diastolique: 66 + bruit(2),
          temperature: 39.6 + bruit(1) / 10,
          glycemie: 1.2 + bruit(5) / 100,
        );
      default: // stable
        final int decalage = math.Random(id).nextInt(7) - 3;
        return Constantes(
          frequence: (enfant ? 94 : 74) + decalage + bruit(4),
          spo2: 97 + r.nextInt(3),
          systolique: 120 + bruit(5),
          diastolique: 78 + bruit(4),
          temperature: 36.8 + bruit(2) / 10,
          glycemie: 0.95 + bruit(8) / 100,
        );
    }
  }

  /// Fréquence cardiaque moyenne des 7 derniers jours (aujourd'hui en dernier).
  static List<int> frequenceSemaine(Patient p) {
    return [for (int i = 0; i < 7; i++) instant(p, tick: 1000 + i).frequence];
  }

  static Evaluation evaluerPatient(Patient p) => evaluer(instant(p), p.age);

  // ------------------------------------------------------------------
  // Seuils d'alerte (adulte / enfant de moins de 12 ans)
  // ------------------------------------------------------------------

  static NiveauAlerte niveauFrequence(int fc, int age) {
    final bool enfant = age < 12;
    if (fc > (enfant ? 140 : 120) || fc < 45) return NiveauAlerte.critique;
    if (fc > (enfant ? 120 : 100) || fc < 55) return NiveauAlerte.surveiller;
    return NiveauAlerte.stable;
  }

  static NiveauAlerte niveauSpo2(int spo2) {
    if (spo2 < 92) return NiveauAlerte.critique;
    if (spo2 < 95) return NiveauAlerte.surveiller;
    return NiveauAlerte.stable;
  }

  static NiveauAlerte niveauTension(int systolique, int diastolique) {
    if (systolique >= 160 || diastolique >= 100) return NiveauAlerte.critique;
    if (systolique >= 140 || diastolique >= 90 || systolique < 90) {
      return NiveauAlerte.surveiller;
    }
    return NiveauAlerte.stable;
  }

  static NiveauAlerte niveauTemperature(double t) {
    if (t >= 39.5) return NiveauAlerte.critique;
    if (t >= 38 || t < 35.5) return NiveauAlerte.surveiller;
    return NiveauAlerte.stable;
  }

  static NiveauAlerte niveauGlycemie(double g) {
    if (g > 2.5) return NiveauAlerte.critique;
    if (g > 1.8 || g < 0.7) return NiveauAlerte.surveiller;
    return NiveauAlerte.stable;
  }

  static Evaluation evaluer(Constantes c, int age) {
    final List<(NiveauAlerte, String)> alertes = [];
    void signaler(NiveauAlerte n, String critique, String surveiller) {
      if (n == NiveauAlerte.stable) return;
      alertes.add((n, n == NiveauAlerte.critique ? critique : surveiller));
    }

    signaler(
      niveauFrequence(c.frequence, age),
      'Fréquence cardiaque anormale (${c.frequence} bpm)',
      'Fréquence cardiaque à surveiller (${c.frequence} bpm)',
    );
    signaler(
      niveauSpo2(c.spo2),
      'Saturation basse (SpO₂ ${c.spo2} %)',
      'Saturation à surveiller (SpO₂ ${c.spo2} %)',
    );
    final NiveauAlerte tension = niveauTension(c.systolique, c.diastolique);
    signaler(
      tension,
      'Tension très élevée (${c.tension} mmHg)',
      c.systolique < 90
          ? 'Tension basse (${c.tension} mmHg)'
          : 'Tension élevée (${c.tension} mmHg)',
    );
    signaler(
      niveauTemperature(c.temperature),
      'Forte fièvre (${c.temperatureTexte} °C)',
      c.temperature < 35.5
          ? 'Hypothermie (${c.temperatureTexte} °C)'
          : 'Fièvre (${c.temperatureTexte} °C)',
    );
    signaler(
      niveauGlycemie(c.glycemie),
      'Glycémie très élevée (${c.glycemieTexte} g/L)',
      'Glycémie à surveiller (${c.glycemieTexte} g/L)',
    );

    // Les alertes critiques d'abord.
    alertes.sort((a, b) => b.$1.index.compareTo(a.$1.index));
    return Evaluation(
      alertes.isEmpty ? NiveauAlerte.stable : alertes.first.$1,
      [for (final a in alertes) a.$2],
    );
  }
}
