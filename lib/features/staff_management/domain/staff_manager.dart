import 'package:sqflite/sqflite.dart';

import '../../../core/services/app_database.dart';
import '../../../core/services/email_service.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/medecin.dart';
import '../../../models/patient.dart';
import '../../../models/service.dart';
import '../../../models/utilisateur.dart';
import '../data/compte_repository.dart';
import '../data/medecin_repository.dart';
import '../data/patient_repository.dart';
import '../data/service_repository.dart';
import 'staff_models.dart';

/// Règles métier du module Services & Personnel.
class StaffManager {
  StaffManager({
    ServiceRepository? services,
    MedecinRepository? medecins,
    PatientRepository? patients,
    CompteRepository? comptes,
    EmailService? email,
  })  : _services = services ?? ServiceRepository(),
        _medecins = medecins ?? MedecinRepository(),
        _patients = patients ?? PatientRepository(),
        _comptes = comptes ?? CompteRepository(),
        _email = email ?? EmailService();

  final ServiceRepository _services;
  final MedecinRepository _medecins;
  final PatientRepository _patients;
  final CompteRepository _comptes;
  final EmailService _email;

  Future<Database> get _db => AppDatabase.instance.database;

  // =====================================================================
  // Services
  // =====================================================================

  Future<int> enregistrerService(Service s) async {
    if (await _services.nomExiste(s.nom, exclureId: s.id)) {
      throw StaffException('Le service « ${s.nom} » existe déjà');
    }
    if (s.capacite < 1) {
      throw const StaffException('La capacité doit être au moins 1');
    }

    final int? id = s.id;
    if (id == null) {
      return _services.inserer(s);
    }

    final int nbPatients = await _patients.compterParService(id);
    if (s.capacite < nbPatients) {
      throw StaffException(
        'Capacité insuffisante : $nbPatients patients sont déjà dans ce service',
      );
    }
    final int? chefId = s.chefServiceId;
    if (chefId != null) {
      final Medecin? chef = await _medecins.parId(chefId);
      if (chef == null || chef.serviceId != id) {
        throw const StaffException(
          'Le chef de service doit être un médecin de ce service',
        );
      }
    }
    await _services.modifier(s);
    return id;
  }

  /// Les médecins et patients du service sont désaffectés (ON DELETE SET NULL).
  Future<void> supprimerService(int id) => _services.supprimer(id);

  // =====================================================================
  // Médecins
  // =====================================================================

  /// Ajout : crée aussi le compte (mot de passe temporaire haché).
  /// Modification : met à jour le compte ; si le médecin change de service,
  /// ses patients sont réaffectés automatiquement.
  Future<ResultatEnregistrement> enregistrerMedecin(Medecin m) async {
    if (await _medecins.matriculeExiste(m.matricule, exclureId: m.id)) {
      throw StaffException('Le matricule ${m.matricule} est déjà utilisé');
    }
    if (await _comptes.emailExiste(m.email, role: Role.medecin, refId: m.id)) {
      throw StaffException("L'email ${m.email} est déjà utilisé");
    }

    final Database db = await _db;
    final int? id = m.id;

    if (id == null) {
      final ResultatEnregistrement cree =
          await db.transaction((Transaction txn) async {
        final int nouveauId = await _medecins.inserer(m, exec: txn);
        final CompteCree compte = await _comptes.creer(
          email: m.email,
          role: Role.medecin,
          refId: nouveauId,
          nom: m.nom,
          prenom: m.prenom,
          exec: txn,
        );
        return ResultatEnregistrement(id: nouveauId, compte: compte);
      });
      return _envoyerIdentifiants(cree);
    }

    final Medecin? ancien = await _medecins.parId(id);
    final bool changeService = ancien != null && ancien.serviceId != m.serviceId;

    await db.transaction((Transaction txn) async {
      await _medecins.modifier(m, exec: txn);
      await _comptes.mettreAJour(
        role: Role.medecin,
        refId: id,
        email: m.email,
        nom: m.nom,
        prenom: m.prenom,
        exec: txn,
      );
      if (changeService) {
        await _services.retirerChef(id, exec: txn);
      }
    });

    if (!changeService) {
      return ResultatEnregistrement(id: id);
    }
    final int n = await _reaffecterPatientsDe(id);
    return ResultatEnregistrement(
      id: id,
      message: n == 0 ? null : '$n patient(s) réaffecté(s) automatiquement',
    );
  }

  /// Supprime le médecin et son compte ; ses patients sont réaffectés
  /// au médecin le moins chargé de leur service. Renvoie le nombre réaffecté.
  Future<int> supprimerMedecin(int id) async {
    final int n = await _reaffecterPatientsDe(id);
    final Database db = await _db;
    await db.transaction((Transaction txn) async {
      await _services.retirerChef(id, exec: txn);
      await _comptes.supprimer(role: Role.medecin, refId: id, exec: txn);
      await _medecins.supprimer(id, exec: txn);
    });
    return n;
  }

