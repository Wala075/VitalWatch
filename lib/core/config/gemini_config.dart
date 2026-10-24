import 'dart:convert';

import 'package:flutter/services.dart';

/// Clé de l'API Google Gemini (lecture complète de la CIN en arabe), lue au
/// démarrage depuis assets/config/gemini.json (fichier ignoré par Git).
/// Modèle : assets/config/gemini.example.json
/// Sans clé, le scan de CIN ne lit que le numéro (Google ML Kit).
class GeminiConfig {
  GeminiConfig._();

  static const String _fichier = 'assets/config/gemini.json';

  /// Alias qui suit toujours le dernier modèle Flash de Google.
  static const String modeleParDefaut = 'gemini-flash-latest';

  static String cleApi = '';
  static String modele = modeleParDefaut;

  static bool get estConfigure => cleApi.isNotEmpty;

  /// À appeler une fois dans main() avant runApp().
  static Future<void> charger() async {
    try {
      final String brut = await rootBundle.loadString(_fichier);
      final Object? json = jsonDecode(brut);
      if (json is Map<String, dynamic>) {
        cleApi = _lire(json, 'GEMINI_API_KEY');
        final String m = _lire(json, 'GEMINI_MODEL');
        if (m.isNotEmpty) {
          modele = m;
        }
      }
    } catch (_) {
      // Fichier absent ou invalide : lecture du numéro seulement (ML Kit).
    }
  }

  static String _lire(Map<String, dynamic> json, String cle) {
    final Object? valeur = json[cle];
    return valeur is String ? valeur.trim() : '';
  }
}
