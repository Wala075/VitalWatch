import 'package:sqflite/sqflite.dart';

import '../../../models/medecin.dart';
import '../../../models/patient.dart';
import '../../../models/utilisateur.dart';
import '../data/consultation_repository.dart';
import '../data/creneau_repository.dart';
import '../data/notification_repository.dart';
import '../data/personnes_repository.dart';
import '../data/rdv_repository.dart';
import '../data/rdv_schema.dart';
import '../services/visio_service.dart';
import 'rdv_models.dart';
import 'rdv_permissions.dart';
import 'rdv_regles.dart';

/// Règles métier du module Rendez-vous & Téléconsultation.
/// Les écrans n'appellent que cette classe (jamais SQL directement).
class RdvManager {
  RdvManager({
    RdvRepository? rdvs,
    CreneauRepository? creneaux,
    ConsultationRepository? consultations,
    PersonnesRepository? personnes,
    NotificationRepository? notifications,
    NotificationPatientRepository? notificationsPatient,
    DateTime Function()? horloge,
  })  : _rdvs = rdvs ?? RdvRepository(),
        _notifications = notifications ?? NotificationRepository(),
        _notificationsPatient =
            notificationsPatient ?? NotificationPatientRepository(),
        _creneaux = creneaux ?? CreneauRepository(),
        _consultations = consultations ?? ConsultationRepository(),
        _personnes = personnes ?? PersonnesRepository(),
        _horloge = horloge ?? DateTime.now;

  final RdvRepository _rdvs;
  final CreneauRepository _creneaux;
  final ConsultationRepository _consultations;
  final PersonnesRepository _personnes;
  final NotificationRepository _notifications;
  final NotificationPatientRepository _notificationsPatient;
  final DateTime Function() _horloge;

  DateTime get _maintenant => _horloge();

  // =====================================================================
  // Créneaux libres
  // =====================================================================

  /// Horaires libres du médecin pour ce jour (créneaux - RDV déjà pris).
  Future<List<DateTime>> horairesLibres(int medecinId, DateTime jour) async {
    final DateTime debut = DateTime(jour.year, jour.month, jour.day);
    final List<Creneau> creneaux = await _creneaux.parMedecin(medecinId);
    final List<RendezVous> occupes = await _rdvs.actifsMedecin(
      medecinId,
      debut,
      debut.add(const Duration(days: 1)),
    );
    return RdvRegles.horairesLibres(
      jour: debut,
      creneaux: creneaux,
      occupes: occupes,
      maintenant: _maintenant,
    );
  }

  /// Premier horaire libre du médecin à partir de [apres] (30 jours max).
  Future<DateTime?> prochainHoraireLibre(int medecinId, DateTime apres) async {
    final List<Creneau> creneaux = await _creneaux.parMedecin(medecinId);
    if (creneaux.isEmpty) {
      return null;
    }
    final DateTime premierJour = DateTime(apres.year, apres.month, apres.day);
    final List<RendezVous> occupes = await _rdvs.actifsMedecin(
      medecinId,
      premierJour,
      premierJour.add(const Duration(days: RdvRegles.horizonRechercheJours + 1)),
    );
    final DateTime limite = apres.isAfter(_maintenant) ? apres : _maintenant;
    for (int i = 0; i <= RdvRegles.horizonRechercheJours; i++) {
      final DateTime jour = premierJour.add(Duration(days: i));
      final List<DateTime> libres = RdvRegles.horairesLibres(
        jour: jour,
        creneaux: creneaux,
        occupes: occupes,
        maintenant: limite.subtract(const Duration(seconds: 1)),
      );
      if (libres.isNotEmpty) {
        return libres.first;
      }
    }
    return null;
  }

  // =====================================================================
  // Prise de rendez-vous
  // =====================================================================

