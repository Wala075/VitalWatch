import 'package:latlong2/latlong.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/utils/validators.dart';
import '../data/ambulance_repository.dart';
import '../data/ambulance_schema.dart';
import '../data/ambulancier_repository.dart';
import '../data/api/nominatim_api.dart';
import '../data/intervention_repository.dart';
import '../data/maintenance_repository.dart';
import 'dispatch_models.dart';
import 'haversine.dart';
import 'hopitaux.dart';
import 'models/ambulance.dart';
import 'models/ambulancier.dart';
import 'models/intervention.dart';
import 'models/maintenance.dart';

/// Règles métier du module Ambulances & Interventions.
///
/// - Dispatch automatique : ambulance disponible la plus proche (Haversine),
///   pondérée par l'adéquation type d'ambulance / gravité.
/// - Réquisition : une urgence critique sans ambulance libre récupère
///   l'ambulance d'une mission modérée/faible pas encore sur place.
/// - File d'attente par gravité, traitée dès qu'une ambulance se libère.
/// - Maintenance préventive : blocage / déblocage automatique.
class DispatchManager {
  DispatchManager({
    AmbulanceRepository? ambulances,
    AmbulancierRepository? equipiers,
    InterventionRepository? interventions,
    MaintenanceRepository? maintenances,
    NominatimApi? nominatim,
  })  : _ambulances = ambulances ?? AmbulanceRepository(),
        _equipiers = equipiers ?? AmbulancierRepository(),
        _interventions = interventions ?? InterventionRepository(),
        _maintenances = maintenances ?? MaintenanceRepository(),
        _nominatim = nominatim ?? NominatimApi();

  final AmbulanceRepository _ambulances;
  final AmbulancierRepository _equipiers;
  final InterventionRepository _interventions;
  final MaintenanceRepository _maintenances;
  final NominatimApi _nominatim;

  /// Zone couverte : 90 km autour de Sousse.
  static final LatLng centreZone = LatLng(35.80, 10.66);
  static const double rayonZoneKm = 90;
  static const int maxEquipiers = 4;

  static final RegExp _immatriculation =
      RegExp(r'^(\d{1,3})\s*TU\s*(\d{1,4})$', caseSensitive: false);

  Future<Database> get _db => AmbulanceSchema.database;

  static bool dansZone(LatLng p) =>
      FormuleHaversine.distanceKm(centreZone, p) <= rayonZoneKm;

  /// « 214tu5521 » → « 214 TU 5521 » ; null si le format est invalide.
  static String? normaliserImmatriculation(String saisie) {
    final RegExpMatch? m = _immatriculation.firstMatch(saisie.trim());
    if (m == null) {
      return null;
    }
    return '${m.group(1)} TU ${m.group(2)}';
  }

  // =====================================================================
  // Ambulances
  // =====================================================================

  Future<int> enregistrerAmbulance(Ambulance a) async {
    final String? immat = normaliserImmatriculation(a.immatriculation);
    if (immat == null) {
      throw const DispatchException('Immatriculation invalide (ex : 214 TU 5521)');
    }
    if (await _ambulances.immatriculationExiste(immat, exclureId: a.id)) {
      throw DispatchException("L'immatriculation $immat existe déjà");
    }
    if (a.kilometrage < 0) {
      throw const DispatchException('Le kilométrage ne peut pas être négatif');
    }
    if (!dansZone(a.position)) {
      throw const DispatchException(
        'La position doit se trouver dans la zone couverte (région de Sousse)',
      );
    }

    final int? id = a.id;
    if (id == null) {
      if (a.statut == StatutAmbulance.enMission) {
        throw const DispatchException(
          'Le statut « En mission » est attribué par le dispatch',
        );
      }
      return _ambulances.inserer(Ambulance(
        immatriculation: immat,
        type: a.type,
        statut: a.statut,
        latitude: a.latitude,
        longitude: a.longitude,
        kilometrage: a.kilometrage,
      ));
    }

    final Ambulance? ancienne = await _ambulances.parId(id);
    if (ancienne == null) {
      throw const DispatchException('Ambulance introuvable');
    }
    if (a.kilometrage < ancienne.kilometrage) {
      throw DispatchException(
        'Le kilométrage ne peut pas diminuer (compteur : ${ancienne.kilometrage} km)',
      );
    }
    final bool enMission = ancienne.statut == StatutAmbulance.enMission;
    if (enMission && a.statut != StatutAmbulance.enMission) {
      throw const DispatchException(
        'Ambulance en mission : terminez ou annulez la mission avant de changer son statut',
      );
    }
    if (!enMission && a.statut == StatutAmbulance.enMission) {
      throw const DispatchException(
        'Le statut « En mission » est attribué par le dispatch',
      );
    }
    if (a.statut == StatutAmbulance.disponible) {
      final String? motif = await motifBlocage(id, kilometrage: a.kilometrage);
      if (motif != null) {
        throw DispatchException('Remise en service impossible : $motif');
      }
    }

    await _ambulances.modifier(Ambulance(
      id: id,
      immatriculation: immat,
      type: a.type,
      statut: a.statut,
      // En mission, la position vient du suivi temps réel
      latitude: enMission ? ancienne.latitude : a.latitude,
      longitude: enMission ? ancienne.longitude : a.longitude,
      kilometrage: a.kilometrage,
    ));
    await controlerMaintenances();
    if (a.statut == StatutAmbulance.disponible) {
      await traiterFileAttente();
    }
    return id;
  }

