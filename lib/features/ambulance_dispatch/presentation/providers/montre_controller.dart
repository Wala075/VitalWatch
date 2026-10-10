import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import '../../data/api/montre_ble_service.dart';
import '../../data/rythme_repository.dart';
import '../../domain/dispatch_manager.dart';
import '../../domain/dispatch_models.dart';
import '../../domain/models/intervention.dart';
import '../../domain/surveillance_cardiaque.dart';
import 'dispatch_controller.dart';

/// Montre Mibro C2 du patient connecté, pour TOUTE l'application (accueil,
/// écran montre, SOS, écran verrouillé avec la protection vocale) :
/// - connexion Bluetooth et lecture toutes les 30 s ;
/// - enregistrement des mesures (médecin, régulation, ambulancier) ;
/// - seuils fixés par le médecin, relus à chaque synchro ;
/// - détection des alertes, publiées sur [alertes] (l'espace patient affiche
///   « Ça va ? » puis envoie l'ambulance).
///
/// Démarrée à l'ouverture de l'espace patient, arrêtée à la déconnexion.
class MontreController extends ChangeNotifier {
  MontreController._();

  static final MontreController instance = MontreController._();

  static const Duration frequence = Duration(seconds: 30);
  static const Duration periode = Duration(hours: 3);

  final MontreBleService montre = MontreBleService();
  final RythmeRepository _rythme = RythmeRepository();
  final StreamController<AlerteCardiaque> _alertes =
      StreamController<AlerteCardiaque>.broadcast();
  final StreamController<String> _messages = StreamController<String>.broadcast();

  AnalyseurCardiaque _analyseur = AnalyseurCardiaque();
  int? _patientId;
  bool _demarre = false;
  EtatMontre? _etat;
  List<MesureCardiaque> _mesures = [];
  DateTime? _derniereLecture;
  String? _erreur;
  bool _lecture = false;
  Timer? _minuterie;

  /// Un « Ça va ? » est à l'écran (une seule alerte à la fois).
  bool alerteOuverte = false;

  /// Alertes cardiaques à confirmer (« Ça va ? »).
  Stream<AlerteCardiaque> get alertes => _alertes.stream;

  /// Messages d'information (nouveaux seuils, simulation...).
  Stream<String> get messages => _messages.stream;

  AnalyseurCardiaque get analyseur => _analyseur;
  int? get patientId => _patientId;
  bool get demarre => _demarre;

  /// null : recherche de la montre en cours.
  EtatMontre? get etat => _etat;
  bool get connectee => _etat == EtatMontre.connectee;
  List<MesureCardiaque> get mesures => _mesures;
  DateTime? get derniereLecture => _derniereLecture;
  String? get erreur => _erreur;
  bool get lecture => _lecture;
  SeuilsCardiaques get seuils => _analyseur.seuils;

  MesureCardiaque? get derniere => _mesures.isEmpty ? null : _mesures.last;

  EtatRythme? get etatRythme {
    final MesureCardiaque? m = derniere;
    return m == null ? null : _analyseur.seuils.evaluer(m.bpm);
  }

  /// Ouverture de l'espace patient : courbe et seuils depuis la base, puis
  /// connexion à la montre et synchro toutes les 30 s.
  Future<void> demarrer(int patientId) async {
    if (_demarre && _patientId == patientId) {
      return;
    }
    if (_demarre) {
      await arreter();
    }
    _demarre = true;
    _patientId = patientId;
    _analyseur = AnalyseurCardiaque();
    notifyListeners();
    await _chargerBase();
    await connecter();
    _minuterie?.cancel();
    _minuterie = Timer.periodic(frequence, (_) => lire());
  }

  /// Déconnexion du patient.
  Future<void> arreter() async {
    _demarre = false;
    _minuterie?.cancel();
    _minuterie = null;
    _patientId = null;
    _mesures = [];
    _etat = null;
    _derniereLecture = null;
    _erreur = null;
    alerteOuverte = false;
    notifyListeners();
    await montre.deconnecter();
  }

  Future<void> _chargerBase() async {
    final int? pid = _patientId;
    if (pid == null) {
      return;
    }
    try {
      _analyseur.seuils = await _rythme.seuils(pid);
      _mesures = await _rythme.historique(pid, periode: periode);
    } catch (e) {
      _erreur = 'Base de données indisponible : $e';
    }
    notifyListeners();
  }

  /// Cherche la montre (déjà connectée à Mibro Fit, appairée ou par scan)
  /// et s'y connecte en Bluetooth.
  Future<void> connecter() async {
    if (!_demarre) {
      return;
    }
    _etat = null;
    notifyListeners();
    final EtatMontre e = await montre.connecter();
    if (!_demarre) {
      return;
    }
    _etat = e;
    notifyListeners();
    if (e == EtatMontre.connectee) {
      await lire(premiere: true);
    }
  }

