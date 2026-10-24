import 'dart:convert';

import 'package:flutter/services.dart';

/// Clés Cloudflare Turnstile (captcha), lues au démarrage depuis
/// assets/config/turnstile.json (fichier ignoré par Git : ne jamais pousser
/// la clé secrète). Modèle : assets/config/turnstile.example.json
///
/// Sans ce fichier, l'app utilise les clés de TEST officielles de Cloudflare :
/// la case « Vérifiez que vous êtes humain » s'affiche, il faut la cocher,
/// et la vérification passe toujours (bandeau « test » de Cloudflare).
class TurnstileConfig {
  TurnstileConfig._();

  static const String _fichier = 'assets/config/turnstile.json';

  /// Clé de test « défi interactif » : affiche la case à cocher.
  static const String cleSiteTest = '3x00000000000000000000FF';
  static const String cleSecreteTest = '1x0000000000000000000000000000000AA';

  static String cleSite = cleSiteTest;
  static String cleSecrete = cleSecreteTest;

  /// Adresse sous laquelle le widget est chargé : sur Android et iOS elle
  /// doit faire partie des domaines déclarés pour le widget chez Cloudflare.
  static String baseUrl = 'http://localhost/';

  static bool get modeTest => cleSite == cleSiteTest;

  /// Captcha exigé (connexion, mot de passe oublié). Mis à false uniquement
  /// dans les tests (`flutter test` n'a pas de WebView pour afficher le
  /// widget Cloudflare).
  static bool actif = true;

  /// À appeler une fois dans main() avant runApp().
  static Future<void> charger() async {
    try {
      final String brut = await rootBundle.loadString(_fichier);
      final Object? json = jsonDecode(brut);
      if (json is Map<String, dynamic>) {
        final String site = _lire(json, 'TURNSTILE_SITE_KEY');
        final String secret = _lire(json, 'TURNSTILE_SECRET_KEY');
        if (site.isNotEmpty && secret.isNotEmpty) {
          cleSite = site;
          cleSecrete = secret;
        }
        final String url = _lire(json, 'TURNSTILE_BASE_URL');
        if (url.isNotEmpty) {
          baseUrl = url;
        }
      }
    } catch (_) {
      // Fichier absent ou invalide : clés de test.
    }
  }

  static String _lire(Map<String, dynamic> json, String cle) {
    final Object? valeur = json[cle];
    return valeur is String ? valeur.trim() : '';
  }
}
