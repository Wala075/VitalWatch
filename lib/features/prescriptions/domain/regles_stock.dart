/// Niveau de stock d'un médicament à la pharmacie.
enum NiveauStock {
  rupture('Rupture'),
  faible('Stock faible'),
  normal('En stock');

  const NiveauStock(this.libelle);

  final String libelle;
}

/// Règles du stock de la pharmacie (sans base de données, testables).
class ReglesStock {
  ReglesStock._();

  /// À ce nombre de boîtes ou moins : alerte « stock faible ».
  static const int seuilFaible = 5;

  /// Plus grande entrée de stock acceptée en une fois.
  static const int entreeMax = 1000;

  static NiveauStock niveau(int stock) {
    if (stock <= 0) {
      return NiveauStock.rupture;
    }
    if (stock <= seuilFaible) {
      return NiveauStock.faible;
    }
    return NiveauStock.normal;
  }

  /// Boîtes délivrables maintenant : le reste à délivrer, limité au stock.
  static int delivrable(int resteADelivrer, int stock) {
    if (resteADelivrer <= 0 || stock <= 0) {
      return 0;
    }
    return resteADelivrer < stock ? resteADelivrer : stock;
  }

  static String? verifierEntree(int? boites) {
    if (boites == null || boites < 1) {
      return 'Au moins 1 boîte';
    }
    if (boites > entreeMax) {
      return 'Au plus $entreeMax boîtes par entrée';
    }
    return null;
  }

  /// « 3 boîtes »
  static String boites(int n) => '$n boîte${n > 1 ? 's' : ''}';
}