  /// Lit les relevés de la montre, les enregistre et analyse les nouveaux.
  /// [premiere] : l'historique ancien ne déclenche pas d'alerte.
  Future<void> lire({bool premiere = false}) async {
    // Montre déconnectée : mesures() tente une reconnexion.
    if (!_demarre ||
        _lecture ||
        (_etat != EtatMontre.connectee && _etat != EtatMontre.deconnectee)) {
      return;
    }
    _lecture = true;
    notifyListeners();
    try {
      final List<MesureCardiaque> res = await montre.mesures(periode: periode);
      // Synchronisation : mesures → base (médecin), seuils ← base (médecin).
      final List<MesureCardiaque>? base = await _enregistrer(res);
      final bool nouveauxSeuils = await _rechargerSeuils();
      final List<MesureCardiaque> simulees = [];
      for (final MesureCardiaque m in _mesures) {
        if (m.simulee) {
          simulees.add(m);
        }
      }
      _mesures = base ??
          ([...res, ...simulees]
            ..sort((MesureCardiaque a, MesureCardiaque b) => a.date.compareTo(b.date)));
      _derniereLecture = DateTime.now();
      _etat = montre.etat;
      _erreur = null;
      if (nouveauxSeuils && !premiere) {
        appliquerSeuils(nouveaux: true);
        return;
      }
      if (premiere) {
        _publier(_analyseur.reevaluer(res));
        return;
      }
      for (final MesureCardiaque m in res) {
        final AlerteCardiaque? alerte = _analyseur.analyser(m);
        if (alerte != null) {
          _publier(alerte);
          break;
        }
      }
    } catch (e) {
      _etat = montre.etat;
      _erreur = 'Synchronisation impossible : $e';
    } finally {
      _lecture = false;
      notifyListeners();
    }
  }

  void _publier(AlerteCardiaque? alerte) {
    if (alerte != null && !alerteOuverte) {
      _alertes.add(alerte);
    }
  }

  Future<List<MesureCardiaque>?> _enregistrer(List<MesureCardiaque> mesures) async {
    final int? pid = _patientId;
    if (pid == null) {
      return null;
    }
    await _rythme.enregistrer(pid, mesures);
    return _rythme.historique(pid, periode: periode);
  }

  Future<bool> _rechargerSeuils() async {
    final int? pid = _patientId;
    if (pid == null) {
      return false;
    }
    final SeuilsCardiaques s = await _rythme.seuils(pid);
    final SeuilsCardiaques avant = _analyseur.seuils;
    if (s.min == avant.min && s.max == avant.max) {
      return false;
    }
    _analyseur.seuils = s;
    return true;
  }

  /// Nouveaux seuils du médecin ou « Reprendre » : pause levée, dernière
  /// mesure comparée tout de suite ; sinon un message explique pourquoi.
  void appliquerSeuils({bool nouveaux = false}) {
    final AlerteCardiaque? alerte = _analyseur.seuilsModifies(_mesures);
    notifyListeners();
    if (alerte != null) {
      _publier(alerte);
      return;
    }
    _messages.add('${nouveaux ? 'Nouveaux seuils du médecin · ' : ''}${_sansAlerte()}');
  }

  String _sansAlerte() {
    final MesureCardiaque? der = derniere;
    if (der == null) {
      return 'Aucune mesure de la montre pour l\'instant';
    }
    if (DateTime.now().difference(der.date) > _analyseur.fraicheur) {
      return 'Dernière mesure trop ancienne : lancez une mesure sur la montre';
    }
    final SeuilsCardiaques s = _analyseur.seuils;
    return '${der.bpm} bpm : dans les seuils (${s.min}–${s.max}), pas d\'alerte';
  }

  void reprendre() {
    _analyseur.reprendre();
    appliquerSeuils();
  }

  /// « Je vais bien » ou alerte traitée.
  void suspendre() {
    _analyseur.suspendre();
    notifyListeners();
  }

  /// Mode démo : 2 mesures anormales d'affilée → même chaîne qu'une vraie
  /// mesure. Renvoie un message si aucune alerte ne part.
  Future<String?> simuler(int bpm) async {
    final DateTime maintenant = DateTime.now();
    final List<MesureCardiaque> deux = [
      MesureCardiaque(
        bpm: bpm - 3,
        date: maintenant.subtract(const Duration(seconds: 30)),
        source: 'Simulation',
        simulee: true,
      ),
      MesureCardiaque(bpm: bpm, date: maintenant, source: 'Simulation', simulee: true),
    ];
    final List<MesureCardiaque>? base = await _enregistrer(deux);
    _mesures = base ?? [..._mesures, ...deux];
    notifyListeners();
    for (final MesureCardiaque m in deux) {
      final AlerteCardiaque? alerte = _analyseur.analyser(m);
      if (alerte != null) {
        _publier(alerte);
        return null;
      }
    }
    return _analyseur.enPause
        ? 'Alertes en pause (15 min après « Je vais bien »)'
        : '$bpm bpm : dans les seuils, pas d\'alerte';
  }

  /// Gravité d'un appel vocal : urgente, ou selon le dernier rythme s'il
  /// est déjà hors seuils.
  Gravite graviteVocale() {
    final MesureCardiaque? der = derniere;
    if (der != null && _analyseur.seuils.evaluer(der.bpm) != EtatRythme.normal) {
      return AnalyseurCardiaque.graviteDe(der.bpm);
    }
    return Gravite.urgente;
  }

  /// Crée l'intervention pour le patient (GPS, sinon position de démo).
  /// Renvoie le résultat du dispatch et si la position est celle de démo.
  Future<(ResultatDispatch, bool)> envoyerAmbulance(Gravite gravite) async {
    final int? pid = _patientId;
    if (pid == null) {
      throw const DispatchException(
        'Connectez-vous avec le compte du patient qui porte la montre',
      );
    }
    final DispatchController ctrl = DispatchController.instance;
    LatLng position = DispatchManager.centreZone;
    bool demo = true;
    try {
      final LatLng p = await ctrl.gps.positionActuelle();
      if (DispatchManager.dansZone(p)) {
        position = p;
        demo = false;
      }
    } on DispatchException {
      // GPS indisponible : position de démonstration (Sousse)
    }
    final ResultatDispatch r = await ctrl.creerDepuisAlerte(
      patientId: pid,
      position: position,
      gravite: gravite,
    );
    return (r, demo);
  }
}