  /// Contrôles : date future, motif, médecin disponible, horaire dans un
  /// créneau, pas de conflit (médecin ni patient). En cas de conflit, la
  /// [ConflitCreneauException] contient le prochain créneau libre.
  /// Priorité « haute » automatique si le patient a une alerte récente.
  Future<RendezVous> reserver({
    required int patientId,
    required int medecinId,
    required DateTime dateHeure,
    required TypeRdv type,
    required String motif,
    required Utilisateur auteur,
  }) async {
    if (auteur.role == Role.patient && auteur.refId != patientId) {
      throw const RdvException('Vous ne pouvez prendre RDV que pour vous-même');
    }
    if (!dateHeure.isAfter(_maintenant)) {
      throw const RdvException('La date du rendez-vous est déjà passée');
    }
    if (motif.trim().length < 3) {
      throw const RdvException('Indiquez le motif du rendez-vous');
    }
    final Medecin? medecin = await _personnes.medecin(medecinId);
    if (medecin == null) {
      throw const RdvException('Médecin introuvable');
    }
    if (!medecin.disponible) {
      throw RdvException('${medecin.nomComplet} n\'est pas disponible actuellement');
    }
    final Patient? patient = await _personnes.patient(patientId);
    if (patient == null) {
      throw const RdvException('Patient introuvable');
    }
    // Un médecin ne prend RDV que pour SES patients, et avec lui-même.
    if (auteur.role == Role.medecin) {
      if (medecinId != auteur.refId) {
        throw const RdvException('Vous ne pouvez prendre RDV que dans votre propre agenda');
      }
      if (patient.medecinId != auteur.refId) {
        throw const RdvException("Ce patient n'est pas affecté à vous");
      }
    }

    final List<Creneau> creneaux = await _creneaux.parMedecin(medecinId);
    final int duree = RdvRegles.dureePour(dateHeure, creneaux);
    if (RdvRegles.creneauContenant(dateHeure, duree, creneaux) == null) {
      final DateTime? prop = await prochainHoraireLibre(medecinId, dateHeure);
      throw ConflitCreneauException(
        '${medecin.nomComplet} ne consulte pas à cette heure',
        proposition: prop,
      );
    }

    final DateTime fin = dateHeure.add(Duration(minutes: duree));
    final List<RendezVous> occupesMedecin =
        await _rdvs.actifsMedecin(medecinId, dateHeure, fin);
    if (RdvRegles.conflit(dateHeure, duree, occupesMedecin) != null) {
      final DateTime? prop = await prochainHoraireLibre(medecinId, dateHeure);
      throw ConflitCreneauException(
        'Ce créneau est déjà pris',
        proposition: prop,
      );
    }
    final List<RendezVous> occupesPatient =
        await _rdvs.actifsPatient(patientId, dateHeure, fin);
    if (RdvRegles.conflit(dateHeure, duree, occupesPatient) != null) {
      throw const RdvException('Le patient a déjà un rendez-vous à cette heure');
    }

    final bool alerte = await _rdvs.alerteRecente(patientId);
    final RendezVous rdv = RendezVous(
      patientId: patientId,
      medecinId: medecinId,
      dateHeure: dateHeure,
      duree: duree,
      type: type,
      motif: motif.trim(),
      // Pris par le personnel : directement confirmé.
      statut: auteur.role == Role.patient ? StatutRdv.enAttente : StatutRdv.confirme,
      priorite: RdvRegles.prioriteInitiale(urgent: false, alerteRecente: alerte),
      lienVisio: type == TypeRdv.visio ? VisioService.nouveauLien() : null,
      creePar: auteur.id,
      dateCreation: _maintenant,
    );
    final int id = await _rdvs.inserer(rdv);
    // RDV pris par le personnel : le patient est prévenu dans son espace.
    if (auteur.role != Role.patient) {
      await _notificationsPatient.creer(
        rdvId: id,
        patientId: patientId,
        type: NotificationRepository.typeRdvCree,
      );
    }
    return rdv.copyWith(id: id);
  }

