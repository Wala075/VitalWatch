/// Métier 8 : calcul de la prise en charge, ligne par ligne puis total.
///
/// 1. Montant = prix public × boîtes.
/// 2. Base remboursable = min(prix public, prix de référence) × boîtes.
/// 3. Taux = 100 % si la ligne est APCI, sinon le taux CNAM de la catégorie.
/// 4. Part CNAM = base × taux, limitée au plafond restant.
/// 5. Mutuelle = (montant − part CNAM) × taux de la mutuelle.
/// 6. Reste à charge = montant − part CNAM − mutuelle, arrondi au millime.
///
/// Les taux et plafonds viennent des tables taux_couverture et assurance.
class CalculPriseEnCharge {
  CalculPriseEnCharge._();

  static double arrondi(double v) => (v * 1000).round() / 1000;

  static DetailLigne calculerLigne({
    required String libelle,
    required double prixPublic,
    double? prixReference,
    required int boites,
    required double tauxCnam,
    required bool apci,
    double? tauxMutuelle,
    double? plafondRestant,
  }) {
    final double montant = prixPublic * boites;
    final double reference = prixReference ?? prixPublic;
    final double base = (reference < prixPublic ? reference : prixPublic) * boites;
    final double taux = apci ? 1.0 : tauxCnam;
    double cnam = base * taux;
    if (plafondRestant != null && cnam > plafondRestant) {
      cnam = plafondRestant < 0 ? 0 : plafondRestant;
    }
    final double resteApresCnam = montant - cnam;
    final double mutuelle = tauxMutuelle == null ? 0 : resteApresCnam * tauxMutuelle;
    return DetailLigne(
      libelle: libelle,
      boites: boites,
      montant: arrondi(montant),
      base: arrondi(base),
      taux: taux,
      partCnam: arrondi(cnam),
      partMutuelle: arrondi(mutuelle),
      resteACharge: arrondi(resteApresCnam - mutuelle),
      apci: apci,
    );
  }
}

/// Résultat du calcul pour une ligne.
class DetailLigne {
  const DetailLigne({
    required this.libelle,
    required this.boites,
    required this.montant,
    required this.base,
    required this.taux,
    required this.partCnam,
    required this.partMutuelle,
    required this.resteACharge,
    required this.apci,
  });

  final String libelle;
  final int boites;
  final double montant;
  final double base;

  /// Taux CNAM appliqué (1.0 si APCI).
  final double taux;
  final double partCnam;
  final double partMutuelle;
  final double resteACharge;
  final bool apci;
}

/// Résultat du calcul pour toute l'ordonnance.
class DetailPriseEnCharge {
  const DetailPriseEnCharge({required this.lignes, this.remarques = const []});

  final List<DetailLigne> lignes;

  /// Informations pour le patient (plafond atteint, APCI non reconnue…).
  final List<String> remarques;

  double get montant => _somme((DetailLigne l) => l.montant);
  double get partCnam => _somme((DetailLigne l) => l.partCnam);
  double get partMutuelle => _somme((DetailLigne l) => l.partMutuelle);
  double get resteACharge => _somme((DetailLigne l) => l.resteACharge);

  double _somme(double Function(DetailLigne l) valeur) {
    double total = 0;
    for (final DetailLigne l in lignes) {
      total += valeur(l);
    }
    return CalculPriseEnCharge.arrondi(total);
  }
}
