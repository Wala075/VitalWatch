import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../core/config/turnstile_config.dart';
import '../domain/protection_connexion.dart';

/// API REST Cloudflare Turnstile « siteverify » : vérifie que le jeton
/// renvoyé par le captcha est valide (une seule utilisation par jeton).
///
/// En production, cette vérification se fait sur un serveur pour garder la
/// clé secrète cachée. L'app n'a pas de serveur : la clé est lue depuis un
/// fichier ignoré par Git, comme les clés EmailJS.
class CaptchaApi {
  static final Uri _url =
      Uri.parse('https://challenges.cloudflare.com/turnstile/v0/siteverify');

  Future<VerificationCaptcha> verifier(String jeton) async {
    if (jeton.isEmpty) {
      return const VerificationCaptcha(false, ['missing-input-response']);
    }
    if (kIsWeb) {
      // Le navigateur bloque l'appel direct à Cloudflare (CORS) :
      // sur le web, le jeton reçu du widget est accepté tel quel.
      return const VerificationCaptcha(true, []);
    }
    try {
      final http.Response r = await http.post(
        _url,
        body: {'secret': TurnstileConfig.cleSecrete, 'response': jeton},
      ).timeout(const Duration(seconds: 10));
      final Object? json = jsonDecode(r.body);
      if (json is Map<String, dynamic>) {
        return VerificationCaptcha.depuisJson(json);
      }
      return const VerificationCaptcha(false, ['reponse-invalide']);
    } catch (_) {
      return const VerificationCaptcha(false, ['erreur-reseau']);
    }
  }
}
