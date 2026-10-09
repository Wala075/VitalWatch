/// Métier 2 : nombre de boîtes à délivrer à partir de la posologie.
///
/// boîtes = ⌈ dose par prise × prises par jour × durée ÷ unités par boîte ⌉
/// Ex. 1 comprimé × 3 par jour × 10 jours ÷ 20 comprimés = 1,5 → 2 boîtes.
class CalculBoites {
  CalculBoites._();

  /// Marge contre les erreurs d'arrondi des doubles (0,1 × 3 = 0,30000000000000004).
  static const double _marge = 1e-9;

  static int calculer({
    required double dosePrise,
    required int prisesParJour,
    required int dureeJours,
    required int unitesParBoite,
  }) {
    final double total = dosePrise * prisesParJour * dureeJours;
    final int boites = (total / unitesParBoite - _marge).ceil();
    return boites < 1 ? 1 : boites;
  }
}
