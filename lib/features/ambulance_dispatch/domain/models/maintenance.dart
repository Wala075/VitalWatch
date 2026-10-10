/// Type d'entretien + intervalle kilométrique conseillé avant le suivant.
enum TypeMaintenance {
  vidange('vidange', 'Vidange', 10000),
  revision('revision', 'Révision générale', 20000),
  freins('freins', 'Freins', 30000),
  pneus('pneus', 'Pneumatiques', 40000),
  equipement('equipement', 'Équipement médical', 15000),
  reparation('reparation', 'Réparation', 10000);

  const TypeMaintenance(this.code, this.libelle, this.intervalleKm);

  final String code;
  final String libelle;
  final int intervalleKm;

  static TypeMaintenance depuisCode(String? code) {
    for (final TypeMaintenance t in TypeMaintenance.values) {
      if (t.code == code) {
        return t;
      }
    }
    return TypeMaintenance.revision;
  }
}

enum StatutMaintenance {
  planifiee('planifiee', 'Planifiée'),
  enCours('en_cours', 'En cours'),
  terminee('terminee', 'Terminée');

  const StatutMaintenance(this.code, this.libelle);

  final String code;
  final String libelle;

  static StatutMaintenance depuisCode(String? code) {
    for (final StatutMaintenance s in StatutMaintenance.values) {
      if (s.code == code) {
        return s;
      }
    }
    return StatutMaintenance.terminee;
  }
}

class Maintenance {
  final int? id;
  final int ambulanceId;
  final TypeMaintenance type;
  final DateTime date;
  final double cout;

  /// Kilométrage auquel l'ambulance devra repasser à l'entretien.
  final int? prochainEntretienKm;
  final StatutMaintenance statut;

  const Maintenance({
    this.id,
    required this.ambulanceId,
    required this.type,
    required this.date,
    this.cout = 0,
    this.prochainEntretienKm,
    this.statut = StatutMaintenance.terminee,
  });

  Maintenance copyWith({
    int? id,
    DateTime? date,
    double? cout,
    int? prochainEntretienKm,
    StatutMaintenance? statut,
  }) {
    return Maintenance(
      id: id ?? this.id,
      ambulanceId: ambulanceId,
      type: type,
      date: date ?? this.date,
      cout: cout ?? this.cout,
      prochainEntretienKm: prochainEntretienKm ?? this.prochainEntretienKm,
      statut: statut ?? this.statut,
    );
  }

  factory Maintenance.fromMap(Map<String, Object?> map) {
    return Maintenance(
      id: map['id'] as int?,
      ambulanceId: map['ambulance_id'] as int,
      type: TypeMaintenance.depuisCode(map['type'] as String?),
      date: DateTime.parse(map['date'] as String),
      cout: ((map['cout'] as num?) ?? 0).toDouble(),
      prochainEntretienKm: map['prochain_entretien_km'] as int?,
      statut: StatutMaintenance.depuisCode(map['statut'] as String?),
    );
  }

  Map<String, Object?> toMap() {
    return {
      'ambulance_id': ambulanceId,
      'type': type.code,
      'date': _jour(date),
      'cout': cout,
      'prochain_entretien_km': prochainEntretienKm,
      'statut': statut.code,
    };
  }

  /// Date seule (AAAA-MM-JJ) : les maintenances se planifient à la journée.
  static String _jour(DateTime d) {
    final String m = d.month.toString().padLeft(2, '0');
    final String j = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$j';
  }
}
