/// MODULE 4 — Rendez-vous & Téléconsultation : entités et objets métier.
library;

// =====================================================================
// Énumérations (valeur stockée en base = name)
// =====================================================================

enum TypeRdv { presentiel, visio }

enum StatutRdv { enAttente, confirme, enCours, termine, annule, absent }

enum PrioriteRdv { normale, haute, urgente }

extension TypeRdvLibelle on TypeRdv {
  String get libelle => this == TypeRdv.visio ? 'Téléconsultation' : 'Présentiel';
}

extension StatutRdvLibelle on StatutRdv {
  String get libelle {
    switch (this) {
      case StatutRdv.enAttente:
        return 'En attente';
      case StatutRdv.confirme:
        return 'Confirmé';
      case StatutRdv.enCours:
        return 'En cours';
      case StatutRdv.termine:
        return 'Terminé';
      case StatutRdv.annule:
        return 'Annulé';
      case StatutRdv.absent:
        return 'Absent';
    }
  }

  /// RDV qui occupe encore le créneau du médecin.
  bool get estActif =>
      this == StatutRdv.enAttente ||
      this == StatutRdv.confirme ||
      this == StatutRdv.enCours;
}

extension PrioriteRdvLibelle on PrioriteRdv {
  String get libelle {
    switch (this) {
      case PrioriteRdv.normale:
        return 'Normale';
      case PrioriteRdv.haute:
        return 'Haute';
      case PrioriteRdv.urgente:
        return 'Urgente';
    }
  }

  /// Poids utilisé pour trier la file d'attente.
  int get poids {
    switch (this) {
      case PrioriteRdv.normale:
        return 1;
      case PrioriteRdv.haute:
        return 2;
      case PrioriteRdv.urgente:
        return 3;
    }
  }
}

T _enumDepuis<T extends Enum>(List<T> valeurs, Object? nom, T defaut) {
  for (final T v in valeurs) {
    if (v.name == nom) {
      return v;
    }
  }
  return defaut;
}

// =====================================================================
// Creneau : plage de disponibilité d'un médecin
// =====================================================================

/// Si [recurrent] : chaque semaine le [jour] (1 = lundi ... 7 = dimanche).
/// Sinon : une seule fois, à la [date] indiquée.
class Creneau {
  const Creneau({
    this.id,
    required this.medecinId,
    required this.jour,
    this.date,
    required this.heureDebut,
    required this.heureFin,
    this.recurrent = true,
    this.dureeRdv = 30,
  });

  final int? id;
  final int medecinId;
  final int jour;
  final DateTime? date;

  /// Minutes depuis minuit (ex : 9h30 = 570).
  final int heureDebut;
  final int heureFin;
  final bool recurrent;

  /// Durée d'un rendez-vous dans ce créneau (minutes).
  final int dureeRdv;

  /// Le créneau s'applique-t-il à ce jour ?
  bool concerne(DateTime d) {
    final DateTime? date = this.date;
    if (recurrent) {
      return d.weekday == jour;
    }
    return date != null &&
        date.year == d.year &&
        date.month == d.month &&
        date.day == d.day;
  }

  factory Creneau.fromMap(Map<String, Object?> map) {
    final Object? date = map['date'];
    return Creneau(
      id: map['id'] as int?,
      medecinId: map['medecin_id'] as int,
      jour: (map['jour'] as int?) ?? 1,
      date: date == null ? null : DateTime.parse(date as String),
      heureDebut: map['heure_debut'] as int,
      heureFin: map['heure_fin'] as int,
      recurrent: ((map['recurrent'] as int?) ?? 1) == 1,
      dureeRdv: (map['duree_rdv'] as int?) ?? 30,
    );
  }

  Map<String, Object?> toMap() {
    final DateTime? d = date;
    return {
      'medecin_id': medecinId,
      'jour': jour,
      'date': d == null ? null : d.toIso8601String().substring(0, 10),
      'heure_debut': heureDebut,
      'heure_fin': heureFin,
      'recurrent': recurrent ? 1 : 0,
      'duree_rdv': dureeRdv,
    };
  }
}

// =====================================================================
// RendezVous
// =====================================================================

