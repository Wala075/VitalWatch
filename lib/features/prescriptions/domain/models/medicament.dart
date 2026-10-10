/// Catégorie de remboursement d'un médicament (taux fixé par chaque assurance).
enum CategorieMedicament {
  vital('vital', 'Vital'),
  essentiel('essentiel', 'Essentiel'),
  intermediaire('intermediaire', 'Intermédiaire'),
  nonRemboursable('non_remboursable', 'Non remboursable');

  const CategorieMedicament(this.valeur, this.libelle);

  /// Valeur stockée en base.
  final String valeur;
  final String libelle;

  static CategorieMedicament depuis(Object? valeur) {
    for (final CategorieMedicament c in CategorieMedicament.values) {
      if (c.valeur == valeur) {
        return c;
      }
    }
    return CategorieMedicament.nonRemboursable;
  }
}

/// Médicament du catalogue (table medicament).
class Medicament {
  final int? id;
  final String nomCommercial;
  final String dci;

  /// Identifiant RxNorm, mis en cache après le premier appel à l'API.
  final String? rxcui;

  /// Classe thérapeutique (ex. pénicilline).
  final String? classe;

  /// Comprimé, gélule, sirop…
  final String forme;

  /// Ex. 500 mg.
  final String dosage;
  final int unitesParBoite;

  /// Dose maximale par jour, en unités (comprimés, ml…).
  final double? doseMaxJour;
  final String? codeBarres;
  final double prixPublic;
  final double? prixReference;
  final CategorieMedicament categorie;
  final bool generique;

  /// false = archivé (déjà prescrit, ne peut plus être supprimé).
  final bool actif;

  /// Boîtes en stock à la pharmacie. Absent de [toMap] : il ne change que
  /// par une entrée de stock ou une délivrance (MedicamentRepository).
  final int stock;

  const Medicament({
    this.id,
    required this.nomCommercial,
    required this.dci,
    this.rxcui,
    this.classe,
    required this.forme,
    required this.dosage,
    required this.unitesParBoite,
    this.doseMaxJour,
    this.codeBarres,
    required this.prixPublic,
    this.prixReference,
    required this.categorie,
    this.generique = false,
    this.actif = true,
    this.stock = 0,
  });

  /// Doliprane 1000 mg
  String get libelle => '$nomCommercial $dosage';

  /// paracétamol · comprimé · 8 par boîte
  String get description => '$dci · $forme · $unitesParBoite par boîte';

  /// Prix servant de base au remboursement : min(prix public, prix de référence).
  double get prixBase {
    final double? reference = prixReference;
    if (reference == null || reference > prixPublic) {
      return prixPublic;
    }
    return reference;
  }

  Medicament copyWith({int? id, String? rxcui, bool? actif}) {
    return Medicament(
      id: id ?? this.id,
      nomCommercial: nomCommercial,
      dci: dci,
      rxcui: rxcui ?? this.rxcui,
      classe: classe,
      forme: forme,
      dosage: dosage,
      unitesParBoite: unitesParBoite,
      doseMaxJour: doseMaxJour,
      codeBarres: codeBarres,
      prixPublic: prixPublic,
      prixReference: prixReference,
      categorie: categorie,
      generique: generique,
      actif: actif ?? this.actif,
      stock: stock,
    );
  }

  factory Medicament.fromMap(Map<String, Object?> map) {
    return Medicament(
      id: map['id'] as int?,
      nomCommercial: map['nom_commercial'] as String,
      dci: map['dci'] as String,
      rxcui: map['rxcui'] as String?,
      classe: map['classe'] as String?,
      forme: map['forme'] as String,
      dosage: map['dosage'] as String,
      unitesParBoite: map['unites_par_boite'] as int,
      doseMaxJour: (map['dose_max_jour'] as num?)?.toDouble(),
      codeBarres: map['code_barres'] as String?,
      prixPublic: (map['prix_public'] as num).toDouble(),
      prixReference: (map['prix_reference'] as num?)?.toDouble(),
      categorie: CategorieMedicament.depuis(map['categorie']),
      generique: ((map['generique'] as int?) ?? 0) == 1,
      actif: ((map['actif'] as int?) ?? 1) == 1,
      stock: (map['stock'] as int?) ?? 0,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'nom_commercial': nomCommercial,
      'dci': dci,
      'rxcui': rxcui,
      'classe': classe,
      'forme': forme,
      'dosage': dosage,
      'unites_par_boite': unitesParBoite,
      'dose_max_jour': doseMaxJour,
      'code_barres': codeBarres,
      'prix_public': prixPublic,
      'prix_reference': prixReference,
      'categorie': categorie.valeur,
      'generique': generique ? 1 : 0,
      'actif': actif ? 1 : 0,
    };
  }
}
