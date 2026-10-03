import 'dart:convert';

import 'package:flutter/services.dart';

/// Clés EmailJS, lues au démarrage depuis assets/config/emailjs.json
/// (fichier ignoré par Git : ne jamais pousser les clés).
/// Modèle vide : assets/config/emailjs.example.json
class EmailConfig {
  EmailConfig._();

  static const String _fichier = 'assets/config/emailjs.json';

  // Valeurs par défaut : --dart-define (optionnel), sinon vides.
  static String serviceId = const String.fromEnvironment('EMAILJS_SERVICE_ID');
  static String templateId = const String.fromEnvironment('EMAILJS_TEMPLATE_ID');
  static String publicKey = const String.fromEnvironment('EMAILJS_PUBLIC_KEY');
  static String privateKey = const String.fromEnvironment('EMAILJS_PRIVATE_KEY');

  static bool get estConfigure =>
      serviceId.isNotEmpty && templateId.isNotEmpty && publicKey.isNotEmpty;

  /// À appeler une fois dans main() avant runApp().
  static Future<void> charger() async {
    try {
      final String brut = await rootBundle.loadString(_fichier);
      final Object? json = jsonDecode(brut);
      if (json is Map<String, dynamic>) {
        serviceId = _lire(json, 'EMAILJS_SERVICE_ID', serviceId);
        templateId = _lire(json, 'EMAILJS_TEMPLATE_ID', templateId);
        publicKey = _lire(json, 'EMAILJS_PUBLIC_KEY', publicKey);
        privateKey = _lire(json, 'EMAILJS_PRIVATE_KEY', privateKey);
      }
    } catch (_) {
      // Fichier absent ou invalide : l'envoi par mail reste désactivé.
    }
  }

  static String _lire(Map<String, dynamic> json, String cle, String defaut) {
    final Object? valeur = json[cle];
    if (valeur is String && valeur.trim().isNotEmpty) {
      return valeur.trim();
    }
    return defaut;
  }
}
