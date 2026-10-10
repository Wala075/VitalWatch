import '../../../models/utilisateur.dart';

/// Droits du module Ordonnances & Assurance selon le profil connecté.
extension PrescriptionsPermissions on Role {
  /// Tous les profils sauf l'ambulancier.
  bool get accesOrdonnances => this != Role.ambulancier;

  /// Catalogue des médicaments, assurances et taux.
  bool get gererReferentiels => this == Role.admin;

  /// Référentiel APCI (codes CIM-10) et APCI de ses patients : le médecin.
  bool get gererApci => this == Role.medecin;

  /// Médicaments couverts par chaque APCI, appliqués à la délivrance.
  bool get gererMedicamentsApci => this == Role.pharmacien;

  /// Onglet APCI : le médecin (codes) et le pharmacien (médicaments).
  bool get voirApci => gererApci || gererMedicamentsApci;

  /// Stock de la pharmacie : consultation, alertes, entrées.
  bool get gererStock => this == Role.pharmacien;

  /// Créer, valider, annuler, corriger et renouveler une ordonnance.
  bool get prescrire => this == Role.medecin;

  /// Retrouver l'ordonnance (QR code ou numéro) et enregistrer la délivrance.
  bool get delivrer => this == Role.pharmacien;

  /// Liste des patients : ordonnances, traitements, contrats, dossiers.
  bool get voirPatients => this == Role.admin || this == Role.infirmier;

  /// Contrats d'assurance des patients (création, résiliation), sans l'APCI
  /// qui est déclarée par le médecin.
  bool get gererContrats => this == Role.admin;

  /// Réponse de la CNAM simulée, remboursement, relances.
  bool get traiterDossiers => this == Role.admin;

  /// Espace du patient : planning, observance, ses ordonnances, ses dossiers.
  bool get espacePatient => this == Role.patient;

  bool get voirStatistiques => this == Role.admin || this == Role.medecin;
}
