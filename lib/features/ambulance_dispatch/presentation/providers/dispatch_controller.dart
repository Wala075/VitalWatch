import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../data/ambulance_repository.dart';
import '../../data/api/geolocalisation_service.dart';
import '../../data/api/osrm_api.dart';
import '../../data/intervention_repository.dart';
import '../../domain/dispatch_manager.dart';
import '../../domain/dispatch_models.dart';
import '../../domain/haversine.dart';
import '../../domain/hopitaux.dart';
import '../../domain/models/ambulance.dart';
import '../../domain/models/intervention.dart';
import 'suivi_mission.dart';

/// État partagé du module : flotte, interventions ouvertes et suivi
/// temps réel des ambulances (simulation le long de l'itinéraire OSRM,
/// ou position GPS réelle partagée par l'ambulancier).
class DispatchController extends ChangeNotifier {
  DispatchController._();

  static final DispatchController instance = DispatchController._();

  final DispatchManager manager = DispatchManager();
  final GeolocalisationService gps = GeolocalisationService();
  final AmbulanceRepository _ambulances = AmbulanceRepository();
  final InterventionRepository _interventions = InterventionRepository();
  final OsrmApi _osrm = OsrmApi();

  static const List<StatutIntervention> statutsOuverts = [
    StatutIntervention.enAttente,
    StatutIntervention.assignee,
    StatutIntervention.enRoute,
    StatutIntervention.surPlace,
    StatutIntervention.transport,
  ];

  /// Temps de mobilisation de l'équipage avant le départ (simulation).
  static const Duration mobilisation = Duration(seconds: 60);

  List<AmbulanceDetail> flotte = [];
  List<InterventionDetail> ouvertes = [];

  /// Clé : id de l'intervention.
  final Map<int, SuiviMission> suivis = {};
  final Map<int, double> _kmMissions = {};
  final Set<int> _calculsEnCours = {};
  final List<String> _evenements = [];

  bool charge = false;
  String? erreur;

  /// Incrémenté à chaque rechargement des données (pas à chaque tick de
  /// position) : les listes ne se rechargent que si elle change.
  int revision = 0;

  /// Simulation du déplacement (démo) et facteur d'accélération.
  bool simulation = true;
  int vitesse = 10;

  Timer? _horloge;
  bool _tickEnCours = false;
  int _ticks = 0;
  bool _premierControle = true;

  StreamSubscription<Position>? _abonnementGps;
  int? ambulanceGps;

  // =====================================================================
  // Chargement
  // =====================================================================

  Future<void> demarrer() async {
    _horloge ??= Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    if (_premierControle) {
      _premierControle = false;
      try {
        _evenements.addAll(await manager.controlerMaintenances());
        _noterDispatchs(await manager.traiterFileAttente());
      } catch (e) {
        erreur = '$e';
      }
    }
    await rafraichir();
  }

  Future<void> rafraichir() async {
    try {
      flotte = await _ambulances.details();
      ouvertes = await _interventions.rechercher(statuts: statutsOuverts);
      charge = true;
      erreur = null;
      revision++;
      notifyListeners();
      await _synchroniserSuivis();
    } catch (e) {
      erreur = '$e';
    }
    notifyListeners();
  }

  /// Crée / met à jour les suivis des missions où l'ambulance roule.
  Future<void> _synchroniserSuivis() async {
    final Set<int> actives = {};
    for (final InterventionDetail d in ouvertes) {
      final Intervention i = d.intervention;
      final int? id = i.id;
      final int? ambId = i.ambulanceId;
      final bool roule = i.statut == StatutIntervention.assignee ||
          i.statut == StatutIntervention.enRoute ||
          i.statut == StatutIntervention.transport;
      if (id == null || ambId == null || !roule) {
        continue;
      }
      actives.add(id);

      final SuiviMission? existant = suivis[id];
      if (existant != null &&
          existant.ambulanceId == ambId &&
          _memeTrajet(existant.phase, i.statut)) {
        // Passage assignée → en route : même trajet, nouvelle phase
        if (existant.phase != i.statut) {
          suivis[id] = _copierPhase(existant, i.statut);
        }
        continue;
      }
      if (_calculsEnCours.contains(id)) {
        continue;
      }

      final Ambulance? amb = ambulanceParId(ambId);
      if (amb == null) {
        continue;
      }
      final LatLng depart = existant?.position ?? amb.position;
      LatLng cible = i.position;
      if (i.statut == StatutIntervention.transport) {
        cible = Hopitaux.parNom(i.hopitalDestination)?.position ?? i.position;
      }

      _calculsEnCours.add(id);
      try {
        final Itineraire it = await _osrm.itineraire(depart, cible);
        suivis[id] = SuiviMission(
          interventionId: id,
          ambulanceId: ambId,
          phase: i.statut,
          itineraire: it,
          cible: cible,
        );
      } finally {
        _calculsEnCours.remove(id);
      }
    }

    final List<int> obsoletes = [];
    for (final int id in suivis.keys) {
      if (!actives.contains(id)) {
        obsoletes.add(id);
      }
    }
    for (final int id in obsoletes) {
      suivis.remove(id);
    }
  }

