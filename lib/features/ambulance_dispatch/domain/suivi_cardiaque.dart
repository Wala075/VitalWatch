import 'surveillance_cardiaque.dart';

/// Résumé du rythme cardiaque d'un patient pour le personnel (médecin,
/// régulation, ambulancier). Les mesures sont envoyées par le téléphone du
/// patient qui porte la montre et lues ici dans la base.
class SuiviPatient {
  const SuiviPatient({
    required this.patientId,
    required this.nom,
    this.medecinId,
    this.derniere,
    this.seuils = const SeuilsCardiaques(),
    this.mesuresAujourdhui = 0,
    this.interventionId,
  });

  final int patientId;
  final String nom;
  final int? medecinId;
  final MesureCardiaque? derniere;
  final SeuilsCardiaques seuils;
  final int mesuresAujourdhui;

  /// Intervention d'ambulance en cours pour ce patient.
  final int? interventionId;

  /// Au-delà, la montre du patient est considérée comme inactive.
  static const Duration delaiActif = Duration(minutes: 30);

  EtatRythme? get etat {
    final MesureCardiaque? m = derniere;
    return m == null ? null : seuils.evaluer(m.bpm);
  }

  /// Dernière mesure récente : la montre envoie encore des données.
  bool estActif([DateTime? maintenant]) {
    final MesureCardiaque? m = derniere;
    return m != null && (maintenant ?? DateTime.now()).difference(m.date) <= delaiActif;
  }

  /// Mesure récente hors des seuils du patient : à surveiller en priorité.
  bool enAlerte([DateTime? maintenant]) {
    final EtatRythme? e = etat;
    return estActif(maintenant) && e != null && e != EtatRythme.normal;
  }

  /// Ordre d'affichage : en alerte, montres actives, anciennes mesures,
  /// puis patients sans mesure ; à rang égal, la mesure la plus récente
  /// d'abord, sinon par nom.
  static List<SuiviPatient> trier(List<SuiviPatient> liste, {DateTime? maintenant}) {
    final DateTime now = maintenant ?? DateTime.now();
    int rang(SuiviPatient s) {
      if (s.enAlerte(now)) {
        return 0;
      }
      if (s.estActif(now)) {
        return 1;
      }
      return s.derniere != null ? 2 : 3;
    }

    final List<SuiviPatient> res = [...liste];
    res.sort((SuiviPatient a, SuiviPatient b) {
      final int r = rang(a).compareTo(rang(b));
      if (r != 0) {
        return r;
      }
      final DateTime? da = a.derniere?.date;
      final DateTime? db = b.derniere?.date;
      if (da != null && db != null && da != db) {
        return db.compareTo(da);
      }
      return a.nom.toLowerCase().compareTo(b.nom.toLowerCase());
    });
    return res;
  }
}

/// Statistiques d'une série de mesures.
class StatsRythme {
  const StatsRythme({
    required this.nombre,
    required this.moyenne,
    required this.min,
    required this.max,
    required this.horsSeuils,
  });

  factory StatsRythme.de(List<MesureCardiaque> mesures, SeuilsCardiaques seuils) {
    if (mesures.isEmpty) {
      return const StatsRythme(nombre: 0, moyenne: 0, min: 0, max: 0, horsSeuils: 0);
    }
    int min = mesures.first.bpm;
    int max = mesures.first.bpm;
    int somme = 0;
    int hors = 0;
    for (final MesureCardiaque m in mesures) {
      if (m.bpm < min) {
        min = m.bpm;
      }
      if (m.bpm > max) {
        max = m.bpm;
      }
      somme += m.bpm;
      if (seuils.evaluer(m.bpm) != EtatRythme.normal) {
        hors++;
      }
    }
    return StatsRythme(
      nombre: mesures.length,
      moyenne: (somme / mesures.length).round(),
      min: min,
      max: max,
      horsSeuils: hors,
    );
  }

  final int nombre;
  final int moyenne;
  final int min;
  final int max;
  final int horsSeuils;
}
