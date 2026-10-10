import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../domain/appel_aide.dart';
import 'protection_vocale_service.dart';

enum EtatEcoute {
  arretee('Écoute vocale désactivée'),
  demarrage('Démarrage du micro…'),
  ecoute('À l\'écoute : dites « help » ou « au secours »'),
  appelDetecte('Appel à l\'aide détecté'),
  indisponible('Reconnaissance vocale indisponible sur cet appareil'),
  refusee('Micro non autorisé : autorisez-le pour VitalWatch');

  const EtatEcoute(this.libelle);

  final String libelle;
}

typedef EcouteurAppelAide = void Function(AppelAide appel);

/// Écoute vocale continue (package speech_to_text, reconnaissance vocale du
/// téléphone) tant qu'un écran est abonné : application au premier plan, ou
/// partout (arrière-plan, écran verrouillé) quand la protection permanente
/// est active ([ProtectionVocale], service de premier plan Android).
/// La reconnaissance Android s'arrête après quelques secondes de silence :
/// elle est relancée automatiquement.
///
/// Un seul micro : service unique, seul le dernier écran abonné (celui du
/// dessus) reçoit les appels à l'aide.
class EcouteVocaleService extends ChangeNotifier {
  EcouteVocaleService._();

  static final EcouteVocaleService instance = EcouteVocaleService._();

  final SpeechToText _stt = SpeechToText();
  final List<EcouteurAppelAide> _abonnes = [];
  AppLifecycleListener? _cycle;
  Timer? _relance;
  bool _initialise = false;
  bool _lancement = false;
  bool _activee = true;
  bool _suspendue = false;
  bool _premierPlan = true;
  bool _permanente = false;
  bool _restauree = false;
  int _erreurs = 0;
  String? _langue;
  EtatEcoute _etat = EtatEcoute.arretee;
  String _entendu = '';

  EtatEcoute get etat => _etat;

  /// Dernière phrase entendue.
  String get entendu => _entendu;

  /// Interrupteur « Alerte vocale » (pour toute la session).
  bool get activee => _activee;

  /// Protection « même écran verrouillé » active.
  bool get permanente => _permanente;

  /// Application visible (sinon : arrière-plan ou écran verrouillé).
  bool get premierPlan => _premierPlan;

  bool get _doitEcouter =>
      _activee && _abonnes.isNotEmpty && !_suspendue && (_premierPlan || _permanente);

  /// Appelé depuis initState / dispose : la mise à jour (qui notifie les
  /// écrans) est différée après la construction de l'arbre de widgets.
  void abonner(EcouteurAppelAide ecouteur) {
    _abonnes.add(ecouteur);
    _cycle ??= AppLifecycleListener(onStateChange: _cycleDeVie);
    scheduleMicrotask(_mettreAJour);
  }

  void desabonner(EcouteurAppelAide ecouteur) {
    _abonnes.remove(ecouteur);
    if (_abonnes.isEmpty) {
      // Déconnexion du patient : plus personne n'écoute, on coupe le
      // service ; la préférence est gardée et relue à la prochaine connexion.
      _restauree = false;
      if (_permanente) {
        _permanente = false;
        unawaited(ProtectionVocale.instance.arreter());
      }
    }
    scheduleMicrotask(_mettreAJour);
  }

  /// Active ou coupe la protection permanente. Renvoie un message d'erreur
  /// ou null. À appeler app au premier plan (exigence d'Android).
  Future<String?> activerPermanente(bool oui) async {
    if (!oui) {
      _permanente = false;
      notifyListeners();
      await ProtectionVocale.instance.arreter();
      await ProtectionVocale.instance.enregistrerPreference(false);
      _mettreAJour();
      return null;
    }
    // Micro autorisé d'abord : Android refuse un service « micro » sinon.
    _activee = true;
    await _demarrer();
    if (!_initialise) {
      return _etat == EtatEcoute.refusee
          ? 'Autorisez le micro pour activer la protection'
          : 'Reconnaissance vocale indisponible sur ce téléphone';
    }
    bool gps = false;
    try {
      final LocationPermission p = await Geolocator.checkPermission();
      gps = p == LocationPermission.always || p == LocationPermission.whileInUse;
    } catch (_) {
      gps = false;
    }
    final String? erreur = await ProtectionVocale.instance.demarrer(localisation: gps);
    if (erreur != null) {
      return 'Protection impossible : $erreur';
    }
    _permanente = true;
    notifyListeners();
    await ProtectionVocale.instance.enregistrerPreference(true);
    _mettreAJour();
    return null;
  }

  /// Au premier affichage de l'espace patient : réactive la protection si
  /// le patient l'avait laissée activée.
  Future<void> restaurerPermanente() async {
    if (_restauree) {
      return;
    }
    _restauree = true;
    if (await ProtectionVocale.instance.preference()) {
      await activerPermanente(true);
    }
  }

  void activer(bool oui) {
    _activee = oui;
    _erreurs = 0;
    if (!oui && _permanente) {
      unawaited(activerPermanente(false));
    }
    _mettreAJour();
  }

  /// Après le compte à rebours (annulé ou alerte envoyée).
  void reprendre() {
    _suspendue = false;
    _mettreAJour();
  }

  /// Après un refus du micro ou une indisponibilité.
  void reessayer() {
    _erreurs = 0;
    _mettreAJour();
  }