  /// Demande urgente (non vitale) : pas besoin de créneau réservé.
  /// - médecin : celui du patient s'il est disponible, sinon le moins chargé
  ///   aujourd'hui dans le service du patient, sinon dans tout l'hôpital ;
  /// - visio : maintenant ; présentiel : prochain horaire libre du jour,
  ///   sinon inséré tout de suite dans la file ;
  /// - priorité « urgente » : passe en tête de la file d'attente.
  Future<RdvDetail> demandeUrgente({
    required int patientId,
    required TypeRdv type,
    required String motif,
    required Utilisateur auteur,
  }) async {
    if (!auteur.role.demandeUrgente) {
      throw const RdvException("Vous n'avez pas le droit de créer une demande urgente");
    }
    if (auteur.role == Role.patient && auteur.refId != patientId) {
      throw const RdvException('Vous ne pouvez faire une demande que pour vous-même');
    }
    if (motif.trim().length < 3) {
      throw const RdvException('Décrivez brièvement le problème');
    }
    final Patient? patient = await _personnes.patient(patientId);
    if (patient == null) {
      throw const RdvException('Patient introuvable');
    }

    final Medecin medecin = await _choisirMedecinUrgence(patient);
    final DateTime maintenant = _maintenant;
    DateTime quand = RdvRegles.prochainesCinqMinutes(maintenant);
    if (type == TypeRdv.presentiel) {
      final List<DateTime> libres =
          await horairesLibres(medecin.id ?? 0, maintenant);
      if (libres.isNotEmpty) {
        quand = libres.first;
      }
    }

    final RendezVous rdv = RendezVous(
      patientId: patientId,
      medecinId: medecin.id ?? 0,
      dateHeure: quand,
      duree: type == TypeRdv.visio ? 15 : 30,
      type: type,
      motif: motif.trim(),
      statut: StatutRdv.confirme,
      priorite: PrioriteRdv.urgente,
      lienVisio: type == TypeRdv.visio ? VisioService.nouveauLien() : null,
      creePar: auteur.id,
      dateCreation: maintenant,
    );
    final int id = await _rdvs.inserer(rdv);
    // Le médecin reçoit une notification « appel urgent » (sonnerie in-app).
    await _notifications.creer(
      rdvId: id,
      medecinId: medecin.id ?? 0,
      type: NotificationRepository.typeAppelUrgent,
    );
    final RdvDetail? d = await _rdvs.detail(id);
    if (d == null) {
      throw const RdvException('Erreur lors de la création de la demande');
    }
    return d;
  }

  // =====================================================================
  // Notifications du médecin
  // =====================================================================

  /// Nouveaux RDV pris POUR le patient connecté par le personnel
  /// (marqués lus dès qu'ils sont renvoyés : affichés une seule fois).
  Future<List<RdvDetail>> nouveauxRdvPourPatient(Utilisateur u) async {
    final int? pid = u.refId;
    if (u.role != Role.patient || pid == null) {
      return [];
    }
    final List<NotificationRdv> notifs = await _notificationsPatient.nonLues(pid);
    final List<RdvDetail> res = [];
    for (final NotificationRdv n in notifs) {
      await _notificationsPatient.marquerLue(n.id);
      final RdvDetail? d = await _rdvs.detail(n.rdvId);
      if (d != null) {
        res.add(d);
      }
    }
    return res;
  }

  /// Appels urgents pas encore vus par le médecin connecté.
  Future<List<RdvDetail>> appelsUrgentsEnAttente(Utilisateur u) async {
    final int? mid = u.refId;
    if (u.role != Role.medecin || mid == null) {
      return [];
    }
    final List<NotificationRdv> notifs = await _notifications.nonLues(mid);
    final List<RdvDetail> res = [];
    for (final NotificationRdv n in notifs) {
      // Lue dès qu'elle est affichée : elle ne sonne qu'une fois.
      await _notifications.marquerLue(n.id);
      final RdvDetail? d = await _rdvs.detail(n.rdvId);
      if (d != null) {
        res.add(d);
      }
    }
    return res;
  }

  Future<Medecin> _choisirMedecinUrgence(Patient patient) async {
    final List<Medecin> dispo =
        await _personnes.medecins(disponiblesSeulement: true);
    if (dispo.isEmpty) {
      throw const RdvException('Aucun médecin disponible pour le moment');
    }
    for (final Medecin m in dispo) {
      if (m.id != null && m.id == patient.medecinId) {
        return m;
      }
    }
    final List<Medecin> duService = [
      for (final Medecin m in dispo)
        if (patient.serviceId != null && m.serviceId == patient.serviceId) m,
    ];
    final List<Medecin> candidats = duService.isNotEmpty ? duService : dispo;

    Medecin choisi = candidats.first;
    int chargeMin = 1 << 30;
    for (final Medecin m in candidats) {
      final int charge = await _rdvs.chargeDuJour(m.id ?? 0, _maintenant);
      if (charge < chargeMin) {
        chargeMin = charge;
        choisi = m;
      }
    }
    return choisi;
  }

  // =====================================================================
  // Cycle de vie du RDV
  // =====================================================================