class RendezVous {
  const RendezVous({
    this.id,
    required this.patientId,
    required this.medecinId,
    required this.dateHeure,
    this.duree = 30,
    required this.type,
    required this.motif,
    this.statut = StatutRdv.enAttente,
    this.priorite = PrioriteRdv.normale,
    this.lienVisio,
    this.creePar,
    this.motifAnnulation,
    this.dateCreation,
  });

  final int? id;
  final int patientId;
  final int medecinId;
  final DateTime dateHeure;

  /// Durée prévue (minutes).
  final int duree;
  final TypeRdv type;
  final String motif;
  final StatutRdv statut;
  final PrioriteRdv priorite;
  final String? lienVisio;

  /// Id de l'utilisateur qui a pris le RDV (patient ou personnel).
  final int? creePar;
  final String? motifAnnulation;
  final DateTime? dateCreation;

  DateTime get fin => dateHeure.add(Duration(minutes: duree));

  bool get estUrgent => priorite == PrioriteRdv.urgente;

  RendezVous copyWith({
    int? id,
    int? medecinId,
    DateTime? dateHeure,
    StatutRdv? statut,
    PrioriteRdv? priorite,
    String? lienVisio,
    String? motifAnnulation,
  }) {
    return RendezVous(
      id: id ?? this.id,
      patientId: patientId,
      medecinId: medecinId ?? this.medecinId,
      dateHeure: dateHeure ?? this.dateHeure,
      duree: duree,
      type: type,
      motif: motif,
      statut: statut ?? this.statut,
      priorite: priorite ?? this.priorite,
      lienVisio: lienVisio ?? this.lienVisio,
      creePar: creePar,
      motifAnnulation: motifAnnulation ?? this.motifAnnulation,
      dateCreation: dateCreation,
    );
  }

  factory RendezVous.fromMap(Map<String, Object?> map) {
    final Object? creation = map['date_creation'];
    return RendezVous(
      id: map['id'] as int?,
      patientId: map['patient_id'] as int,
      medecinId: map['medecin_id'] as int,
      dateHeure: DateTime.parse(map['date_heure'] as String),
      duree: (map['duree'] as int?) ?? 30,
      type: _enumDepuis(TypeRdv.values, map['type'], TypeRdv.presentiel),
      motif: (map['motif'] as String?) ?? '',
      statut: _enumDepuis(StatutRdv.values, map['statut'], StatutRdv.enAttente),
      priorite:
          _enumDepuis(PrioriteRdv.values, map['priorite'], PrioriteRdv.normale),
      lienVisio: map['lien_visio'] as String?,
      creePar: map['cree_par'] as int?,
      motifAnnulation: map['motif_annulation'] as String?,
      dateCreation: creation == null ? null : DateTime.parse(creation as String),
    );
  }

  Map<String, Object?> toMap() {
    return {
      'patient_id': patientId,
      'medecin_id': medecinId,
      'date_heure': dateHeure.toIso8601String(),
      'duree': duree,
      'type': type.name,
      'motif': motif,
      'statut': statut.name,
      'priorite': priorite.name,
      'lien_visio': lienVisio,
      'cree_par': creePar,
      'motif_annulation': motifAnnulation,
      'date_creation': (dateCreation ?? DateTime.now()).toIso8601String(),
    };
  }
}

// =====================================================================
// Consultation : ce qui s'est passé pendant le RDV
// =====================================================================

class Consultation {
  const Consultation({
    this.id,
    required this.rdvId,
    required this.diagnostic,
    required this.compteRendu,
    this.resumeIa,
    this.debut,
    this.fin,
    this.dureeReelle,
  });

  final int? id;
  final int rdvId;
  final String diagnostic;
  final String compteRendu;
  final String? resumeIa;
  final DateTime? debut;
  final DateTime? fin;

  /// Durée réelle en minutes.
  final int? dureeReelle;