  /// assignée et en route partagent le même trajet (base → patient).
  bool _memeTrajet(StatutIntervention a, StatutIntervention b) {
    if (a == b) {
      return true;
    }
    final bool aVersPatient =
        a == StatutIntervention.assignee || a == StatutIntervention.enRoute;
    final bool bVersPatient =
        b == StatutIntervention.assignee || b == StatutIntervention.enRoute;
    return aVersPatient && bVersPatient;
  }

  SuiviMission _copierPhase(SuiviMission s, StatutIntervention phase) {
    final SuiviMission copie = SuiviMission(
      interventionId: s.interventionId,
      ambulanceId: s.ambulanceId,
      phase: phase,
      itineraire: s.itineraire,
      cible: s.cible,
    );
    copie.parcouruKm = s.parcouruKm;
    copie.position = s.position;
    return copie;
  }

  // =====================================================================
  // Accès pour l'interface
  // =====================================================================

  Ambulance? ambulanceParId(int id) {
    for (final AmbulanceDetail d in flotte) {
      if (d.ambulance.id == id) {
        return d.ambulance;
      }
    }
    return null;
  }

  /// Position affichée : celle du suivi si l'ambulance roule.
  LatLng positionAmbulance(Ambulance a) {
    for (final SuiviMission s in suivis.values) {
      if (s.ambulanceId == a.id) {
        return s.position;
      }
    }
    return a.position;
  }

  SuiviMission? suiviDe(int interventionId) => suivis[interventionId];

  InterventionDetail? ouverteParId(int id) {
    for (final InterventionDetail d in ouvertes) {
      if (d.intervention.id == id) {
        return d;
      }
    }
    return null;
  }

  /// Mission en cours d'une ambulance (vue ambulancier).
  InterventionDetail? missionDe(int ambulanceId) {
    for (final InterventionDetail d in ouvertes) {
      if (d.intervention.ambulanceId == ambulanceId && d.intervention.statut.estActive) {
        return d;
      }
    }
    return null;
  }

  int get nbEnAttente {
    int n = 0;
    for (final InterventionDetail d in ouvertes) {
      if (d.intervention.statut == StatutIntervention.enAttente) {
        n++;
      }
    }
    return n;
  }

  int compterFlotte(StatutAmbulance s) {
    int n = 0;
    for (final AmbulanceDetail d in flotte) {
      if (d.ambulance.statut == s) {
        n++;
      }
    }
    return n;
  }

  /// Notifications métier (dispatch auto, blocage...) à afficher une fois.
  List<String> prendreEvenements() {
    final List<String> res = List<String>.of(_evenements);
    _evenements.clear();
    return res;
  }

  void _noterDispatchs(List<ResultatDispatch> res) {
    for (final ResultatDispatch r in res) {
      final Ambulance? a = r.ambulance;
      if (a != null) {
        _evenements.add(
          'File d\'attente : ${a.immatriculation} envoyée sur « ${r.intervention.adresse} »',
        );
      }
    }
  }

  // =====================================================================
  // Actions
  // =====================================================================

  Future<ResultatDispatch> creerIntervention({
    required String adresse,
    required LatLng position,
    required Gravite gravite,
    OrigineIntervention origine = OrigineIntervention.appel,
    int? patientId,
    int? alerteId,
  }) async {
    final ResultatDispatch r = await manager.creerIntervention(
      adresse: adresse,
      position: position,
      gravite: gravite,
      origine: origine,
      patientId: patientId,
      alerteId: alerteId,
    );
    await rafraichir();
    return r;
  }

  /// Alerte vitale (montre) → intervention + dispatch automatique.
  Future<ResultatDispatch> creerDepuisAlerte({
    required int patientId,
    required LatLng position,
    required Gravite gravite,
    int? alerteId,
  }) async {
    final ResultatDispatch r = await manager.creerDepuisAlerte(
      alerteId: alerteId,
      patientId: patientId,
      position: position,
      gravite: gravite,
    );
    await rafraichir();
    return r;
  }

  Future<ResultatDispatch> declencherSos(LatLng position, {int? patientId}) async {
    final ResultatDispatch r =
        await manager.declencherSos(position: position, patientId: patientId);
    await rafraichir();
    return r;
  }

  Future<ResultatDispatch> relancerDispatch(int id) async {
    final ResultatDispatch r = await manager.dispatcher(id);
    await rafraichir();
    return r;
  }

  Future<void> demarrerMission(int id) async {
    await manager.demarrer(id);
    await rafraichir();
  }

  Future<void> arriverSurPlace(int id) async {
    _cumulerKm(id);
    await manager.arriverSurPlace(id);
    await rafraichir();
  }

  Future<void> transporter(int id, String hopital) async {
    await manager.transporter(id, hopital);
    await rafraichir();
  }

