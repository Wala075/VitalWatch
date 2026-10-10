import 'package:sqflite/sqflite.dart';

import '../../../core/services/app_database.dart';
import '../../../core/services/email_service.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/validators.dart';
import '../../../models/ambulancier.dart';
import '../../../models/infirmier.dart';
import '../../../models/medecin.dart';
import '../../../models/patient.dart';
import '../../../models/pharmacien.dart';
import '../../../models/service.dart';
import '../../../models/utilisateur.dart';
import '../data/ambulancier_repository.dart';
import '../data/compte_repository.dart';
import '../data/horaire_repository.dart';
import '../data/infirmier_repository.dart';
import '../data/medecin_repository.dart';
import '../data/patient_repository.dart';
import '../data/pharmacien_repository.dart';
import '../data/service_repository.dart';
import 'disponibilite.dart';
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
  final HoraireRepository _horaires = HoraireRepository();
  final InfirmierRepository _infirmiers = InfirmierRepository();
  final AmbulancierRepository _ambulanciers = AmbulancierRepository();
  final PharmacienRepository _pharmaciens = PharmacienRepository();

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
        await _horaires.parDefaut(nouveauId, exec: txn);
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

  /// Horaires de consultation : créneaux valides (début < fin),
  /// sans chevauchement dans une même journée.
  Future<void> enregistrerHoraires(int medecinId, List<Creneau> creneaux) async {
    for (final Creneau c in creneaux) {
      if (c.jour < 1 || c.jour > 7) {
        throw const StaffException('Jour invalide');
      }
      if (c.debut < 0 || c.fin > 24 * 60 || c.debut >= c.fin) {
        throw StaffException(
          "${Horaire.jours[c.jour - 1]} : l'heure de fin doit être après l'heure de début",
        );
      }
    }
    for (int j = 1; j <= 7; j++) {
      final List<Creneau> jour = [
        for (final Creneau c in creneaux)
          if (c.jour == j) c,
      ]..sort((a, b) => a.debut.compareTo(b.debut));
      for (int i = 1; i < jour.length; i++) {
        if (jour[i].debut < jour[i - 1].fin) {
          throw StaffException('${Horaire.jours[j - 1]} : deux créneaux se chevauchent');
        }
      }
    }
    final Database db = await _db;
    await db.transaction(
      (Transaction txn) => _horaires.remplacer(medecinId, creneaux, exec: txn),
    );
  }

  /// Congé (false) / retour (true) : un médecin en congé ne reçoit plus
  /// de nouveaux patients (affectation automatique).
  Future<void> changerDisponibilite(int medecinId, bool disponible) {
    return _medecins.changerDisponibilite(medecinId, disponible);
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

  // =====================================================================
  // Infirmiers
  // =====================================================================

  /// Ajout : crée aussi le compte et envoie les identifiants par mail.
  /// Modification : met à jour le compte (ou le crée s'il manquait).
  Future<ResultatEnregistrement> enregistrerInfirmier(Infirmier i) async {
    final int? id = i.id;
    if (await _infirmiers.matriculeExiste(i.matricule, exclureId: id)) {
      throw StaffException('Le matricule ${i.matricule} est déjà utilisé');
    }
    if (await _infirmiers.emailExiste(i.email, exclureId: id) ||
        await _comptes.emailExiste(i.email, role: Role.infirmier, refId: id)) {
      throw StaffException("L'email ${i.email} est déjà utilisé");
    }

    final Database db = await _db;
    final ResultatEnregistrement res =
        await db.transaction((Transaction txn) async {
      final int infirmierId;
      if (id == null) {
        infirmierId = await _infirmiers.inserer(i, exec: txn);
      } else {
        infirmierId = id;
        await _infirmiers.modifier(i, exec: txn);
      }
      final CompteCree? compte = await _compteDuPersonnel(
        role: Role.infirmier,
        refId: infirmierId,
        email: i.email,
        nom: i.nom,
        prenom: i.prenom,
        exec: txn,
      );
      return ResultatEnregistrement(id: infirmierId, compte: compte);
    });
    return _envoyerIdentifiants(res);
  }

  Future<void> supprimerInfirmier(int id) async {
    final Database db = await _db;
    await db.transaction((Transaction txn) async {
      await _comptes.supprimer(role: Role.infirmier, refId: id, exec: txn);
      await _infirmiers.supprimer(id, exec: txn);
    });
  }

  // =====================================================================
  // Ambulanciers (table partagée avec le module 3, qui fait l'affectation)
  // =====================================================================

  /// Contrôles : nom (3 caractères min.), téléphone valide et unique,
  /// email unique. Crée ou met à jour le compte de connexion.
  Future<ResultatEnregistrement> enregistrerAmbulancier(
    Ambulancier a,
    String email,
  ) async {
    final String nom = a.nom.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (nom.length < 3) {
      throw const StaffException('Le nom doit contenir au moins 3 caractères');
    }
    final String? erreurTel = Validators.telephone(a.telephone);
    if (erreurTel != null) {
      throw StaffException(erreurTel);
    }
    final String tel = Validators.normaliserTelephone(a.telephone);
    final int? id = a.id;
    if (await _ambulanciers.telephoneExiste(tel, exclureId: id)) {
      throw const StaffException('Ce numéro est déjà attribué à un ambulancier');
    }
    final String mail = email.trim().toLowerCase();
    if (await _comptes.emailExiste(mail, role: Role.ambulancier, refId: id)) {
      throw StaffException("L'email $mail est déjà utilisé");
    }

    final Ambulancier propre = Ambulancier(
      id: id,
      nom: nom,
      role: a.role,
      telephone: tel,
      disponible: a.disponible,
      ambulanceId: a.ambulanceId,
    );
    final ({String prenom, String nom}) pn = propre.prenomNom;

    final Database db = await _db;
    final ResultatEnregistrement res =
        await db.transaction((Transaction txn) async {
      final int ambulancierId;
      if (id == null) {
        ambulancierId = await _ambulanciers.inserer(propre, exec: txn);
      } else {
        ambulancierId = id;
        await _ambulanciers.modifier(propre, exec: txn);
      }
      final CompteCree? compte = await _compteDuPersonnel(
        role: Role.ambulancier,
        refId: ambulancierId,
        email: mail,
        nom: pn.nom,
        prenom: pn.prenom,
        exec: txn,
      );
      return ResultatEnregistrement(id: ambulancierId, compte: compte);
    });
    return _envoyerIdentifiants(res);
  }

  /// Refusé si l'ambulancier fait partie d'un équipage : il faut d'abord
  /// le retirer de son ambulance (module Ambulances).
  Future<void> supprimerAmbulancier(int id) async {
    final AmbulancierCompte? fiche = await _ambulanciers.parId(id);
    if (fiche == null) return;
    if (fiche.ambulancier.ambulanceId != null) {
      throw const StaffException(
        "Cet ambulancier fait partie d'un équipage : retirez-le d'abord de "
        'son ambulance (module Ambulances)',
      );
    }
    final Database db = await _db;
    await db.transaction((Transaction txn) async {
      await _comptes.supprimer(role: Role.ambulancier, refId: id, exec: txn);
      await _ambulanciers.supprimer(id, exec: txn);
    });
  }

  // =====================================================================
  // Pharmaciens (la délivrance des ordonnances est dans le module 5)
  // =====================================================================

  /// Ajout : crée aussi le compte et envoie les identifiants par mail.
  /// Modification : met à jour le compte (ou le crée s'il manquait).
  Future<ResultatEnregistrement> enregistrerPharmacien(Pharmacien p) async {
    final int? id = p.id;
    if (await _pharmaciens.matriculeExiste(p.matricule, exclureId: id)) {
      throw StaffException('Le matricule ${p.matricule} est déjà utilisé');
    }
    if (await _pharmaciens.emailExiste(p.email, exclureId: id) ||
        await _comptes.emailExiste(p.email, role: Role.pharmacien, refId: id)) {
      throw StaffException("L'email ${p.email} est déjà utilisé");
    }

    final Database db = await _db;
    final ResultatEnregistrement res =
        await db.transaction((Transaction txn) async {
      final int pharmacienId;
      if (id == null) {
        pharmacienId = await _pharmaciens.inserer(p, exec: txn);
      } else {
        pharmacienId = id;
        await _pharmaciens.modifier(p, exec: txn);
      }
      final CompteCree? compte = await _compteDuPersonnel(
        role: Role.pharmacien,
        refId: pharmacienId,
        email: p.email,
        nom: p.nom,
        prenom: p.prenom,
        exec: txn,
      );
      return ResultatEnregistrement(id: pharmacienId, compte: compte);
    });
    return _envoyerIdentifiants(res);
  }

  Future<void> supprimerPharmacien(int id) async {
    final Database db = await _db;
    await db.transaction((Transaction txn) async {
      await _comptes.supprimer(role: Role.pharmacien, refId: id, exec: txn);
      await _pharmaciens.supprimer(id, exec: txn);
    });
  }

  /// Crée le compte s'il n'existe pas encore (renvoyé pour l'envoi du mail),
  /// sinon met à jour son email et son nom (renvoie null).
  Future<CompteCree?> _compteDuPersonnel({
    required Role role,
    required int refId,
    required String email,
    required String nom,
    required String prenom,
    required DatabaseExecutor exec,
  }) async {
    if (await _comptes.existe(role: role, refId: refId, exec: exec)) {
      await _comptes.mettreAJour(
        role: role,
        refId: refId,
        email: email,
        nom: nom,
        prenom: prenom,
        exec: exec,
      );
      return null;
    }
    return _comptes.creer(
      email: email,
      role: role,
      refId: refId,
      nom: nom,
      prenom: prenom,
      exec: exec,
    );
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
