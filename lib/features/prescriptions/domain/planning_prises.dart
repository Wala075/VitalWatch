import 'models/prise.dart';

/// Métier 3 : planning des prises généré à la validation de l'ordonnance.
class PlanningPrises {
  PlanningPrises._();

  /// Moments de prise, dans l'ordre de la journée.
  static const List<String> moments = ['matin', 'midi', 'soir', 'coucher'];

  /// Heure de chaque moment (paramétrable).
  static const Map<String, int> heures = {
    'matin': 8,
    'midi': 13,
    'soir': 20,
    'coucher': 22,
  };

  static const Map<String, String> libelles = {
    'matin': 'Matin',
    'midi': 'Midi',
    'soir': 'Soir',
    'coucher': 'Coucher',
  };

  /// Une prise par jour et par moment, à partir de [debut].
  ///
  /// Les moments déjà passés à l'instant [debut] sont sautés, mais le nombre
  /// total de prises (durée × moments) est conservé : le traitement finit
  /// simplement un peu plus tard.
  static List<Prise> generer({
    required int ligneId,
    required List<String> momentsLigne,
    required int dureeJours,
    required DateTime debut,
  }) {
    final List<int> heuresDuJour = [];
    for (final String m in moments) {
      final int? h = heures[m];
      if (h != null && momentsLigne.contains(m)) {
        heuresDuJour.add(h);
      }
    }

    final List<Prise> res = [];
    if (heuresDuJour.isEmpty) {
      return res;
    }

    final int total = dureeJours * heuresDuJour.length;
    int jour = 0;
    while (res.length < total) {
      for (final int h in heuresDuJour) {
        final DateTime heure = DateTime(debut.year, debut.month, debut.day + jour, h);
        if (res.length < total && !heure.isBefore(debut)) {
          res.add(Prise(ligneId: ligneId, heurePrevue: heure));
        }
      }
      jour++;
    }
    return res;
  }
}
