import '../dates_sql.dart';

/// Cycle de vie : brouillon → validée → partiellement délivrée → délivrée.
/// Une ordonnance validée peut aussi devenir expirée ou annulée.
enum StatutOrdonnance {
  brouillon('brouillon', 'Brouillon'),
  validee('validee', 'Validée'),
  partiellementDelivree('partiellement_delivree', 'Partiellement délivrée'),
  delivree('delivree', 'Délivrée'),
  expiree('expiree', 'Expirée'),
  annulee('annulee', 'Annulée');

  const StatutOrdonnance(this.valeur, this.libelle);

  /// Valeur stockée en base.
  final String valeur;
  final String libelle;

  /// Peut encore être délivrée et suivie (planning, observance).
  bool get estActive =>
      this == StatutOrdonnance.validee ||
      this == StatutOrdonnance.partiellementDelivree;

  static StatutOrdonnance depuis(Object? valeur) {
    for (final StatutOrdonnance s in StatutOrdonnance.values) {
      if (s.valeur == valeur) {
        return s;
      }
    }
    return StatutOrdonnance.brouillon;
  }
}

/// Ordonnance datée d'un médecin (table ordonnance).
class Ordonnance {
  /// Validité par défaut d'une ordonnance (paramétrable).
  static const int validiteJoursParDefaut = 90;

  final int? id;

  /// ORD-2026-0001
  final String numero;
  final int patientId;

  /// medecins.id (le compte connecté y pointe via utilisateurs.ref_id).
  final int medecinId;

  /// Consultation du module Rendez-vous (pas encore de table).
  final int? consultationId;
  final DateTime dateEmission;
  final DateTime dateExpiration;
  final StatutOrdonnance statut;
  final int nbRenouvellements;

  /// Ordonnance d'origine d'un renouvellement ou d'une correction.
  final int? ordonnanceOrigineId;

  /// SHA-256 calculé à la validation (voir AuthenticiteOrdonnance).
  final String? hashSignature;
  final String? motifAnnulation;

  const Ordonnance({
    this.id,
    required this.numero,
    required this.patientId,
    required this.medecinId,
    this.consultationId,
    required this.dateEmission,
    required this.dateExpiration,
    this.statut = StatutOrdonnance.brouillon,
    this.nbRenouvellements = 0,
    this.ordonnanceOrigineId,
    this.hashSignature,
    this.motifAnnulation,
  });

  /// Seul un brouillon se modifie ou se supprime.
  bool get estModifiable => statut == StatutOrdonnance.brouillon;

  Ordonnance copyWith({
    int? id,
    String? numero,
    StatutOrdonnance? statut,
    int? nbRenouvellements,
    String? hashSignature,
    String? motifAnnulation,
  }) {
    return Ordonnance(
      id: id ?? this.id,
      numero: numero ?? this.numero,
      patientId: patientId,
      medecinId: medecinId,
      consultationId: consultationId,
      dateEmission: dateEmission,
      dateExpiration: dateExpiration,
      statut: statut ?? this.statut,
      nbRenouvellements: nbRenouvellements ?? this.nbRenouvellements,
      ordonnanceOrigineId: ordonnanceOrigineId,
      hashSignature: hashSignature ?? this.hashSignature,
      motifAnnulation: motifAnnulation ?? this.motifAnnulation,
    );
  }

  factory Ordonnance.fromMap(Map<String, Object?> map) {
    return Ordonnance(
      id: map['id'] as int?,
      numero: map['numero'] as String,
      patientId: map['patient_id'] as int,
      medecinId: map['medecin_id'] as int,
      consultationId: map['consultation_id'] as int?,
      dateEmission: DatesSql.lire(map['date_emission']),
      dateExpiration: DatesSql.lire(map['date_expiration']),
      statut: StatutOrdonnance.depuis(map['statut']),
      nbRenouvellements: (map['nb_renouvellements'] as int?) ?? 0,
      ordonnanceOrigineId: map['ordonnance_origine_id'] as int?,
      hashSignature: map['hash_signature'] as String?,
      motifAnnulation: map['motif_annulation'] as String?,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'numero': numero,
      'patient_id': patientId,
      'medecin_id': medecinId,
      'consultation_id': consultationId,
      'date_emission': DatesSql.date(dateEmission),
      'date_expiration': DatesSql.date(dateExpiration),
      'statut': statut.valeur,
      'nb_renouvellements': nbRenouvellements,
      'ordonnance_origine_id': ordonnanceOrigineId,
      'hash_signature': hashSignature,
      'motif_annulation': motifAnnulation,
    };
  }
}