  Future<void> supprimerAmbulance(int id) async {
    final Intervention? mission = await _interventions.activePourAmbulance(id);
    if (mission != null) {
      throw const DispatchException(
        'Ambulance en mission : suppression impossible avant la fin de la mission',
      );
    }
    // Équipage désaffecté, historique conservé (ON DELETE SET NULL)
    await _ambulances.supprimer(id);
  }

  /// Raison pour laquelle l'ambulance ne peut pas rouler (null si aucune).
  Future<String?> motifBlocage(int ambulanceId, {int? kilometrage}) async {
    final AmbulanceDetail? d = await _ambulances.detailParId(ambulanceId);
    if (d == null) {
      return null;
    }
    if (d.nbMaintenancesEnCours > 0) {
      return 'une maintenance est en cours';
    }
    final int? seuil = d.seuilEntretienKm;
    final int km = kilometrage ?? d.ambulance.kilometrage;
    if (seuil != null && km >= seuil) {
      return 'seuil d\'entretien de $seuil km atteint, enregistrez l\'entretien';
    }
    return null;
  }

  // =====================================================================
  // Ambulanciers (équipages)
  // =====================================================================

  Future<int> enregistrerAmbulancier(Ambulancier a) async {
    final String nom = a.nom.trim();
    if (nom.length < 3) {
      throw const DispatchException('Le nom doit contenir au moins 3 caractères');
    }
    final String? erreurTel = Validators.telephone(a.telephone);
    if (erreurTel != null) {
      throw DispatchException(erreurTel);
    }
    final String tel = Validators.normaliserTelephone(a.telephone);
    if (await _equipiers.telephoneExiste(tel, exclureId: a.id)) {
      throw const DispatchException('Ce numéro est déjà attribué à un ambulancier');
    }

    final int? id = a.id;
    final Ambulancier? ancien = id == null ? null : await _equipiers.parId(id);
    if (id != null && ancien == null) {
      throw const DispatchException('Ambulancier introuvable');
    }

    // On ne modifie pas l'équipage d'une ambulance en mission
    if (ancien != null) {
      final bool change =
          ancien.ambulanceId != a.ambulanceId || (ancien.disponible && !a.disponible);
      if (change && await _ambulanceEnMission(ancien.ambulanceId)) {
        throw const DispatchException(
          'Équipage en mission : modification possible après la fin de la mission',
        );
      }
    }

    final int? ambulanceId = a.ambulanceId;
    if (ambulanceId != null) {
      final bool dejaAffecte = ancien != null && ancien.ambulanceId == ambulanceId;
      final int nb = await _equipiers.compterAffectes(ambulanceId);
      if (!dejaAffecte && nb >= maxEquipiers) {
        throw const DispatchException(
          'Équipage complet : $maxEquipiers ambulanciers maximum par ambulance',
        );
      }
    }

    final Ambulancier propre = Ambulancier(
      id: id,
      nom: nom,
      role: a.role,
      telephone: tel,
      disponible: a.disponible,
      ambulanceId: ambulanceId,
    );
    if (id == null) {
      final int nouveau = await _equipiers.inserer(propre);
      await traiterFileAttente();
      return nouveau;
    }
    await _equipiers.modifier(propre);
    await traiterFileAttente();
    return id;
  }

