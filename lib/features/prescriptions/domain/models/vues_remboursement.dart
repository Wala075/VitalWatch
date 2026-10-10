import 'assurance.dart';
import 'contrat_assurance.dart';
import 'dossier_remboursement.dart';

/// Dossier + ordonnance, patient et assurance (listes, fiche).
class DossierResume {
  const DossierResume({
    required this.dossier,
    required this.ordonnanceNumero,
    required this.dateOrdonnance,
    required this.patientId,
    required this.patientNom,
    required this.assuranceNom,
    required this.delaiReponseJours,
  });

  final DossierRemboursement dossier;
  final String ordonnanceNumero;
  final DateTime dateOrdonnance;
  final int patientId;
  final String patientNom;
  final String assuranceNom;
  final int delaiReponseJours;

  /// En attente de réponse depuis plus que le délai de l'assurance (relance).
  bool get enRetard {
    final DateTime? depot = dossier.dateDepot;
    final bool attente =
        dossier.statut == StatutDossier.soumis || dossier.statut == StatutDossier.enCours;
    return attente &&
        depot != null &&
        DateTime.now().difference(depot).inDays > delaiReponseJours;
  }
}

/// Contrat avec son assurance et la consommation de son plafond (métier 10).
class ContratDetail {
  const ContratDetail({
    required this.contrat,
    required this.assurance,
    required this.consomme,
  });

  final ContratAssurance contrat;
  final Assurance assurance;

  /// Part obligatoire remboursée cette année (recalculée, jamais stockée).
  final double consomme;

  /// Seuil d'alerte : 80 % du plafond.
  static const double seuilAlerte = 0.8;

  double? get plafond => assurance.plafondAnnuel;

  /// Entre 0 et 1 ; null sans plafond.
  double? get ratio {
    final double? p = plafond;
    if (p == null || p <= 0) {
      return null;
    }
    final double r = consomme / p;
    return r > 1 ? 1 : r;
  }

  double? get restant {
    final double? p = plafond;
    if (p == null) {
      return null;
    }
    final double r = p - consomme;
    return r < 0 ? 0 : r;
  }

  bool get alerte => (ratio ?? 0) >= seuilAlerte;

  bool get actif => contrat.estActifLe(DateTime.now());
}

/// Conditions avant tout calcul (métier 7).
class Eligibilite {
  const Eligibilite({
    this.cnam,
    this.complementaire,
    this.plafondRestant,
    required this.bloquants,
    required this.remarques,
  });

  /// Contrat CNAM actif à la date de l'ordonnance.
  final ContratDetail? cnam;

  /// Mutuelle ou assurance privée active.
  final ContratDetail? complementaire;

  /// null : pas de plafond.
  final double? plafondRestant;
  final List<String> bloquants;
  final List<String> remarques;

  bool get eligible => bloquants.isEmpty;
}
