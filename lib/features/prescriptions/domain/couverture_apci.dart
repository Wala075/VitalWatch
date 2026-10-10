/// Prise en charge APCI d'une ligne, contrôlée par le pharmacien.
enum StatutApci {
  /// Ligne non liée à l'APCI par le médecin : taux normal.
  nonDemandee('Taux normal'),

  /// Médicament de la liste de l'APCI du patient : 100 %.
  couverte('APCI · 100 %'),

  /// APCI demandée mais médicament hors de la liste : taux normal.
  horsListe('Hors liste APCI · taux normal'),

  /// APCI demandée mais pas de contrat APCI actif : taux normal.
  sansApci('Patient sans APCI · taux normal');

  const StatutApci(this.libelle);

  final String libelle;

  bool get aCent => this == StatutApci.couverte;
}

/// Le médecin lie la ligne à l'APCI ; le pharmacien tient la liste des
/// médicaments (par DCI) couverts par chaque APCI. Le 100 % ne s'applique
/// que si les deux concordent.
class CouvertureApci {
  CouvertureApci._();

  static StatutApci statut({
    required bool lienApci,
    required String? codeApci,
    required Set<String> dcisCouvertes,
    required String dci,
  }) {
    if (!lienApci) {
      return StatutApci.nonDemandee;
    }
    if (codeApci == null) {
      return StatutApci.sansApci;
    }
    if (!dcisCouvertes.contains(normaliser(dci))) {
      return StatutApci.horsListe;
    }
    return StatutApci.couverte;
  }

  /// DCI comparées sans casse ni espaces autour.
  static String normaliser(String dci) => dci.trim().toLowerCase();
}