  void _cycleDeVie(AppLifecycleState s) {
    // inactive (fenêtre de permission, volet de notifications) : on continue.
    if (s == AppLifecycleState.resumed) {
      _premierPlan = true;
      _mettreAJour();
    } else if (s == AppLifecycleState.paused ||
        s == AppLifecycleState.hidden ||
        s == AppLifecycleState.detached) {
      // Protection permanente : l'écoute continue (service de premier plan).
      _premierPlan = false;
      _mettreAJour();
    }
  }

  void _mettreAJour() {
    if (_doitEcouter) {
      unawaited(_demarrer());
    } else {
      unawaited(_arreter());
    }
  }

  Future<void>? _initEnCours;

  Future<void> _demarrer() async {
    if (!_initialise) {
      // Une seule initialisation à la fois (abonnement + restauration).
      final Future<void> init = _initEnCours ??= _initialiser();
      await init;
      _initEnCours = null;
      if (!_initialise) {
        return;
      }
    }
    await _ecouter();
  }

  Future<void> _initialiser() async {
    _changer(EtatEcoute.demarrage);
    bool ok = false;
    try {
      // Demande l'autorisation du micro au premier lancement.
      ok = await _stt.initialize(onStatus: _statut, onError: _erreur);
    } catch (_) {
      ok = false;
    }
    if (!ok) {
      bool micro = true;
      try {
        micro = await _stt.hasPermission;
      } catch (_) {
        micro = true;
      }
      _changer(micro ? EtatEcoute.indisponible : EtatEcoute.refusee);
      return;
    }
    _langue = await _choisirLangue();
    _initialise = true;
  }

  /// Français si disponible (« au secours », « à l'aide ») ; « help » est
  /// reconnu aussi en français.
  Future<String?> _choisirLangue() async {
    try {
      final LocaleName? systeme = await _stt.systemLocale();
      if (systeme != null && systeme.localeId.toLowerCase().startsWith('fr')) {
        return systeme.localeId;
      }
      final List<LocaleName> langues = await _stt.locales();
      for (final LocaleName l in langues) {
        if (l.localeId.toLowerCase().startsWith('fr')) {
          return l.localeId;
        }
      }
      return systeme?.localeId;
    } catch (_) {
      return null;
    }
  }

  Future<void> _ecouter() async {
    if (!_doitEcouter || !_initialise || _lancement || _stt.isListening) {
      return;
    }
    _lancement = true;
    try {
      await _stt.listen(
        onResult: _resultat,
        listenOptions: SpeechListenOptions(
          partialResults: true,
          cancelOnError: false,
          listenMode: ListenMode.dictation,
          listenFor: const Duration(minutes: 2),
          pauseFor: const Duration(seconds: 30),
          localeId: _langue,
        ),
      );
      _changer(EtatEcoute.ecoute);
    } catch (_) {
      _relancerApresErreur();
    } finally {
      _lancement = false;
    }
  }

  Future<void> _arreter() async {
    _relance?.cancel();
    if (_etat == EtatEcoute.indisponible || _etat == EtatEcoute.refusee) {
      if (!_activee || _abonnes.isEmpty) {
        _changer(EtatEcoute.arretee);
      }
      return;
    }
    if (!_suspendue) {
      _changer(EtatEcoute.arretee);
    }
    if (_initialise && _stt.isListening) {
      try {
        await _stt.cancel();
      } catch (_) {
        // déjà arrêtée
      }
    }
  }

  void _statut(String statut) {
    if (statut == 'listening') {
      _changer(EtatEcoute.ecoute);
    } else if (statut == 'done' || statut == 'notListening') {
      // Fin de session (silence, durée max) : on relance.
      _relancer(const Duration(milliseconds: 600));
    }
  }

  void _erreur(SpeechRecognitionError e) {
    if (e.errorMsg == 'error_insufficient_permissions' ||
        e.errorMsg == 'error_permission') {
      _relance?.cancel();
      _changer(EtatEcoute.refusee);
      return;
    }
    if (e.errorMsg == 'error_language_not_supported' ||
        e.errorMsg == 'error_language_unavailable') {
      _langue = null; // langue du téléphone
    }
    // error_no_match / error_speech_timeout : simple silence.
    if (e.errorMsg == 'error_no_match' || e.errorMsg == 'error_speech_timeout') {
      _relancer(const Duration(milliseconds: 600));
    } else {
      _relancerApresErreur();
    }
  }

  /// Erreurs répétées : attente croissante (1 s, 2 s, 4 s... 30 s max).
  void _relancerApresErreur() {
    _erreurs++;
    final int secondes = _erreurs >= 5 ? 30 : 1 << (_erreurs - 1);
    _relancer(Duration(seconds: secondes));
  }

  void _relancer(Duration delai) {
    _relance?.cancel();
    if (!_doitEcouter) {
      return;
    }
    _relance = Timer(delai, () => unawaited(_ecouter()));
  }

  void _resultat(SpeechRecognitionResult r) {
    if (!_doitEcouter) {
      return;
    }
    _erreurs = 0;
    _entendu = r.recognizedWords;
    notifyListeners();
    final String? mot = DetecteurAppelAide.detecter(_entendu);
    if (mot == null || _abonnes.isEmpty) {
      return;
    }
    // Le compte à rebours est affiché : micro coupé jusqu'à reprendre().
    _suspendue = true;
    _relance?.cancel();
    _changer(EtatEcoute.appelDetecte);
    unawaited(_stt.cancel());
    _abonnes.last(AppelAide(motCle: mot, texte: _entendu, date: DateTime.now()));
  }

  void _changer(EtatEcoute e) {
    if (_etat != e) {
      _etat = e;
      notifyListeners();
    }
  }
}
