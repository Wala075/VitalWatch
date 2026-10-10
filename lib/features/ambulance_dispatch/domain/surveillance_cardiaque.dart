import 'models/intervention.dart';

/// Une mesure de fréquence cardiaque (montre via Health Connect, ou simulée).
class MesureCardiaque {
  const MesureCardiaque({
    required this.bpm,
    required this.date,
    this.source = '',
    this.simulee = false,
  });

  final int bpm;
  final DateTime date;
  final String source;
  final bool simulee;
}

enum EtatRythme {
  normal('Normal'),
  eleve('Trop élevé'),
  bas('Trop bas');

  const EtatRythme(this.libelle);

  final String libelle;
}

/// Seuils d'alerte (bpm). Par défaut : < 45 ou > 120 au repos.
class SeuilsCardiaques {
  const SeuilsCardiaques({this.min = 45, this.max = 120});

  final int min;
  final int max;

  EtatRythme evaluer(int bpm) {
    if (bpm > max) {
      return EtatRythme.eleve;
    }
    if (bpm < min) {
      return EtatRythme.bas;
    }
    return EtatRythme.normal;
  }
}

/// Alerte à confirmer avant l'envoi d'une ambulance.
class AlerteCardiaque {
  const AlerteCardiaque({
    required this.mesure,
    required this.etat,
    required this.gravite,
  });

  final MesureCardiaque mesure;
  final EtatRythme etat;
  final Gravite gravite;
}

/// Règles métier de la surveillance cardiaque :
/// - une alerte exige [mesuresConsecutives] mesures anormales d'affilée
///   (une valeur isolée, souvent un artefact du capteur, ne suffit pas) ;
/// - chaque mesure n'est analysée qu'une fois (horodatage croissant) ;
/// - après « Je vais bien » ou une alerte envoyée, pause de [pause] ;
/// - au changement de seuils par l'utilisateur, la pause est levée et la
///   dernière mesure récente (moins de [fraicheur]) est comparée tout de
///   suite aux nouveaux seuils, quels qu'ils soient ;
/// - gravité critique si ≥ 150 ou ≤ 40 bpm, urgente sinon.
class AnalyseurCardiaque {
  AnalyseurCardiaque({
    this.seuils = const SeuilsCardiaques(),
    this.mesuresConsecutives = 2,
    this.pause = const Duration(minutes: 15),
    this.fraicheur = const Duration(minutes: 30),
  });

  SeuilsCardiaques seuils;
  final int mesuresConsecutives;
  final Duration pause;
  final Duration fraicheur;

  final List<MesureCardiaque> _anormales = [];
  DateTime? _derniere;
  DateTime? _silenceJusqua;

  /// Nombre de mesures anormales d'affilée (affiché dans l'écran).
  int get anomaliesEnCours => _anormales.length;

  bool get enPause {
    final DateTime? fin = _silenceJusqua;
    return fin != null && DateTime.now().isBefore(fin);
  }

  /// Fin de la pause en cours (null si pas de pause).
  DateTime? get finPause => enPause ? _silenceJusqua : null;

  /// Analyse une nouvelle mesure ; renvoie l'alerte à déclencher ou null.
  AlerteCardiaque? analyser(MesureCardiaque m) {
    final DateTime? precedente = _derniere;
    if (precedente != null && !m.date.isAfter(precedente)) {
      return null; // déjà analysée
    }
    _derniere = m.date;

    final EtatRythme etat = seuils.evaluer(m.bpm);
    if (etat == EtatRythme.normal) {
      _anormales.clear();
      return null;
    }
    _anormales.add(m);
    if (enPause || _anormales.length < mesuresConsecutives) {
      return null;
    }
    _anormales.clear();
    return AlerteCardiaque(mesure: m, etat: etat, gravite: graviteDe(m.bpm));
  }

  /// Réévalue tout de suite les dernières mesures (triées par date) avec les
  /// seuils actuels : sans cela, un nouveau seuil n'agit qu'après
  /// [mesuresConsecutives] nouvelles mesures de la montre (~5 min chacune).
  /// Seules les mesures de moins de [fraicheur] comptent.
  AlerteCardiaque? reevaluer(List<MesureCardiaque> mesures, {DateTime? maintenant}) {
    final DateTime now = maintenant ?? DateTime.now();
    for (final MesureCardiaque m in mesures) {
      final DateTime? d = _derniere;
      if (d == null || m.date.isAfter(d)) {
        _derniere = m.date;
      }
    }
    _anormales.clear();
    for (int i = mesures.length - 1; i >= 0; i--) {
      final MesureCardiaque m = mesures[i];
      if (now.difference(m.date) > fraicheur || seuils.evaluer(m.bpm) == EtatRythme.normal) {
        break;
      }
      _anormales.insert(0, m);
    }
    if (enPause || _anormales.length < mesuresConsecutives) {
      return null;
    }
    final MesureCardiaque der = _anormales.last;
    _anormales.clear();
    return AlerteCardiaque(mesure: der, etat: seuils.evaluer(der.bpm), gravite: graviteDe(der.bpm));
  }

  /// Seuils modifiés à la main : la pause est levée et la dernière mesure
  /// récente suffit (l'utilisateur a changé la règle lui-même ; le « Ça va ? »
  /// de 30 s reste là pour annuler). Null si cette mesure est dans les seuils,
  /// trop ancienne ou absente.
  AlerteCardiaque? seuilsModifies(List<MesureCardiaque> mesures, {DateTime? maintenant}) {
    _silenceJusqua = null;
    _anormales.clear();
    for (final MesureCardiaque m in mesures) {
      final DateTime? d = _derniere;
      if (d == null || m.date.isAfter(d)) {
        _derniere = m.date;
      }
    }
    if (mesures.isEmpty) {
      return null;
    }
    final MesureCardiaque der = mesures.last;
    final DateTime now = maintenant ?? DateTime.now();
    final EtatRythme etat = seuils.evaluer(der.bpm);
    if (now.difference(der.date) > fraicheur || etat == EtatRythme.normal) {
      return null;
    }
    return AlerteCardiaque(mesure: der, etat: etat, gravite: graviteDe(der.bpm));
  }

  /// « Je vais bien » ou alerte traitée : pas de nouvelle alerte pendant [pause].
  void suspendre() {
    _silenceJusqua = DateTime.now().add(pause);
    _anormales.clear();
  }

  /// Fin anticipée de la pause.
  void reprendre() {
    _silenceJusqua = null;
  }

  static Gravite graviteDe(int bpm) {
    if (bpm >= 150 || bpm <= 40) {
      return Gravite.critique;
    }
    return Gravite.urgente;
  }
}
