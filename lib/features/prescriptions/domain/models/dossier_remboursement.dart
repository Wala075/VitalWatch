import '../dates_sql.dart';

/// brouillon → soumis → en cours → accepté, partiel ou refusé → remboursé.
/// Un dossier refusé peut repartir en recours (retour à soumis).
enum StatutDossier {
  brouillon('brouillon', 'Brouillon'),
  soumis('soumis', 'Soumis'),
  enCours('en_cours', 'En cours'),
  accepte('accepte', 'Accepté'),
  partiel('partiel', 'Partiel'),
  refuse('refuse', 'Refusé'),
  rembourse('rembourse', 'Remboursé');

  const StatutDossier(this.valeur, this.libelle);

  /// Valeur stockée en base.
  final String valeur;
  final String libelle;

  /// Statuts comptés dans le plafond annuel consommé.
  bool get compteDansPlafond =>
      this == StatutDossier.accepte ||
      this == StatutDossier.partiel ||
      this == StatutDossier.rembourse;

  static StatutDossier depuis(Object? valeur) {
    for (final StatutDossier s in StatutDossier.values) {
      if (s.valeur == valeur) {
        return s;
      }
    }
    return StatutDossier.brouillon;
  }
}

/// Demande de remboursement d'une ordonnance délivrée (table dossier_remboursement).
class DossierRemboursement {
  final int? id;

  /// REM-2026-0001
  final String numero;
  final int ordonnanceId;

  /// Contrat CNAM (part obligatoire).
  final int contratId;

  /// Mutuelle ou assurance privée (part complémentaire).
  final int? contratComplementaireId;
  final double montantTotal;
  final double partObligatoire;
  final double partComplementaire;
  final double resteACharge;
  final StatutDossier statut;
  final DateTime? dateDepot;
  final DateTime? dateReponse;
  final String? motifRefus;

  /// Reste à charge payé par le patient (Konnect).
  final bool restePaye;
  final String? referencePaiement;

  const DossierRemboursement({
    this.id,
    required this.numero,
    required this.ordonnanceId,
    required this.contratId,
    this.contratComplementaireId,
    required this.montantTotal,
    this.partObligatoire = 0,
    this.partComplementaire = 0,
    this.resteACharge = 0,
    this.statut = StatutDossier.brouillon,
    this.dateDepot,
    this.dateReponse,
    this.motifRefus,
    this.restePaye = false,
    this.referencePaiement,
  });

  factory DossierRemboursement.fromMap(Map<String, Object?> map) {
    return DossierRemboursement(
      id: map['id'] as int?,
      numero: map['numero'] as String,
      ordonnanceId: map['ordonnance_id'] as int,
      contratId: map['contrat_id'] as int,
      contratComplementaireId: map['contrat_complementaire_id'] as int?,
      montantTotal: (map['montant_total'] as num).toDouble(),
      partObligatoire: ((map['part_obligatoire'] as num?) ?? 0).toDouble(),
      partComplementaire: ((map['part_complementaire'] as num?) ?? 0).toDouble(),
      resteACharge: ((map['reste_a_charge'] as num?) ?? 0).toDouble(),
      statut: StatutDossier.depuis(map['statut']),
      dateDepot: DatesSql.lireOuNull(map['date_depot']),
      dateReponse: DatesSql.lireOuNull(map['date_reponse']),
      motifRefus: map['motif_refus'] as String?,
      restePaye: ((map['reste_paye'] as int?) ?? 0) == 1,
      referencePaiement: map['reference_paiement'] as String?,
    );
  }

  Map<String, Object?> toMap() {
    final DateTime? depot = dateDepot;
    final DateTime? reponse = dateReponse;
    return {
      'numero': numero,
      'ordonnance_id': ordonnanceId,
      'contrat_id': contratId,
      'contrat_complementaire_id': contratComplementaireId,
      'montant_total': montantTotal,
      'part_obligatoire': partObligatoire,
      'part_complementaire': partComplementaire,
      'reste_a_charge': resteACharge,
      'statut': statut.valeur,
      'date_depot': depot == null ? null : DatesSql.dateHeure(depot),
      'date_reponse': reponse == null ? null : DatesSql.dateHeure(reponse),
      'motif_refus': motifRefus,
      'reste_paye': restePaye ? 1 : 0,
      'reference_paiement': referencePaiement,
    };
  }
}