  Future<void> supprimerAmbulancier(int id) async {
    final Ambulancier? a = await _equipiers.parId(id);
    if (a == null) {
      return;
    }
    if (await _ambulanceEnMission(a.ambulanceId)) {
      throw const DispatchException(
        'Ambulancier en mission : suppression possible après la fin de la mission',
      );
    }
    await _equipiers.supprimer(id);
  }

  Future<bool> _ambulanceEnMission(int? ambulanceId) async {
    if (ambulanceId == null) {
      return false;
    }
    final Ambulance? amb = await _ambulances.parId(ambulanceId);
    return amb != null && amb.statut == StatutAmbulance.enMission;
  }

  // =====================================================================
  // Dispatch automatique
  // =====================================================================

  /// Pénalité selon l'adéquation du véhicule à la gravité
  /// (null = type non autorisé pour cette gravité).
  static double? coefficient(TypeAmbulance type, Gravite gravite) {
    switch (gravite) {
      case Gravite.critique:
        if (type == TypeAmbulance.c) {
          return 1.0;
        }
        return type == TypeAmbulance.b ? 1.25 : null;
      case Gravite.urgente:
        if (type == TypeAmbulance.b) {
          return 1.0;
        }
        return type == TypeAmbulance.c ? 1.15 : 1.6;
      case Gravite.moderee:
        if (type == TypeAmbulance.a) {
          return 1.0;
        }
        return type == TypeAmbulance.b ? 1.1 : 1.6;
      case Gravite.faible:
        if (type == TypeAmbulance.a) {
          return 1.0;
        }
        return type == TypeAmbulance.b ? 1.2 : 2.0;
    }
  }

  /// Ambulances disponibles avec équipage, triées par score croissant
  /// (score = distance Haversine × coefficient du type).
  static List<CandidatDispatch> classer(
    List<AmbulanceDetail> flotte,
    LatLng lieu,
    Gravite gravite,
  ) {
    final List<CandidatDispatch> res = [];
    for (final AmbulanceDetail d in flotte) {
      final Ambulance a = d.ambulance;
      if (!a.estDisponible || !d.aEquipage) {
        continue;
      }
      final double? coef = coefficient(a.type, gravite);
      if (coef == null) {
        continue;
      }
      final double km = FormuleHaversine.distanceKm(a.position, lieu);
      res.add(CandidatDispatch(ambulance: a, distanceKm: km, score: km * coef));
    }
    res.sort((CandidatDispatch x, CandidatDispatch y) => x.score.compareTo(y.score));
    return res;
  }

  /// Aperçu du classement (formulaire de création, avant validation).
  Future<List<CandidatDispatch>> apercu(LatLng lieu, Gravite gravite) async {
    return classer(await _ambulances.details(), lieu, gravite);
  }

  /// Crée l'intervention puis lance le dispatch automatique.
  Future<ResultatDispatch> creerIntervention({
    required String adresse,
    required LatLng position,
    required Gravite gravite,
    OrigineIntervention origine = OrigineIntervention.appel,
    int? patientId,
    int? alerteId,
  }) async {
    final String adr = adresse.trim();
    if (adr.isEmpty) {
      throw const DispatchException("L'adresse de l'intervention est obligatoire");
    }
    if (!dansZone(position)) {
      throw DispatchException(
        'Lieu hors zone de couverture (${rayonZoneKm.round()} km autour de Sousse)',
      );
    }

    // Anti-doublon : un patient n'a qu'une intervention ouverte
    if (patientId != null) {
      final Intervention? existante = await _ouvertePourPatient(patientId);
      if (existante != null) {
        if (origine == OrigineIntervention.appel) {
          throw DispatchException(
            'Ce patient a déjà une intervention en cours (n°${existante.id})',
          );
        }
        // SOS / alerte répétés : on renvoie l'intervention existante
        return ResultatDispatch(
          intervention: existante,
          ambulance: await _ambulanceDe(existante),
          justification: 'Intervention déjà en cours pour ce patient',
        );
      }
    }

    final int id = await _interventions.inserer(Intervention(
      adresse: adr,
      lat: position.latitude,
      lng: position.longitude,
      gravite: gravite,
      origine: origine,
      patientId: patientId,
      alerteId: alerteId,
      heureAppel: DateTime.now(),
      hopitalDestination: Hopitaux.plusProche(position).nom,
    ));
    return dispatcher(id);
  }