  factory Consultation.fromMap(Map<String, Object?> map) {
    final Object? debut = map['debut'];
    final Object? fin = map['fin'];
    return Consultation(
      id: map['id'] as int?,
      rdvId: map['rdv_id'] as int,
      diagnostic: (map['diagnostic'] as String?) ?? '',
      compteRendu: (map['compte_rendu'] as String?) ?? '',
      resumeIa: map['resume_ia'] as String?,
      debut: debut == null ? null : DateTime.parse(debut as String),
      fin: fin == null ? null : DateTime.parse(fin as String),
      dureeReelle: map['duree_reelle'] as int?,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'rdv_id': rdvId,
      'diagnostic': diagnostic,
      'compte_rendu': compteRendu,
      'resume_ia': resumeIa,
      'debut': debut?.toIso8601String(),
      'fin': fin?.toIso8601String(),
      'duree_reelle': dureeReelle,
    };
  }
}

// =====================================================================
// Objets d'affichage et résultats
// =====================================================================

/// RDV + noms du patient, du médecin et du service (jointures).
class RdvDetail {
  const RdvDetail({
    required this.rdv,
    required this.patientNom,
    required this.medecinNom,
    this.specialite,
    this.serviceNom,
    this.alerteRecente = false,
  });

  final RendezVous rdv;
  final String patientNom;
  final String medecinNom;
  final String? specialite;
  final String? serviceNom;

  /// Le patient a eu une alerte (module Patients) dans les dernières 48 h.
  final bool alerteRecente;
}

/// Erreur métier affichable à l'utilisateur.
class RdvException implements Exception {
  const RdvException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Le créneau demandé est déjà pris : on propose le prochain créneau libre.
class ConflitCreneauException extends RdvException {
  const ConflitCreneauException(super.message, {this.proposition});

  final DateTime? proposition;
}

/// Rappel J-1 / H-1 à afficher à l'utilisateur.
class Rappel {
  const Rappel({required this.detail, required this.libelle});

  final RdvDetail detail;

  /// « Demain » ou « Dans moins d'une heure ».
  final String libelle;
}

/// Statistiques d'un médecin.
class StatsMedecin {
  const StatsMedecin({
    required this.medecinId,
    required this.medecinNom,
    required this.total,
    required this.termines,
    required this.absents,
    required this.annules,
    required this.aVenir,
    required this.cetteSemaine,
    this.dureeMoyenne,
  });

  final int medecinId;
  final String medecinNom;
  final int total;
  final int termines;
  final int absents;
  final int annules;
  final int aVenir;
  final int cetteSemaine;

  /// Durée réelle moyenne des consultations (minutes).
  final double? dureeMoyenne;

  /// Absents / (terminés + absents).
  double get tauxAbsenteisme {
    final int base = termines + absents;
    return base == 0 ? 0 : absents / base;
  }
}

/// Statistiques globales du module.
class StatsRdv {
  const StatsRdv({required this.parMedecin});

  final List<StatsMedecin> parMedecin;

  int get total => parMedecin.fold(0, (int s, StatsMedecin m) => s + m.total);

  int get termines =>
      parMedecin.fold(0, (int s, StatsMedecin m) => s + m.termines);

  int get absents => parMedecin.fold(0, (int s, StatsMedecin m) => s + m.absents);

  int get aVenir => parMedecin.fold(0, (int s, StatsMedecin m) => s + m.aVenir);

  double get tauxAbsenteisme {
    final int base = termines + absents;
    return base == 0 ? 0 : absents / base;
  }
}

/// Filtres de la liste des RDV (admin / infirmier).
class RdvFiltre {
  const RdvFiltre({
    this.texte = '',
    this.medecinId,
    this.patientId,
    this.statut,
    this.type,
    this.jour,
  });

  final String texte;
  final int? medecinId;
  final int? patientId;
  final StatutRdv? statut;
  final TypeRdv? type;

  /// Limite aux RDV de ce jour.
  final DateTime? jour;

  int get nbFiltresActifs =>
      (medecinId != null ? 1 : 0) +
      (statut != null ? 1 : 0) +
      (type != null ? 1 : 0) +
      (jour != null ? 1 : 0);

  RdvFiltre avecTexte(String t) => RdvFiltre(
        texte: t,
        medecinId: medecinId,
        patientId: patientId,
        statut: statut,
        type: type,
        jour: jour,
      );
}
