import '../../../core/services/email_service.dart';
import '../../../models/ambulancier.dart';
import '../../../models/infirmier.dart';
import '../../../models/medecin.dart';
import '../../../models/patient.dart';
import '../../../models/pharmacien.dart';
import '../../../models/service.dart';

/// Erreur métier affichable à l'utilisateur.
class StaffException implements Exception {
  const StaffException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Doublon potentiel (même nom + même date de naissance) :
/// l'utilisateur peut confirmer l'enregistrement.
class DoublonPatientException implements Exception {
  const DoublonPatientException(this.existant);

  final Patient existant;
}

/// Identifiants générés lors de la création automatique d'un compte.
class CompteCree {
  const CompteCree({
    required this.email,
    required this.motDePasseTemporaire,
    required this.nom,
    required this.role,
  });

  final String email;
  final String motDePasseTemporaire;
  final String nom;
  final String role;
}

class ResultatEnregistrement {
  const ResultatEnregistrement({
    required this.id,
    this.compte,
    this.message,
    this.envoi,
  });

  final int id;
  final CompteCree? compte;
  final String? message;

  /// Résultat de l'envoi automatique des identifiants par mail.
  final EnvoiEmail? envoi;
}

/// Statistiques d'un service.
class ServiceStats {
  const ServiceStats({
    required this.service,
    this.chefNom,
    required this.nbMedecins,
    required this.nbMedecinsDisponibles,
    required this.nbPatients,
  });

  final Service service;
  final String? chefNom;
  final int nbMedecins;
  final int nbMedecinsDisponibles;
  final int nbPatients;

  double get ratioPatientsParMedecin =>
      nbMedecins == 0 ? 0 : nbPatients / nbMedecins;

  double get tauxOccupation =>
      service.capacite == 0 ? 0 : nbPatients / service.capacite;

  bool get estComplet => service.capacite > 0 && nbPatients >= service.capacite;
}

class MedecinDetail {
  const MedecinDetail({
    required this.medecin,
    this.serviceNom,
    required this.nbPatients,
  });

  final Medecin medecin;
  final String? serviceNom;
  final int nbPatients;
}

class InfirmierDetail {
  const InfirmierDetail({
    required this.infirmier,
    this.serviceNom,
    required this.aCompte,
  });

  final Infirmier infirmier;
  final String? serviceNom;
  final bool aCompte;
}

/// Ambulancier + email de son compte de connexion (null : pas de compte).
class AmbulancierCompte {
  const AmbulancierCompte({required this.ambulancier, this.email});

  final Ambulancier ambulancier;
  final String? email;
}

class PharmacienDetail {
  const PharmacienDetail({required this.pharmacien, required this.aCompte});

  final Pharmacien pharmacien;
  final bool aCompte;
}

class PatientDetail {
  const PatientDetail({required this.patient, this.serviceNom, this.medecinNom});

  final Patient patient;
  final String? serviceNom;
  final String? medecinNom;
}

/// Critères de recherche multicritère des médecins.
class MedecinFiltre {
  const MedecinFiltre({this.texte = '', this.serviceId, this.disponible});

  final String texte;
  final int? serviceId;
  final bool? disponible;

  int get nbFiltresActifs =>
      (serviceId != null ? 1 : 0) + (disponible != null ? 1 : 0);

  MedecinFiltre avecTexte(String t) =>
      MedecinFiltre(texte: t, serviceId: serviceId, disponible: disponible);
}

/// Critères de recherche multicritère des patients.
class PatientFiltre {
  const PatientFiltre({
    this.texte = '',
    this.serviceId,
    this.groupeSanguin,
    this.sexe,
    this.nonAffectes = false,
  });

  final String texte;
  final int? serviceId;
  final String? groupeSanguin;
  final String? sexe;
  final bool nonAffectes;

  int get nbFiltresActifs =>
      (serviceId != null ? 1 : 0) +
      (groupeSanguin != null ? 1 : 0) +
      (sexe != null ? 1 : 0) +
      (nonAffectes ? 1 : 0);

  PatientFiltre avecTexte(String t) => PatientFiltre(
        texte: t,
        serviceId: serviceId,
        groupeSanguin: groupeSanguin,
        sexe: sexe,
        nonAffectes: nonAffectes,
      );
}