  Future<RdvDetail> _charger(int id) async {
    final RdvDetail? d = await _rdvs.detail(id);
    if (d == null) {
      throw const RdvException('Rendez-vous introuvable');
    }
    return d;
  }

  void _verifierAcces(RdvDetail d, Utilisateur u) {
    final RendezVous r = d.rdv;
    final bool ok = u.role.voirTousLesRdv ||
        (u.role == Role.medecin && u.refId == r.medecinId) ||
        (u.role == Role.patient && u.refId == r.patientId);
    if (!ok) {
      throw const RdvException("Ce rendez-vous ne vous concerne pas");
    }
  }

  Future<void> confirmer(int id, Utilisateur u) async {
    final RdvDetail d = await _charger(id);
    _verifierAcces(d, u);
    if (!u.role.gererStatutRdv) {
      throw const RdvException('Action réservée au personnel');
    }
    if (d.rdv.statut != StatutRdv.enAttente) {
      throw const RdvException('Seul un RDV en attente peut être confirmé');
    }
    await _rdvs.changerStatut(id, StatutRdv.confirme);
  }

  /// Annulation. Le patient doit annuler au moins 2 h avant.
  Future<void> annuler(int id, Utilisateur u, {String? motif}) async {
    final RdvDetail d = await _charger(id);
    _verifierAcces(d, u);
    final RendezVous r = d.rdv;
    if (!r.statut.estActif || r.statut == StatutRdv.enCours) {
      throw const RdvException('Ce rendez-vous ne peut plus être annulé');
    }
    if (!u.role.annulerSansDelai &&
        !RdvRegles.patientPeutAnnuler(r, _maintenant)) {
      throw const RdvException(
        'Annulation impossible moins de 2 h avant le rendez-vous. '
        'Contactez le service.',
      );
    }
    await _rdvs.changerStatut(
      id,
      StatutRdv.annule,
      motifAnnulation: (motif == null || motif.trim().isEmpty)
          ? 'Annulé par ${u.role.name}'
          : motif.trim(),
    );
  }

  Future<void> marquerAbsent(int id, Utilisateur u) async {
    final RdvDetail d = await _charger(id);
    _verifierAcces(d, u);
    if (!u.role.gererStatutRdv) {
      throw const RdvException('Action réservée au personnel');
    }
    if (!RdvRegles.peutMarquerAbsent(d.rdv, _maintenant)) {
      throw const RdvException(
        'Possible seulement 15 min après l\'heure du rendez-vous',
      );
    }
    await _rdvs.changerStatut(id, StatutRdv.absent);
  }

  /// Le médecin commence la consultation : statut « en cours » + heure de début.
  Future<void> demarrer(int id, Utilisateur u) async {
    final RdvDetail d = await _charger(id);
    if (u.role != Role.medecin || u.refId != d.rdv.medecinId) {
      throw const RdvException('Seul le médecin du RDV peut démarrer la consultation');
    }
    final StatutRdv s = d.rdv.statut;
    if (s != StatutRdv.confirme && s != StatutRdv.enAttente) {
      throw const RdvException('Ce rendez-vous ne peut pas être démarré');
    }
    final Database db = await RdvSchema.db;
    await db.transaction((Transaction txn) async {
      await _rdvs.changerStatut(id, StatutRdv.enCours, exec: txn);
      await _consultations.enregistrer(
        Consultation(rdvId: id, diagnostic: '', compteRendu: '', debut: _maintenant),
        exec: txn,
      );
    });
  }

