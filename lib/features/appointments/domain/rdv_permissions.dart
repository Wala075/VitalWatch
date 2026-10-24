import '../../../models/utilisateur.dart';

/// Ce que chaque profil peut faire dans le module Rendez-vous.
///
/// | Action                         | Admin | Médecin   | Infirmier | Patient |
/// |--------------------------------|:-----:|:---------:|:---------:|:-------:|
/// | Prendre un RDV                 |  oui  |    oui    |    oui    | pour lui|
/// | Demande urgente                |  oui  |    -      |    oui    |   oui   |
/// | Voir tous les RDV              |  oui  | les siens |    oui    |les siens|
/// | Confirmer / marquer absent     |  oui  |    oui    |    oui    |    -    |
/// | Démarrer / rédiger consultation|   -   |    oui    |    -      |    -    |
/// | Gérer les créneaux             | tous  | les siens |    -      |    -    |
/// | Statistiques                   | toutes| les siennes|   -      |    -    |
extension RdvPermissions on Role {
  bool get accesRdv => this != Role.ambulancier;

  bool get prendreRdvPourAutrui =>
      this == Role.admin || this == Role.medecin || this == Role.infirmier;

  bool get demandeUrgente =>
      this == Role.patient || this == Role.infirmier || this == Role.admin;

  bool get voirTousLesRdv => this == Role.admin || this == Role.infirmier;

  bool get gererStatutRdv =>
      this == Role.admin || this == Role.medecin || this == Role.infirmier;

  /// Annuler sans la limite des 2 h (le patient, lui, est limité).
  bool get annulerSansDelai => gererStatutRdv;

  bool get consulter => this == Role.medecin;

  bool get gererTousLesCreneaux => this == Role.admin;

  bool get gererSesCreneaux => this == Role.medecin;

  bool get voirStatsRdv => this == Role.admin || this == Role.medecin;
}
