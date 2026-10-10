import '../../../models/utilisateur.dart';

/// Droits du module Ambulances & Interventions selon le profil connecté.
extension AmbulancePermissions on Role {
  /// Régulation : carte, interventions, suivi. Le patient a son espace SOS ;
  /// le pharmacien (module Ordonnances) n'y a pas accès.
  bool get accesRegulation => this != Role.patient && this != Role.pharmacien;

  /// Ajouter / modifier / supprimer ambulances, équipages, maintenances.
  bool get gererFlotte => this == Role.admin;

  bool get creerIntervention =>
      this == Role.admin || this == Role.medecin || this == Role.infirmier;

  /// Faire avancer une mission (départ, arrivée, transport, fin).
  bool get piloterMission =>
      this == Role.admin ||
      this == Role.ambulancier ||
      this == Role.medecin ||
      this == Role.infirmier;

  bool get voirKpi => this == Role.admin || this == Role.medecin;

  /// Liste de suivi cardiaque de tous les patients (mesures des montres).
  /// L'ambulancier voit seulement le rythme du patient de sa mission.
  bool get suiviCardiaque =>
      this == Role.admin || this == Role.medecin || this == Role.infirmier;

  /// Fixer les seuils d'alerte cardiaque d'un patient.
  bool get reglerSeuils => this == Role.admin || this == Role.medecin;
}