  /// SOS : position GPS du téléphone, gravité critique par précaution.
  Future<ResultatDispatch> declencherSos({
    required LatLng position,
    int? patientId,
  }) async {
    final String adresse = await _nominatim.adresseDe(position) ?? _coordonnees(position);
    return creerIntervention(
      adresse: adresse,
      position: position,
      gravite: Gravite.critique,
      origine: OrigineIntervention.sos,
      patientId: patientId,
    );
  }

  /// Point d'entrée pour le module 2 (alertes vitales) : une alerte
  /// d'urgence crée automatiquement l'intervention et déclenche le dispatch.
  Future<ResultatDispatch> creerDepuisAlerte({
    required int alerteId,
    required int patientId,
    required LatLng position,
    String? adresse,
    Gravite gravite = Gravite.critique,
  }) async {
    final String adr =
        adresse ?? await _nominatim.adresseDe(position) ?? _coordonnees(position);
    return creerIntervention(
      adresse: adr,
      position: position,
      gravite: gravite,
      origine: OrigineIntervention.alerte,
      patientId: patientId,
      alerteId: alerteId,
    );
  }

  /// Affecte la meilleure ambulance à une intervention en attente.
  Future<ResultatDispatch> dispatcher(int interventionId) async {
    final Intervention? i = await _interventions.parId(interventionId);
    if (i == null) {
      throw const DispatchException('Intervention introuvable');
    }
    if (i.statut != StatutIntervention.enAttente) {
      return ResultatDispatch(intervention: i, ambulance: await _ambulanceDe(i));
    }

    final List<CandidatDispatch> candidats =
        classer(await _ambulances.details(), i.position, i.gravite);
    if (candidats.isNotEmpty) {
      final CandidatDispatch choix = candidats.first;
      final Intervention affectee = await _affecter(i, choix.ambulance);
      return ResultatDispatch(
        intervention: affectee,
        ambulance: choix.ambulance.copyWith(statut: StatutAmbulance.enMission),
        distanceKm: choix.distanceKm,
        justification: _justification(choix, i.gravite, candidats.length),
      );
    }

    if (i.gravite == Gravite.critique) {
      final ResultatDispatch? requisition = await _requisitionner(i);
      if (requisition != null) {
        return requisition;
      }
    }
    return ResultatDispatch(
      intervention: i,
      justification: "Aucune ambulance adaptée disponible : intervention en file "
          "d'attente (priorité ${i.gravite.libelle.toLowerCase()})",
    );
  }

  /// Relance le dispatch des interventions en attente, la plus grave d'abord.
  Future<List<ResultatDispatch>> traiterFileAttente() async {
    final List<ResultatDispatch> res = [];
    final List<Intervention> file = await _interventions.fileAttente();
    for (final Intervention i in file) {
      final int? id = i.id;
      if (id == null) {
        continue;
      }
      final ResultatDispatch r = await dispatcher(id);
      if (r.assignee) {
        res.add(r);
      }
    }
    return res;
  }

  Future<Intervention> _affecter(Intervention i, Ambulance a) async {
    final int? interventionId = i.id;
    final int? ambulanceId = a.id;
    if (interventionId == null || ambulanceId == null) {
      throw const DispatchException('Données incomplètes pour le dispatch');
    }
    final Database db = await _db;
    await db.transaction((Transaction txn) async {
      // Revérifie dans la transaction : l'ambulance a pu partir entre-temps
      final Ambulance? fraiche = await _ambulances.parId(ambulanceId, exec: txn);
      if (fraiche == null || !fraiche.estDisponible) {
        throw const DispatchException(
          "L'ambulance vient d'être engagée ailleurs, relancez le dispatch",
        );
      }
      await _interventions.mettreAJour(
        interventionId,
        {
          'ambulance_id': ambulanceId,
          'statut': StatutIntervention.assignee.code,
        },
        exec: txn,
      );
      await _ambulances.changerStatut(ambulanceId, StatutAmbulance.enMission, exec: txn);
    });
    return i.copyWith(ambulanceId: ambulanceId, statut: StatutIntervention.assignee);
  }

