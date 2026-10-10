import 'models/ambulance.dart';
import 'models/ambulancier.dart';
import 'models/intervention.dart';
import 'models/maintenance.dart';

/// Erreur métier affichable à l'utilisateur.
class DispatchException implements Exception {
  const DispatchException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Ambulance + équipage + suivi d'entretien (liste de la flotte).
class AmbulanceDetail {
  const AmbulanceDetail({
    required this.ambulance,
    required this.nbEquipiers,
    required this.nbEquipiersDisponibles,
    required this.nbMissions,
    this.seuilEntretienKm,
    this.nbMaintenancesEnCours = 0,
  });

  /// Alerte « entretien proche » sous cette marge.
  static const int margeAlerteKm = 1000;

  final Ambulance ambulance;
  final int nbEquipiers;
  final int nbEquipiersDisponibles;
  final int nbMissions;

  /// prochain_entretien_km de la dernière maintenance terminée.
  final int? seuilEntretienKm;
  final int nbMaintenancesEnCours;

  int? get kmAvantEntretien {
    final int? seuil = seuilEntretienKm;
    if (seuil == null) {
      return null;
    }
    return seuil - ambulance.kilometrage;
  }

  bool get seuilDepasse {
    final int? reste = kmAvantEntretien;
    return reste != null && reste <= 0;
  }

  bool get entretienProche {
    final int? reste = kmAvantEntretien;
    return reste != null && reste > 0 && reste <= margeAlerteKm;
  }

  bool get aEquipage => nbEquipiersDisponibles > 0;
}

/// Intervention + libellés joints (ambulance, patient).
class InterventionDetail {
  const InterventionDetail({
    required this.intervention,
    this.immatriculation,
    this.typeAmbulance,
    this.patientNom,
  });

  final Intervention intervention;
  final String? immatriculation;
  final TypeAmbulance? typeAmbulance;
  final String? patientNom;
}

class AmbulancierDetail {
  const AmbulancierDetail({required this.ambulancier, this.immatriculation});

  final Ambulancier ambulancier;
  final String? immatriculation;
}

class MaintenanceDetail {
  const MaintenanceDetail({required this.maintenance, required this.immatriculation});

  final Maintenance maintenance;
  final String immatriculation;
}

/// Résultat du dispatch automatique.
class ResultatDispatch {
  const ResultatDispatch({
    required this.intervention,
    this.ambulance,
    this.distanceKm,
    this.justification,
    this.reaffectee,
  });

  final Intervention intervention;
  final Ambulance? ambulance;
  final double? distanceKm;
  final String? justification;

  /// Intervention moins grave dont l'ambulance a été réquisitionnée.
  final Intervention? reaffectee;

  bool get assignee => ambulance != null;
}

/// Candidat évalué par l'algorithme de dispatch.
class CandidatDispatch {
  const CandidatDispatch({
    required this.ambulance,
    required this.distanceKm,
    required this.score,
  });

  final Ambulance ambulance;
  final double distanceKm;

  /// Distance pondérée selon l'adéquation type d'ambulance / gravité.
  final double score;
}

/// Indicateurs du tableau de bord.
class KpiDispatch {
  const KpiDispatch({
    required this.nbInterventions,
    required this.nbTerminees,
    required this.nbEnCours,
    required this.nbEnAttente,
    this.tempsMoyenReponse,
    this.tempsMoyenDepart,
    required this.tauxObjectif,
    required this.missionsParAmbulance,
    required this.parGravite,
    required this.tempsParGravite,
    required this.flotteDisponible,
    required this.flotteTotale,
    required this.coutMaintenance,
  });

  /// Objectif de temps de réponse (appel → arrivée).
  static const Duration objectif = Duration(minutes: 15);

  final int nbInterventions;
  final int nbTerminees;
  final int nbEnCours;
  final int nbEnAttente;
  final Duration? tempsMoyenReponse;
  final Duration? tempsMoyenDepart;

  /// Part des interventions arrivées en moins de [objectif].
  final double tauxObjectif;

  /// Immatriculation → nombre de missions.
  final Map<String, int> missionsParAmbulance;
  final Map<Gravite, int> parGravite;
  final Map<Gravite, Duration> tempsParGravite;
  final int flotteDisponible;
  final int flotteTotale;
  final double coutMaintenance;
}
