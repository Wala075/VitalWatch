enum TypeAssurance {
  cnam('cnam', 'CNAM'),
  mutuelle('mutuelle', 'Mutuelle'),
  privee('privee', 'Assurance privée');

  const TypeAssurance(this.valeur, this.libelle);

  /// Valeur stockée en base.
  final String valeur;
  final String libelle;

  static TypeAssurance depuis(Object? valeur) {
    for (final TypeAssurance t in TypeAssurance.values) {
      if (t.valeur == valeur) {
        return t;
      }
    }
    return TypeAssurance.privee;
  }
}

/// Organisme : CNAM, mutuelle ou assurance privée (table assurance).
class Assurance {
  final int? id;
  final String nom;
  final TypeAssurance type;

  /// null = pas de plafond.
  final double? plafondAnnuel;
  final int delaiReponseJours;

  const Assurance({
    this.id,
    required this.nom,
    required this.type,
    this.plafondAnnuel,
    this.delaiReponseJours = 30,
  });

  /// La CNAM paie la part obligatoire, les autres la part complémentaire.
  bool get estObligatoire => type == TypeAssurance.cnam;

  factory Assurance.fromMap(Map<String, Object?> map) {
    return Assurance(
      id: map['id'] as int?,
      nom: map['nom'] as String,
      type: TypeAssurance.depuis(map['type']),
      plafondAnnuel: (map['plafond_annuel'] as num?)?.toDouble(),
      delaiReponseJours: (map['delai_reponse_jours'] as int?) ?? 30,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'nom': nom,
      'type': type.valeur,
      'plafond_annuel': plafondAnnuel,
      'delai_reponse_jours': delaiReponseJours,
    };
  }
}