  /// Urgence critique sans ambulance libre : on prend l'ambulance la plus
  /// proche engagée sur une mission modérée/faible et pas encore sur place.
  Future<ResultatDispatch?> _requisitionner(Intervention critique) async {
    final int? critiqueId = critique.id;
    if (critiqueId == null) {
      return null;
    }
    Intervention? cible;
    Ambulance? ambulance;
    double min = double.infinity;

    final List<Intervention> ouvertes = await _interventions.ouvertes();
    for (final Intervention o in ouvertes) {
      final bool pasSurPlace = o.statut == StatutIntervention.assignee ||
          o.statut == StatutIntervention.enRoute;
      if (!pasSurPlace || o.gravite.priorite < Gravite.moderee.priorite) {
        continue;
      }
      final int? ambId = o.ambulanceId;
      if (ambId == null) {
        continue;
      }
      final Ambulance? amb = await _ambulances.parId(ambId);
      if (amb == null || coefficient(amb.type, Gravite.critique) == null) {
        continue;
      }
      final double d = FormuleHaversine.distanceKm(amb.position, critique.position);
      if (d < min) {
        min = d;
        cible = o;
        ambulance = amb;
      }
    }

    final Intervention? aLiberer = cible;
    final Ambulance? requise = ambulance;
    if (aLiberer == null || requise == null) {
      return null;
    }
    final int? cibleId = aLiberer.id;
    final int? ambulanceId = requise.id;
    if (cibleId == null || ambulanceId == null) {
      return null;
    }

    final Database db = await _db;
    await db.transaction((Transaction txn) async {
      await _interventions.mettreAJour(
        cibleId,
        {
          'ambulance_id': null,
          'statut': StatutIntervention.enAttente.code,
          'heure_depart': null,
        },
        exec: txn,
      );
      await _interventions.mettreAJour(
        critiqueId,
        {
          'ambulance_id': ambulanceId,
          'statut': StatutIntervention.assignee.code,
        },
        exec: txn,
      );
    });

    return ResultatDispatch(
      intervention: critique.copyWith(
        ambulanceId: ambulanceId,
        statut: StatutIntervention.assignee,
      ),
      ambulance: requise,
      distanceKm: min,
      justification: 'Réquisition : ${requise.immatriculation} quitte l\'intervention '
          'n°$cibleId (${aLiberer.gravite.libelle.toLowerCase()}), remise en file d\'attente',
      reaffectee: aLiberer,
    );
  }

  String _justification(CandidatDispatch c, Gravite g, int nbCandidats) {
    final String km = c.distanceKm.toStringAsFixed(1).replaceAll('.', ',');
    return '${c.ambulance.immatriculation} (${c.ambulance.type.libelle}) à $km km — '
        'meilleur choix parmi $nbCandidats ambulance(s) pour une urgence '
        '${g.libelle.toLowerCase()}';
  }

  Future<Intervention?> _ouvertePourPatient(int patientId) async {
    final List<Intervention> ouvertes = await _interventions.ouvertes();
    for (final Intervention i in ouvertes) {
      if (i.patientId == patientId) {
        return i;
      }
    }
    return null;
  }

  Future<Ambulance?> _ambulanceDe(Intervention i) async {
    final int? id = i.ambulanceId;
    return id == null ? null : _ambulances.parId(id);
  }

  String _coordonnees(LatLng p) =>
      'Position GPS ${p.latitude.toStringAsFixed(5)}, ${p.longitude.toStringAsFixed(5)}';

  // =====================================================================
  // Cycle de vie d'une intervention
  // =====================================================================

  Future<Intervention> _charger(int id) async {
    final Intervention? i = await _interventions.parId(id);
    if (i == null) {
      throw const DispatchException('Intervention introuvable');
    }
    return i;
  }

  /// Assignée → En route (heure de départ).
  Future<Intervention> demarrer(int id) async {
    final Intervention i = await _charger(id);
    if (i.statut != StatutIntervention.assignee) {
      throw DispatchException('Départ impossible : intervention « ${i.statut.libelle} »');
    }
    final DateTime maintenant = DateTime.now();
    await _interventions.mettreAJour(id, {
      'statut': StatutIntervention.enRoute.code,
      'heure_depart': maintenant.toIso8601String(),
    });
    return i.copyWith(statut: StatutIntervention.enRoute, heureDepart: maintenant);
  }

  /// En route → Sur place (heure d'arrivée = fin du temps de réponse).
  Future<Intervention> arriverSurPlace(int id) async {
    final Intervention i = await _charger(id);
    if (i.statut != StatutIntervention.enRoute &&
        i.statut != StatutIntervention.assignee) {
      throw DispatchException('Arrivée impossible : intervention « ${i.statut.libelle} »');
    }
    final DateTime maintenant = DateTime.now();
    await _interventions.mettreAJour(id, {
      'statut': StatutIntervention.surPlace.code,
      'heure_depart': (i.heureDepart ?? maintenant).toIso8601String(),
      'heure_arrivee': maintenant.toIso8601String(),
    });
    final int? ambId = i.ambulanceId;
    if (ambId != null) {
      await _ambulances.deplacer(ambId, i.lat, i.lng);
    }
    return i.copyWith(
      statut: StatutIntervention.surPlace,
      heureDepart: i.heureDepart ?? maintenant,
      heureArrivee: maintenant,
    );
  }