  Future<int> _reaffecterPatientsDe(int medecinId) async {
    final List<Patient> patients = await _patients.parMedecin(medecinId);
    int n = 0;
    for (final Patient p in patients) {
      final int? patientId = p.id;
      if (patientId == null) {
        continue;
      }
      final int? serviceId = p.serviceId;
      int? nouveau;
      if (serviceId != null) {
        nouveau = await _medecins.moinsCharge(serviceId, exclureId: medecinId);
      }
      await _patients.affecterMedecin(patientId, nouveau);
      if (nouveau != null) {
        n++;
      }
    }
    return n;
  }

  // =====================================================================
  // Patients
  // =====================================================================

  /// Contrôles : CIN unique, doublon nom + date de naissance (confirmable),
  /// email unique, capacité du service, médecin du bon service.
  /// Affectation automatique au médecin le moins chargé si aucun choisi.
  /// Compte patient créé si un email est renseigné.
  Future<ResultatEnregistrement> enregistrerPatient(
    Patient patient, {
    bool ignorerDoublon = false,
  }) async {
    final int? id = patient.id;

    if (await _patients.cinExiste(patient.cin, exclureId: id)) {
      throw StaffException('Un patient avec la CIN ${patient.cin} existe déjà');
    }
    if (!ignorerDoublon) {
      final Patient? doublon = await _patients.doublonNomDate(
        patient.nom,
        Formatters.dateIso(patient.dateNaissance),
        exclureId: id,
      );
      if (doublon != null) {
        throw DoublonPatientException(doublon);
      }
    }
    final String? email = patient.email;
    if (email != null &&
        await _comptes.emailExiste(email, role: Role.patient, refId: id)) {
      throw StaffException("L'email $email est déjà utilisé");
    }

    Patient aEnregistrer = patient;
    String? message;
    final int? serviceId = patient.serviceId;

    if (serviceId != null) {
      final Service? service = await _services.parId(serviceId);
      final int occupes =
          await _patients.compterParService(serviceId, exclureId: id);
      if (service != null && service.capacite > 0 && occupes >= service.capacite) {
        throw StaffException(
          'Le service ${service.nom} est complet (${service.capacite} places)',
        );
      }

      final int? medecinId = patient.medecinId;
      if (medecinId == null) {
        final int? choisi = await _medecins.moinsCharge(serviceId);
        if (choisi == null) {
          message = 'Aucun médecin disponible dans ce service : patient non affecté';
        } else {
          aEnregistrer = patient.copyWith(medecinId: choisi);
          final Medecin? m = await _medecins.parId(choisi);
          message = 'Affecté automatiquement à ${m?.nomComplet ?? 'un médecin'}';
        }
      } else {
        final Medecin? m = await _medecins.parId(medecinId);
        if (m == null || m.serviceId != serviceId) {
          throw const StaffException(
            "Le médecin choisi n'appartient pas à ce service",
          );
        }
      }
    }

    final Database db = await _db;
    final String? messageFinal = message;
    final ResultatEnregistrement res =
        await db.transaction((Transaction txn) async {
      final int patientId;
      if (id == null) {
        patientId = await _patients.inserer(aEnregistrer, exec: txn);
      } else {
        patientId = id;
        await _patients.modifier(aEnregistrer, exec: txn);
      }

      CompteCree? compte;
      final bool aCompte =
          await _comptes.existe(role: Role.patient, refId: patientId, exec: txn);
      if (email != null) {
        if (aCompte) {
          await _comptes.mettreAJour(
            role: Role.patient,
            refId: patientId,
            email: email,
            nom: patient.nom,
            prenom: patient.prenom,
            exec: txn,
          );
        } else {
          compte = await _comptes.creer(
            email: email,
            role: Role.patient,
            refId: patientId,
            nom: patient.nom,
            prenom: patient.prenom,
            exec: txn,
          );
        }
      } else if (aCompte) {
        await _comptes.supprimer(role: Role.patient, refId: patientId, exec: txn);
      }

      return ResultatEnregistrement(
        id: patientId,
        compte: compte,
        message: messageFinal,
      );
    });
    return _envoyerIdentifiants(res);
  }

  /// Envoi automatique des identifiants par mail (après enregistrement en base).
  Future<ResultatEnregistrement> _envoyerIdentifiants(
    ResultatEnregistrement r,
  ) async {
    final CompteCree? c = r.compte;
    if (c == null) {
      return r;
    }
    final EnvoiEmail envoi = await _email.envoyerIdentifiants(
      email: c.email,
      nom: c.nom,
      role: c.role,
      motDePasse: c.motDePasseTemporaire,
    );
    return ResultatEnregistrement(
      id: r.id,
      compte: c,
      message: r.message,
      envoi: envoi,
    );
  }

  Future<void> supprimerPatient(int id) async {
    final Database db = await _db;
    await db.transaction((Transaction txn) async {
      await _comptes.supprimer(role: Role.patient, refId: id, exec: txn);
      await _patients.supprimer(id, exec: txn);
    });
  }
}
