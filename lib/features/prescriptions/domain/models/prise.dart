import '../dates_sql.dart';

enum StatutPrise {
  prevue('prevue', 'Prévue'),
  prise('prise', 'Prise'),
  oubliee('oubliee', 'Oubliée');

  const StatutPrise(this.valeur, this.libelle);

  /// Valeur stockée en base.
  final String valeur;
  final String libelle;

  static StatutPrise depuis(Object? valeur) {
    for (final StatutPrise s in StatutPrise.values) {
      if (s.valeur == valeur) {
        return s;
      }
    }
    return StatutPrise.prevue;
  }
}

/// Une prise prévue et son suivi (table prise).
class Prise {
  final int? id;
  final int ligneId;
  final DateTime heurePrevue;
  final DateTime? heureReelle;
  final StatutPrise statut;

  const Prise({
    this.id,
    required this.ligneId,
    required this.heurePrevue,
    this.heureReelle,
    this.statut = StatutPrise.prevue,
  });

  factory Prise.fromMap(Map<String, Object?> map) {
    return Prise(
      id: map['id'] as int?,
      ligneId: map['ligne_id'] as int,
      heurePrevue: DatesSql.lire(map['heure_prevue']),
      heureReelle: DatesSql.lireOuNull(map['heure_reelle']),
      statut: StatutPrise.depuis(map['statut']),
    );
  }

  Map<String, Object?> toMap() {
    final DateTime? reelle = heureReelle;
    return {
      'ligne_id': ligneId,
      'heure_prevue': DatesSql.dateHeure(heurePrevue),
      'heure_reelle': reelle == null ? null : DatesSql.dateHeure(reelle),
      'statut': statut.valeur,
    };
  }
}