  /// Sur place → Transport vers l'hôpital choisi.
  Future<Intervention> transporter(int id, String hopital) async {
    final Intervention i = await _charger(id);
    if (i.statut != StatutIntervention.surPlace) {
      throw const DispatchException('Le transport commence une fois sur place');
    }
    if (Hopitaux.parNom(hopital) == null) {
      throw const DispatchException('Hôpital de destination inconnu');
    }
    await _interventions.mettreAJour(id, {
      'statut': StatutIntervention.transport.code,
      'hopital_destination': hopital,
    });
    return i.copyWith(statut: StatutIntervention.transport, hopitalDestination: hopital);
  }

  /// Clôture : l'ambulance redevient disponible là où elle se trouve
  /// (hôpital ou lieu d'intervention), ses kilomètres sont ajoutés,
  /// puis contrôle d'entretien et traitement de la file d'attente.
  Future<List<ResultatDispatch>> terminer(int id, {double kmParcourus = 0}) async {
    final Intervention i = await _charger(id);
    if (i.statut != StatutIntervention.surPlace &&
        i.statut != StatutIntervention.transport) {
      throw const DispatchException("Terminez l'intervention une fois sur place");
    }

    LatLng arrivee = i.position;
    double km = kmParcourus;
    final Hopital? hopital = Hopitaux.parNom(i.hopitalDestination);
    if (i.statut == StatutIntervention.transport && hopital != null) {
      arrivee = hopital.position;
      if (km <= 0) {
        km = FormuleHaversine.distanceKm(i.position, hopital.position) * 1.3;
      }
    }

    final int? ambId = i.ambulanceId;
    final Database db = await _db;
    await db.transaction((Transaction txn) async {
      await _interventions.mettreAJour(
        id,
        {'statut': StatutIntervention.terminee.code},
        exec: txn,
      );
      if (ambId != null) {
        await txn.update(
          'ambulances',
          {
            'statut': StatutAmbulance.disponible.code,
            'latitude': arrivee.latitude,
            'longitude': arrivee.longitude,
          },
          where: 'id = ?',
          whereArgs: [ambId],
        );
        await _ambulances.ajouterKilometres(ambId, km.round(), exec: txn);
      }
    });

    await controlerMaintenances();
    return traiterFileAttente();
  }

  Future<List<ResultatDispatch>> annuler(int id) async {
    final Intervention i = await _charger(id);
    if (!i.statut.estOuverte) {
      throw const DispatchException('Cette intervention est déjà clôturée');
    }
    final int? ambId = i.ambulanceId;
    final Database db = await _db;
    await db.transaction((Transaction txn) async {
      await _interventions.mettreAJour(
        id,
        {'statut': StatutIntervention.annulee.code},
        exec: txn,
      );
      if (ambId != null && i.statut.estActive) {
        await _ambulances.changerStatut(ambId, StatutAmbulance.disponible, exec: txn);
      }
    });
    await controlerMaintenances();
    return traiterFileAttente();
  }

  // =====================================================================
  // Maintenance préventive
  // =====================================================================