  /// Enregistre le compte-rendu. Si [terminer] : RDV « terminé » + durée réelle.
  Future<Consultation> enregistrerConsultation({
    required int rdvId,
    required String diagnostic,
    required String compteRendu,
    String? resumeIa,
    required bool terminer,
    required Utilisateur u,
  }) async {
    final RdvDetail d = await _charger(rdvId);
    if (u.role != Role.medecin || u.refId != d.rdv.medecinId) {
      throw const RdvException('Seul le médecin du RDV peut rédiger la consultation');
    }
    if (terminer && diagnostic.trim().isEmpty) {
      throw const RdvException('Le diagnostic est obligatoire pour terminer');
    }
    if (terminer && compteRendu.trim().length < 10) {
      throw const RdvException('Le compte-rendu est trop court');
    }
    final Consultation? existante = await _consultations.parRdv(rdvId);
    final DateTime debut = existante?.debut ?? d.rdv.dateHeure;
    final DateTime? fin = terminer ? _maintenant : existante?.fin;
    int? dureeReelle = existante?.dureeReelle;
    if (fin != null) {
      final int m = fin.difference(debut).inMinutes;
      dureeReelle = m < 1 ? 1 : m;
    }
    final Consultation c = Consultation(
      rdvId: rdvId,
      diagnostic: diagnostic.trim(),
      compteRendu: compteRendu.trim(),
      resumeIa: resumeIa ?? existante?.resumeIa,
      debut: debut,
      fin: fin,
      dureeReelle: dureeReelle,
    );

    final Database db = await RdvSchema.db;
    await db.transaction((Transaction txn) async {
      await _consultations.enregistrer(c, exec: txn);
      if (terminer) {
        await _rdvs.changerStatut(rdvId, StatutRdv.termine, exec: txn);
      } else if (d.rdv.statut != StatutRdv.enCours &&
          d.rdv.statut != StatutRdv.termine) {
        await _rdvs.changerStatut(rdvId, StatutRdv.enCours, exec: txn);
      }
    });
    return c;
  }

  Future<Consultation?> consultation(int rdvId) => _consultations.parRdv(rdvId);

  /// Lien de visio du RDV (créé s'il manque).
  Future<String> lienVisio(RdvDetail d) async {
    final String? lien = d.rdv.lienVisio;
    if (lien != null && lien.isNotEmpty) {
      return lien;
    }
    final String nouveau = VisioService.nouveauLien();
    await _rdvs.definirLienVisio(d.rdv.id ?? 0, nouveau);
    return nouveau;
  }

  // =====================================================================
  // Listes, file d'attente, rappels
  // =====================================================================

  /// RDV visibles par l'utilisateur (le patient et le médecin ne voient que les leurs).
  Future<List<RdvDetail>> mesRdv(
    Utilisateur u, {
    RdvFiltre filtre = const RdvFiltre(),
    bool recentsDabord = false,
  }) {
    RdvFiltre f = filtre;
    if (u.role == Role.patient) {
      f = RdvFiltre(
        texte: filtre.texte,
        patientId: u.refId ?? -1,
        statut: filtre.statut,
        type: filtre.type,
        jour: filtre.jour,
      );
    } else if (u.role == Role.medecin) {
      f = RdvFiltre(
        texte: filtre.texte,
        medecinId: u.refId ?? -1,
        patientId: filtre.patientId,
        statut: filtre.statut,
        type: filtre.type,
        jour: filtre.jour,
      );
    }
    return _rdvs.rechercher(f, recentsDabord: recentsDabord);
  }

  /// File d'attente du jour, triée par priorité puis par heure.
  Future<List<RdvDetail>> fileAttente(Utilisateur u, {int? medecinId}) async {
    final List<RdvDetail> jour = await mesRdv(
      u,
      filtre: RdvFiltre(jour: _maintenant, medecinId: medecinId),
    );
    final List<RdvDetail> actifs = [
      for (final RdvDetail d in jour)
        if (d.rdv.statut.estActif) d,
    ];
    return RdvRegles.trierFile(actifs);
  }

  /// Rappels J-1 et H-1 des RDV à venir de l'utilisateur.
  Future<List<Rappel>> rappels(Utilisateur u) async {
    if (u.role != Role.patient && u.role != Role.medecin) {
      return [];
    }
    final List<RdvDetail> liste = await mesRdv(u);
    final DateTime n = _maintenant;
    final List<Rappel> res = [];
    for (final RdvDetail d in liste) {
      final String? libelle = RdvRegles.rappelPour(d.rdv, n);
      if (libelle != null) {
        res.add(Rappel(detail: d, libelle: libelle));
      }
    }
    return res;
  }

  // =====================================================================
  // Créneaux
  // =====================================================================

  Future<List<Creneau>> creneaux(int medecinId) => _creneaux.parMedecin(medecinId);

  void _verifierCreneaux(int medecinId, Utilisateur u) {
    final bool ok = u.role.gererTousLesCreneaux ||
        (u.role.gererSesCreneaux && u.refId == medecinId);
    if (!ok) {
      throw const RdvException('Vous ne pouvez pas modifier ces créneaux');
    }
  }

