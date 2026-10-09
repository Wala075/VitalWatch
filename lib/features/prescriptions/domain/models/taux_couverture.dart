import 'medicament.dart';

/// Taux de prise en charge d'une assurance pour une catégorie de médicament
/// (table taux_couverture). Une mutuelle utilise souvent la catégorie « tous ».
class TauxCouverture {
  static const String tous = 'tous';

  final int? id;
  final int assuranceId;

  /// Valeur d'une CategorieMedicament, ou [tous].
  final String categorie;

  /// Entre 0 et 1 (0.85 = 85 %).
  final double taux;

  const TauxCouverture({
    this.id,
    required this.assuranceId,
    required this.categorie,
    required this.taux,
  });

  String get libelleCategorie {
    if (categorie == tous) {
      return 'Tous les médicaments';
    }
    return CategorieMedicament.depuis(categorie).libelle;
  }

  factory TauxCouverture.fromMap(Map<String, Object?> map) {
    return TauxCouverture(
      id: map['id'] as int?,
      assuranceId: map['assurance_id'] as int,
      categorie: map['categorie'] as String,
      taux: (map['taux'] as num).toDouble(),
    );
  }

  Map<String, Object?> toMap() {
    return {
      'assurance_id': assuranceId,
      'categorie': categorie,
      'taux': taux,
    };
  }
}