  static DateTime _jour(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Ajout / modification. Le statut est déduit de la date :
  /// future = planifiée, aujourd'hui ou passée = en cours (ambulance bloquée),
  /// sauf si elle est enregistrée comme terminée.
  Future<int> enregistrerMaintenance(Maintenance m) async {
    if (m.cout < 0) {
      throw const DispatchException('Le coût ne peut pas être négatif');
    }
    final Ambulance? amb = await _ambulances.parId(m.ambulanceId);
    if (amb == null) {
      throw const DispatchException('Ambulance introuvable');
    }
    final DateTime aujourdhui = _jour(DateTime.now());
    final DateTime jour = _jour(m.date);

    StatutMaintenance statut = m.statut;
    if (statut == StatutMaintenance.terminee) {
      if (jour.isAfter(aujourdhui)) {
        throw const DispatchException(
          'Une maintenance terminée ne peut pas être datée dans le futur',
        );
      }
      final int? prochain = m.prochainEntretienKm;
      if (prochain == null || prochain <= amb.kilometrage) {
        throw DispatchException(
          'Le prochain entretien doit dépasser le kilométrage actuel '
          '(${amb.kilometrage} km)',
        );
      }
    } else {
      statut = jour.isAfter(aujourdhui)
          ? StatutMaintenance.planifiee
          : StatutMaintenance.enCours;
    }
    if (statut == StatutMaintenance.enCours &&
        amb.statut == StatutAmbulance.enMission) {
      throw const DispatchException(
        'Ambulance en mission : planifiez la maintenance pour plus tard',
      );
    }

    final Maintenance propre = m.copyWith(statut: statut);
    int id;
    final int? existant = m.id;
    if (existant == null) {
      id = await _maintenances.inserer(propre);
    } else {
      await _maintenances.modifier(propre);
      id = existant;
    }
    await controlerMaintenances();
    await traiterFileAttente();
    return id;
  }

  /// Clôt la maintenance : coût réel + nouveau seuil kilométrique.
  /// L'ambulance est débloquée automatiquement si plus rien ne la retient.
  Future<List<ResultatDispatch>> terminerMaintenance(
    Maintenance m, {
    required double cout,
    required int prochainEntretienKm,
  }) async {
    final Ambulance? amb = await _ambulances.parId(m.ambulanceId);
    if (amb == null) {
      throw const DispatchException('Ambulance introuvable');
    }
    if (cout < 0) {
      throw const DispatchException('Le coût ne peut pas être négatif');
    }
    if (prochainEntretienKm <= amb.kilometrage) {
      throw DispatchException(
        'Le prochain entretien doit dépasser le kilométrage actuel '
        '(${amb.kilometrage} km)',
      );
    }
    final DateTime aujourdhui = _jour(DateTime.now());
    await _maintenances.modifier(m.copyWith(
      statut: StatutMaintenance.terminee,
      cout: cout,
      prochainEntretienKm: prochainEntretienKm,
      date: _jour(m.date).isAfter(aujourdhui) ? aujourdhui : m.date,
    ));
    await controlerMaintenances();
    return traiterFileAttente();
  }

  Future<void> supprimerMaintenance(int id) async {
    await _maintenances.supprimer(id);
    await controlerMaintenances();
    await traiterFileAttente();
  }

  /// Contrôle automatique (ouverture du module, fin de mission, saisie) :
  /// 1. une maintenance planifiée dont la date arrive passe « en cours » ;
  /// 2. une ambulance avec maintenance en cours ou seuil km dépassé est
  ///    bloquée ; elle est remise en service quand plus rien ne la retient.
  /// Renvoie les changements effectués (pour les notifier).
  Future<List<String>> controlerMaintenances() async {
    final List<String> messages = [];
    final DateTime aujourdhui = _jour(DateTime.now());

    final List<Maintenance> planifiees =
        await _maintenances.parStatut(StatutMaintenance.planifiee);
    for (final Maintenance m in planifiees) {
      if (_jour(m.date).isAfter(aujourdhui)) {
        continue;
      }
      final Ambulance? a = await _ambulances.parId(m.ambulanceId);
      // En mission : la maintenance démarrera au retour
      if (a != null && a.statut != StatutAmbulance.enMission) {
        await _maintenances.modifier(m.copyWith(statut: StatutMaintenance.enCours));
        messages.add('${a.immatriculation} : ${m.type.libelle.toLowerCase()} prévue aujourd\'hui');
      }
    }

    final List<AmbulanceDetail> flotte = await _ambulances.details();
    for (final AmbulanceDetail d in flotte) {
      final Ambulance a = d.ambulance;
      final int? id = a.id;
      if (id == null ||
          a.statut == StatutAmbulance.enMission ||
          a.statut == StatutAmbulance.horsService) {
        continue;
      }
      final bool bloquer = d.nbMaintenancesEnCours > 0 || d.seuilDepasse;
      if (bloquer && a.statut != StatutAmbulance.maintenance) {
        await _ambulances.changerStatut(id, StatutAmbulance.maintenance);
        if (d.seuilDepasse) {
          messages.add(
            '${a.immatriculation} bloquée : seuil d\'entretien de ${d.seuilEntretienKm} km atteint',
          );
        } else {
          messages.add('${a.immatriculation} bloquée : maintenance en cours');
        }
      } else if (!bloquer && a.statut == StatutAmbulance.maintenance) {
        await _ambulances.changerStatut(id, StatutAmbulance.disponible);
        messages.add('${a.immatriculation} remise en service');
      }
    }
    return messages;
  }

  /// Remet en service une ambulance « hors service » (panne réparée).
  Future<List<ResultatDispatch>> changerDisponibilite(int id, {required bool horsService}) async {
    final Ambulance? a = await _ambulances.parId(id);
    if (a == null) {
      throw const DispatchException('Ambulance introuvable');
    }
    if (a.statut == StatutAmbulance.enMission) {
      throw const DispatchException('Ambulance en mission');
    }
    if (horsService) {
      await _ambulances.changerStatut(id, StatutAmbulance.horsService);
      return [];
    }
    final String? motif = await motifBlocage(id);
    if (motif != null) {
      throw DispatchException('Remise en service impossible : $motif');
    }
    await _ambulances.changerStatut(id, StatutAmbulance.disponible);
    return traiterFileAttente();
  }

  // =====================================================================
  // KPI
  // =====================================================================

  Future<KpiDispatch> kpi({DateTime? depuis}) async {
    final List<InterventionDetail> liste =
        await _interventions.rechercher(depuis: depuis);
    final List<AmbulanceDetail> flotte = await _ambulances.details();

    final Map<String, int> missions = {};
    int flotteDisponible = 0;
    for (final AmbulanceDetail d in flotte) {
      missions[d.ambulance.immatriculation] = 0;
      if (d.ambulance.estDisponible) {
        flotteDisponible++;
      }
    }

    final Map<Gravite, int> parGravite = {};
    final Map<Gravite, int> sommeParGravite = {};
    final Map<Gravite, int> nbParGravite = {};
    for (final Gravite g in Gravite.values) {
      parGravite[g] = 0;
      sommeParGravite[g] = 0;
      nbParGravite[g] = 0;
    }

    int terminees = 0;
    int enCours = 0;
    int enAttente = 0;
    int sommeReponse = 0;
    int nbReponse = 0;
    int sommeDepart = 0;
    int nbDepart = 0;
    int dansObjectif = 0;

    for (final InterventionDetail d in liste) {
      final Intervention i = d.intervention;
      if (i.statut == StatutIntervention.annulee) {
        continue;
      }
      parGravite[i.gravite] = (parGravite[i.gravite] ?? 0) + 1;
      if (i.statut == StatutIntervention.terminee) {
        terminees++;
      } else if (i.statut == StatutIntervention.enAttente) {
        enAttente++;
      } else {
        enCours++;
      }

      final String? immat = d.immatriculation;
      if (immat != null) {
        missions[immat] = (missions[immat] ?? 0) + 1;
      }

      final Duration? reponse = i.tempsReponse;
      if (reponse != null) {
        sommeReponse += reponse.inSeconds;
        nbReponse++;
        sommeParGravite[i.gravite] = (sommeParGravite[i.gravite] ?? 0) + reponse.inSeconds;
        nbParGravite[i.gravite] = (nbParGravite[i.gravite] ?? 0) + 1;
        if (reponse <= KpiDispatch.objectif) {
          dansObjectif++;
        }
      }
      final DateTime? depart = i.heureDepart;
      if (depart != null) {
        sommeDepart += depart.difference(i.heureAppel).inSeconds;
        nbDepart++;
      }
    }

    final Map<Gravite, Duration> tempsParGravite = {};
    for (final Gravite g in Gravite.values) {
      final int n = nbParGravite[g] ?? 0;
      if (n > 0) {
        tempsParGravite[g] = Duration(seconds: (sommeParGravite[g] ?? 0) ~/ n);
      }
    }

    return KpiDispatch(
      nbInterventions: terminees + enCours + enAttente,
      nbTerminees: terminees,
      nbEnCours: enCours,
      nbEnAttente: enAttente,
      tempsMoyenReponse: nbReponse == 0 ? null : Duration(seconds: sommeReponse ~/ nbReponse),
      tempsMoyenDepart: nbDepart == 0 ? null : Duration(seconds: sommeDepart ~/ nbDepart),
      tauxObjectif: nbReponse == 0 ? 0 : dansObjectif / nbReponse,
      missionsParAmbulance: missions,
      parGravite: parGravite,
      tempsParGravite: tempsParGravite,
      flotteDisponible: flotteDisponible,
      flotteTotale: flotte.length,
      coutMaintenance: await _maintenances.coutTotal(depuis: depuis),
    );
  }
}
