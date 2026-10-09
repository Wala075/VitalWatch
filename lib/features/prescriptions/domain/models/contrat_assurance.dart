import '../dates_sql.dart';

enum Beneficiaire {
  assure('assure', 'Assuré'),
  conjoint('conjoint', 'Conjoint'),
  enfant('enfant', 'Enfant');

  const Beneficiaire(this.valeur, this.libelle);

  /// Valeur stockée en base.
  final String valeur;
  final String libelle;

  static Beneficiaire depuis(Object? valeur) {
    for (final Beneficiaire b in Beneficiaire.values) {
      if (b.valeur == valeur) {
        return b;
      }
    }
    return Beneficiaire.assure;
  }
}

/// Filière choisie à la CNAM.
enum FiliereCnam {
  publique('publique', 'Filière publique'),
  privee('privee', 'Filière privée'),
  remboursement('remboursement', 'Système de remboursement');

  const FiliereCnam(this.valeur, this.libelle);

  /// Valeur stockée en base.
  final String valeur;
  final String libelle;

  static FiliereCnam? depuis(Object? valeur) {
    for (final FiliereCnam f in FiliereCnam.values) {
      if (f.valeur == valeur) {
        return f;
      }
    }
    return null;
  }
}

/// Couverture d'un patient par un organisme (table contrat_assurance).
class ContratAssurance {
  final int? id;
  final int patientId;
  final int assuranceId;
  final String numeroAdherent;

  /// Seulement pour la CNAM.
  final FiliereCnam? filiere;
  final Beneficiaire beneficiaire;
  final DateTime dateDebut;

  /// null = contrat en cours ; renseignée à la résiliation.
  final DateTime? dateFin;
  final bool apci;
  final String? codeApci;

  const ContratAssurance({
    this.id,
    required this.patientId,
    required this.assuranceId,
    required this.numeroAdherent,
    this.filiere,
    this.beneficiaire = Beneficiaire.assure,
    required this.dateDebut,
    this.dateFin,
    this.apci = false,
    this.codeApci,
  });

  /// date_debut ≤ date ≤ date_fin (ou pas de date de fin).
  bool estActifLe(DateTime date) {
    final DateTime jour = DatesSql.jour(date);
    if (jour.isBefore(DatesSql.jour(dateDebut))) {
      return false;
    }
    final DateTime? fin = dateFin;
    return fin == null || !jour.isAfter(DatesSql.jour(fin));
  }

  factory ContratAssurance.fromMap(Map<String, Object?> map) {
    return ContratAssurance(
      id: map['id'] as int?,
      patientId: map['patient_id'] as int,
      assuranceId: map['assurance_id'] as int,
      numeroAdherent: map['numero_adherent'] as String,
      filiere: FiliereCnam.depuis(map['filiere']),
      beneficiaire: Beneficiaire.depuis(map['beneficiaire']),
      dateDebut: DatesSql.lire(map['date_debut']),
      dateFin: DatesSql.lireOuNull(map['date_fin']),
      apci: ((map['apci'] as int?) ?? 0) == 1,
      codeApci: map['code_apci'] as String?,
    );
  }

  Map<String, Object?> toMap() {
    final DateTime? fin = dateFin;
    return {
      'patient_id': patientId,
      'assurance_id': assuranceId,
      'numero_adherent': numeroAdherent,
      'filiere': filiere?.valeur,
      'beneficiaire': beneficiaire.valeur,
      'date_debut': DatesSql.date(dateDebut),
      'date_fin': fin == null ? null : DatesSql.date(fin),
      'apci': apci ? 1 : 0,
      'code_apci': apci ? codeApci : null,
    };
  }
}