  Future<List<ResultatDispatch>> terminer(int id) async {
    _cumulerKm(id);
    final List<ResultatDispatch> res =
        await manager.terminer(id, kmParcourus: _kmMissions.remove(id) ?? 0);
    _noterDispatchs(res);
    await rafraichir();
    return res;
  }

  Future<List<ResultatDispatch>> annuler(int id) async {
    _cumulerKm(id);
    final int? ambId = ouverteParId(id)?.intervention.ambulanceId;
    final double km = _kmMissions.remove(id) ?? 0;
    final List<ResultatDispatch> res = await manager.annuler(id);
    if (ambId != null && km > 0) {
      await _ambulances.ajouterKilometres(ambId, km.round());
    }
    _noterDispatchs(res);
    await rafraichir();
    return res;
  }

  /// Ajoute la distance du suivi en cours au total de la mission.
  void _cumulerKm(int id) {
    final SuiviMission? s = suivis.remove(id);
    if (s != null) {
      _kmMissions[id] = (_kmMissions[id] ?? 0) + s.parcouruKm;
      final int ambId = s.ambulanceId;
      _ambulances.deplacer(ambId, s.position.latitude, s.position.longitude);
    }
  }

  void changerVitesse(int v) {
    vitesse = v;
    notifyListeners();
  }

  void basculerSimulation(bool actif) {
    simulation = actif;
    notifyListeners();
  }

  // =====================================================================
  // Horloge : simulation du déplacement (1 tick / seconde)
  // =====================================================================

  Future<void> _tick() async {
    if (_tickEnCours || suivis.isEmpty) {
      return;
    }
    _tickEnCours = true;
    _ticks++;
    bool recharger = false;
    bool bouge = false;
    try {
      final DateTime maintenant = DateTime.now();
      final List<SuiviMission> liste = List<SuiviMission>.of(suivis.values);
      for (final SuiviMission s in liste) {
        if (!simulation || s.ambulanceId == ambulanceGps) {
          continue;
        }
        if (s.phase == StatutIntervention.assignee) {
          // Mobilisation de l'équipage puis départ automatique
          if (maintenant.difference(s.debut) * vitesse >= mobilisation) {
            await manager.demarrer(s.interventionId);
            _evenements.add('${_immat(s.ambulanceId)} part en intervention');
            recharger = true;
          }
          continue;
        }
        if (!s.enMouvement) {
          continue;
        }
        s.avancer(s.vitesseKmS * vitesse);
        bouge = true;
        if (s.arrive) {
          await _arrivee(s);
          recharger = true;
        } else if (_ticks % 5 == 0) {
          await _ambulances.deplacer(
            s.ambulanceId,
            s.position.latitude,
            s.position.longitude,
          );
        }
      }
    } catch (e) {
      erreur = '$e';
    } finally {
      _tickEnCours = false;
    }
    if (recharger) {
      await rafraichir();
    } else if (bouge) {
      notifyListeners();
    }
  }

  Future<void> _arrivee(SuiviMission s) async {
    final int id = s.interventionId;
    final String immat = _immat(s.ambulanceId);
    if (s.phase == StatutIntervention.enRoute) {
      await arriverSurPlace(id);
      final Intervention? i = await _interventions.parId(id);
      final Duration? reponse = i?.tempsReponse;
      _evenements.add(
        '$immat sur place${reponse == null ? '' : ' — temps de réponse ${_minutes(reponse)}'}',
      );
    } else if (s.phase == StatutIntervention.transport) {
      await terminer(id);
      _evenements.add('$immat arrivée à l\'hôpital : mission terminée');
    }
  }

  String _minutes(Duration d) {
    if (d.inMinutes < 1) {
      return '${d.inSeconds} s';
    }
    return '${d.inMinutes} min';
  }

  String _immat(int ambulanceId) => ambulanceParId(ambulanceId)?.immatriculation ?? 'Ambulance';

  // =====================================================================
  // GPS réel (téléphone de l'ambulancier)
  // =====================================================================

  bool get partageGps => _abonnementGps != null;

  Future<void> partagerPosition(int ambulanceId) async {
    await arreterPartage();
    _abonnementGps = await gps.suivre((LatLng p) => _surPositionGps(ambulanceId, p));
    ambulanceGps = ambulanceId;
    notifyListeners();
  }

  Future<void> arreterPartage() async {
    await _abonnementGps?.cancel();
    _abonnementGps = null;
    ambulanceGps = null;
    notifyListeners();
  }

  Future<void> _surPositionGps(int ambulanceId, LatLng p) async {
    await _ambulances.deplacer(ambulanceId, p.latitude, p.longitude);
    SuiviMission? arrivee;
    for (final SuiviMission s in suivis.values) {
      if (s.ambulanceId == ambulanceId) {
        s.placer(p);
        // Arrivée détectée à moins de 80 m de la cible
        if (s.enMouvement && FormuleHaversine.distanceKm(p, s.cible) < 0.08) {
          arrivee = s;
        }
      }
    }
    final SuiviMission? a = arrivee;
    if (a != null) {
      await _arrivee(a);
      return;
    }
    notifyListeners();
  }
}
