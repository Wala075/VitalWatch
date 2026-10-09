import '../../../models/utilisateur.dart';

/// Droits du module Ordonnances & Assurance selon le profil connecté.
extension PrescriptionsPermissions on Role {
  /// Tous les profils sauf l'ambulancier.
  bool get accesOrdonnances => this != Role.ambulancier;

  /// Catalogue des médicaments, assurances et taux, référentiel APCI.
  bool get gererReferentiels => this == Role.admin;

  /// Créer, valider, annuler et renouveler une ordonnance.
  bool get prescrire => this == Role.medecin;

  /// Scanner le QR code et enregistrer les boîtes délivrées.
  bool get delivrer => this == Role.pharmacien;

  /// Contrats d'assurance des patients.
  bool get gererContrats => this == Role.admin;

  /// Dossiers de remboursement et paiement du reste à charge.
  bool get suivreDossiers => this == Role.admin || this == Role.patient;

  /// Cocher ses prises (planning du jour).
  bool get suivrePrises => this == Role.patient;

  bool get voirStatistiques => this == Role.admin || this == Role.medecin;
}
