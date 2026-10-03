import '../../../models/utilisateur.dart';

/// Droits du module Ambulances & Interventions selon le profil connecté.
extension AmbulancePermissions on Role {
  /// Régulation : carte, interventions, suivi.
  bool get accesRegulation => this != Role.patient;

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
}
