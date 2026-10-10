import '../../../models/utilisateur.dart';

/// Droits du module Ordonnances & Assurance selon le profil connecté.
extension PrescriptionsPermissions on Role {
  /// Tous les profils sauf l'ambulancier.
  bool get accesOrdonnances => this != Role.ambulancier;

  /// Catalogue des médicaments, assurances et taux, référentiel APCI.
  bool get gererReferentiels => this == Role.admin;

  /// Créer, valider, annuler, corriger et renouveler une ordonnance.
  bool get prescrire => this == Role.medecin;

  /// Retrouver l'ordonnance (QR code ou numéro) et enregistrer la délivrance.
  bool get delivrer => this == Role.pharmacien;

  /// Liste des patients : ordonnances, traitements, contrats, dossiers.
  bool get voirPatients => this == Role.admin || this == Role.infirmier;

  /// Contrats d'assurance des patients (création, résiliation).
  bool get gererContrats => this == Role.admin;

  /// Réponse de la CNAM simulée, remboursement, relances.
  bool get traiterDossiers => this == Role.admin;

  /// Espace du patient : planning, observance, ses ordonnances, ses dossiers.
  bool get espacePatient => this == Role.patient;

  bool get voirStatistiques => this == Role.admin || this == Role.medecin;
}
