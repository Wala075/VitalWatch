/// Un médicament de l'ordonnance, sa posologie et sa durée (table ligne_ordonnance).
class LigneOrdonnance {
  final int? id;
  final int ordonnanceId;
  final int medicamentId;

  /// En unités du médicament (comprimés, ml, bouffées…).
  final double dosePrise;
  final int prisesParJour;

  /// Moments de prise : matin, midi, soir, coucher (voir PlanningPrises).
  final List<String> moments;
  final int dureeJours;

  /// Calculée par CalculBoites.
  final int quantiteBoites;
  final int quantiteDelivree;
  final bool substitutionAutorisee;

  /// Ligne liée à la maladie APCI du patient (prise en charge à 100 %).
  final bool lienApci;
  final String? instructions;

  const LigneOrdonnance({
    this.id,
    required this.ordonnanceId,
    required this.medicamentId,
    required this.dosePrise,
    required this.prisesParJour,
    required this.moments,
    required this.dureeJours,
    required this.quantiteBoites,
    this.quantiteDelivree = 0,
    this.substitutionAutorisee = true,
    this.lienApci = false,
    this.instructions,
  });

  /// Unités prises par jour.
  double get doseJour => dosePrise * prisesParJour;

  int get resteADelivrer => quantiteBoites - quantiteDelivree;

  bool get estDelivree => quantiteDelivree >= quantiteBoites;

  LigneOrdonnance copyWith({int? id, int? ordonnanceId, int? quantiteDelivree}) {
    return LigneOrdonnance(
      id: id ?? this.id,
      ordonnanceId: ordonnanceId ?? this.ordonnanceId,
      medicamentId: medicamentId,
      dosePrise: dosePrise,
      prisesParJour: prisesParJour,
      moments: moments,
      dureeJours: dureeJours,
      quantiteBoites: quantiteBoites,
      quantiteDelivree: quantiteDelivree ?? this.quantiteDelivree,
      substitutionAutorisee: substitutionAutorisee,
      lienApci: lienApci,
      instructions: instructions,
    );
  }

  factory LigneOrdonnance.fromMap(Map<String, Object?> map) {
    final List<String> moments = [];
    for (final String m in ((map['moments'] as String?) ?? '').split(',')) {
      if (m.trim().isNotEmpty) {
        moments.add(m.trim());
      }
    }
    return LigneOrdonnance(
      id: map['id'] as int?,
      ordonnanceId: map['ordonnance_id'] as int,
      medicamentId: map['medicament_id'] as int,
      dosePrise: (map['dose_par_prise'] as num).toDouble(),
      prisesParJour: map['prises_par_jour'] as int,
      moments: moments,
      dureeJours: map['duree_jours'] as int,
      quantiteBoites: map['quantite_boites'] as int,
      quantiteDelivree: (map['quantite_delivree'] as int?) ?? 0,
      substitutionAutorisee: ((map['substitution_autorisee'] as int?) ?? 1) == 1,
      lienApci: ((map['lien_apci'] as int?) ?? 0) == 1,
      instructions: map['instructions'] as String?,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'ordonnance_id': ordonnanceId,
      'medicament_id': medicamentId,
      'dose_par_prise': dosePrise,
      'prises_par_jour': prisesParJour,
      'moments': moments.join(','),
      'duree_jours': dureeJours,
      'quantite_boites': quantiteBoites,
      'quantite_delivree': quantiteDelivree,
      'substitution_autorisee': substitutionAutorisee ? 1 : 0,
      'lien_apci': lienApci ? 1 : 0,
      'instructions': instructions,
    };
  }
}
