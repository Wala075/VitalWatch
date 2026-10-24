import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

/// Résumé IA du compte-rendu de consultation (API Gemini de Google).
///
/// Clé lue dans assets/config/gemini.json (à ne jamais pousser sur GitHub) :
///   { "GEMINI_API_KEY": "...", "GEMINI_MODEL": "gemini-2.5-flash" }
/// Clé gratuite : https://aistudio.google.com/apikey
///
/// Sans clé (ou sans réseau), un résumé local simple est produit pour que
/// l'application reste utilisable en démo.
class ResumeIaService {
  ResumeIaService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const String _fichier = 'assets/config/gemini.json';
  static String _cle = const String.fromEnvironment('GEMINI_API_KEY');
  static String _modele = 'gemini-2.5-flash';
  static bool _charge = false;

  static Future<void> _chargerConfig() async {
    if (_charge) {
      return;
    }
    _charge = true;
    try {
      final Object? json = jsonDecode(await rootBundle.loadString(_fichier));
      if (json is Map<String, dynamic>) {
        final Object? cle = json['GEMINI_API_KEY'];
        final Object? modele = json['GEMINI_MODEL'];
        if (cle is String && cle.trim().isNotEmpty) {
          _cle = cle.trim();
        }
        if (modele is String && modele.trim().isNotEmpty) {
          _modele = modele.trim();
        }
      }
    } catch (_) {
      // Pas de fichier : résumé local.
    }
  }

  /// Renvoie le résumé et sa source (« Gemini » ou « résumé local »).
  Future<ResumeIa> resumer({
    required String motif,
    required String diagnostic,
    required String compteRendu,
  }) async {
    await _chargerConfig();
    if (_cle.isNotEmpty) {
      try {
        final String texte = await _appelGemini(motif, diagnostic, compteRendu);
        if (texte.trim().isNotEmpty) {
          return ResumeIa(texte.trim(), ia: true);
        }
      } catch (_) {
        // On retombe sur le résumé local.
      }
    }
    return ResumeIa(
      resumeLocal(motif: motif, diagnostic: diagnostic, compteRendu: compteRendu),
      ia: false,
    );
  }

  Future<String> _appelGemini(
    String motif,
    String diagnostic,
    String compteRendu,
  ) async {
    final String prompt = '''
Tu es un assistant médical. Résume ce compte-rendu de consultation en français,
en 3 à 5 puces courtes pour le patient : motif, diagnostic, traitement / conseils,
suivi à prévoir. N'invente aucune information absente du texte.

Motif : $motif
Diagnostic : $diagnostic
Compte-rendu : $compteRendu
''';
    final http.Response rep = await _client
        .post(
          Uri.parse(
            'https://generativelanguage.googleapis.com/v1beta/models/'
            '$_modele:generateContent',
          ),
          headers: {
            'Content-Type': 'application/json',
            'x-goog-api-key': _cle,
          },
          body: jsonEncode({
            'contents': [
              {
                'parts': [
                  {'text': prompt},
                ],
              },
            ],
          }),
        )
        .timeout(const Duration(seconds: 20));
    if (rep.statusCode != 200) {
      throw Exception('Gemini ${rep.statusCode}');
    }
    final Object? json = jsonDecode(utf8.decode(rep.bodyBytes));
    if (json is! Map<String, dynamic>) {
      return '';
    }
    final Object? candidats = json['candidates'];
    if (candidats is! List || candidats.isEmpty) {
      return '';
    }
    final Object? contenu = (candidats.first as Map<String, dynamic>)['content'];
    if (contenu is! Map<String, dynamic>) {
      return '';
    }
    final Object? parts = contenu['parts'];
    if (parts is! List) {
      return '';
    }
    final StringBuffer sb = StringBuffer();
    for (final Object? p in parts) {
      if (p is Map<String, dynamic> && p['text'] is String) {
        sb.write(p['text'] as String);
      }
    }
    return sb.toString();
  }

  /// Résumé sans IA : motif, diagnostic et les 2 premières phrases.
  static String resumeLocal({
    required String motif,
    required String diagnostic,
    required String compteRendu,
  }) {
    final List<String> phrases = compteRendu
        .split(RegExp(r'(?<=[.!?])\s+'))
        .map((String s) => s.trim())
        .where((String s) => s.isNotEmpty)
        .toList();
    final StringBuffer sb = StringBuffer()
      ..writeln('• Motif : ${motif.trim()}')
      ..writeln('• Diagnostic : ${diagnostic.trim().isEmpty ? '-' : diagnostic.trim()}');
    for (final String p in phrases.take(2)) {
      sb.writeln('• $p');
    }
    return sb.toString().trim();
  }
}

class ResumeIa {
  const ResumeIa(this.texte, {required this.ia});

  final String texte;

  /// true : produit par Gemini ; false : résumé local.
  final bool ia;
}