  Future<void> enregistrerCreneau(Creneau c, Utilisateur u) async {
    _verifierCreneaux(c.medecinId, u);
    final String? erreur = RdvRegles.validerCreneau(c);
    if (erreur != null) {
      throw RdvException(erreur);
    }
    final List<Creneau> existants = await _creneaux.parMedecin(c.medecinId);
    for (final Creneau e in existants) {
      if (e.id != c.id && RdvRegles.creneauxSeChevauchent(c, e)) {
        throw RdvException(
          'Chevauche le créneau ${RdvFormat.minutes(e.heureDebut)}'
          '-${RdvFormat.minutes(e.heureFin)}',
        );
      }
    }
    if (c.id == null) {
      await _creneaux.inserer(c);
    } else {
      await _creneaux.modifier(c);
    }
  }

  Future<void> supprimerCreneau(Creneau c, Utilisateur u) async {
    _verifierCreneaux(c.medecinId, u);
    final int? id = c.id;
    if (id != null) {
      await _creneaux.supprimer(id);
    }
  }

  // =====================================================================
  // Statistiques
  // =====================================================================

  /// Absentéisme, charge et durée réelle moyenne par médecin.
  Future<StatsRdv> statistiques(Utilisateur u) async {
    if (!u.role.voirStatsRdv) {
      throw const RdvException('Statistiques réservées');
    }
    final int? filtre = u.role == Role.medecin ? (u.refId ?? -1) : null;
    final List<Map<String, Object?>> lignes =
        await _rdvs.lignesStats(medecinId: filtre);

    final DateTime n = _maintenant;
    final DateTime lundi = RdvRegles.debutSemaine(n);
    final DateTime lundiSuivant = lundi.add(const Duration(days: 7));

    final Map<int, _Cumul> cumul = {};
    for (final Map<String, Object?> l in lignes) {
      final int mid = l['medecin_id'] as int;
      final _Cumul c = cumul.putIfAbsent(
        mid,
        () => _Cumul('Dr ${l['prenom']} ${l['nom']}'),
      );
      final Object? statutBrut = l['statut'];
      if (statutBrut == null) {
        continue; // médecin sans aucun RDV
      }
      final DateTime date = DateTime.parse(l['date_heure'] as String);
      c.total++;
      switch (statutBrut) {
        case 'termine':
          c.termines++;
          final int? d = l['duree_reelle'] as int?;
          if (d != null) {
            c.sommeDuree += d;
            c.nbDuree++;
          }
        case 'absent':
          c.absents++;
        case 'annule':
          c.annules++;
        default:
          if (date.isAfter(n)) {
            c.aVenir++;
          }
      }
      if (statutBrut != 'annule' &&
          !date.isBefore(lundi) &&
          date.isBefore(lundiSuivant)) {
        c.semaine++;
      }
    }

    final List<StatsMedecin> res = [];
    cumul.forEach((int id, _Cumul c) {
      res.add(StatsMedecin(
        medecinId: id,
        medecinNom: c.nom,
        total: c.total,
        termines: c.termines,
        absents: c.absents,
        annules: c.annules,
        aVenir: c.aVenir,
        cetteSemaine: c.semaine,
        dureeMoyenne: c.nbDuree == 0 ? null : c.sommeDuree / c.nbDuree,
      ));
    });
    res.sort((StatsMedecin a, StatsMedecin b) => b.total.compareTo(a.total));
    return StatsRdv(parMedecin: res);
  }

  // Accès en lecture aux personnes (pour les formulaires).
  Future<List<Medecin>> medecins({bool disponiblesSeulement = false}) =>
      _personnes.medecins(disponiblesSeulement: disponiblesSeulement);

  /// Patients proposés dans les formulaires : un médecin ne voit que les siens.
  Future<List<Patient>> patients(Utilisateur u, {String texte = ''}) =>
      _personnes.patients(
        texte: texte,
        medecinId: u.role == Role.medecin ? (u.refId ?? -1) : null,
      );

  Future<Patient?> patient(int id) => _personnes.patient(id);

  Future<RdvDetail?> detail(int id) => _rdvs.detail(id);
}

class _Cumul {
  _Cumul(this.nom);

  final String nom;
  int total = 0;
  int termines = 0;
  int absents = 0;
  int annules = 0;
  int aVenir = 0;
  int semaine = 0;
  int sommeDuree = 0;
  int nbDuree = 0;
}
