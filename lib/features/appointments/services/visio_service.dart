import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';

/// Téléconsultation : création des liens de salle Jitsi Meet.
///
/// L'appel s'ouvre DANS l'application (écran AppelVideoScreen, WebView).
///
/// Serveur : meet.jit.si oblige désormais le premier participant à se
/// connecter avec Google/GitHub (impossible dans une WebView). On utilise donc
/// par défaut un serveur Jitsi public SANS connexion. Pour en changer, créer
/// assets/config/visio.json : { "JITSI_SERVER": "https://mon-serveur-jitsi" }
class VisioService {
  VisioService._();

  static const String _fichier = 'assets/config/visio.json';
  static String serveur = 'https://meet.ffmuc.net';
  static bool _charge = false;

  static final Random _random = Random.secure();
  static const String _alphabet = 'abcdefghijkmnpqrstuvwxyz23456789';

  /// Lit assets/config/visio.json une fois (facultatif).
  static Future<void> chargerConfig() async {
    if (_charge) {
      return;
    }
    _charge = true;
    try {
      final Object? json = jsonDecode(await rootBundle.loadString(_fichier));
      if (json is Map<String, dynamic>) {
        final Object? s = json['JITSI_SERVER'];
        if (s is String && s.trim().startsWith('https://')) {
          serveur = s.trim().replaceAll(RegExp(r'/+$'), '');
        }
      }
    } catch (_) {
      // Pas de fichier : serveur par défaut.
    }
  }

  /// Nouveau lien de salle privée : https://serveur/VitalWatch-k3m9x2pq7d4a
  static String nouveauLien() {
    final StringBuffer sb = StringBuffer();
    for (int i = 0; i < 12; i++) {
      sb.write(_alphabet[_random.nextInt(_alphabet.length)]);
    }
    return '$serveur/VitalWatch-$sb';
  }

  /// Nom de la salle (dernier segment du lien), quel que soit le serveur
  /// d'origine du lien (anciens liens meet.jit.si compris).
  static String salle(String lien) {
    final Uri? u = Uri.tryParse(lien);
    final String brut = (u != null && u.pathSegments.isNotEmpty)
        ? u.pathSegments.last
        : lien.split('/').last;
    final String propre = brut.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '');
    return propre.isEmpty ? 'VitalWatch-salle' : propre;
  }

  /// URL ouverte dans l'application : salle sur le serveur configuré,
  /// sans page d'accueil, sans redirection vers l'app Jitsi, caméra et micro actifs.
  static String urlAppel(String lien, {required String nom}) {
    final String n = Uri.encodeComponent('"$nom"');
    return '$serveur/${salle(lien)}'
        '#config.prejoinConfig.enabled=false'
        '&config.prejoinPageEnabled=false'
        '&config.disableDeepLinking=true'
        '&config.startWithAudioMuted=false'
        '&config.startWithVideoMuted=false'
        '&userInfo.displayName=$n';
  }
}
