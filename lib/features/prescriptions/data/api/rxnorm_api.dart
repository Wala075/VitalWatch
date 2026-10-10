import 'dart:convert';

import 'package:http/http.dart' as http;

/// API RxNorm de la NLM (gratuite, sans clé).
/// - rxcui.json?name=… : identifiant de l'ingrédient (DCI normalisée) ;
/// - rxcui/{id}/related.json?tty=SCD : produits cliniques (ingrédient +
///   dosage + forme), pour vérifier qu'un dosage existe.
/// RxNorm utilise les noms américains et ne connaît aucun prix.
/// (L'API d'interactions de la NLM a été arrêtée en 2024 : non utilisée.)
class RxNormApi {
  RxNormApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const String _base = 'https://rxnav.nlm.nih.gov/REST';
  static const Duration _delai = Duration(seconds: 10);

  /// Identifiant RxNorm de l'ingrédient, ou null s'il est inconnu.
  /// Lève une exception si l'API est injoignable.
  Future<String?> rxcuiIngredient(String nomAnglais) async {
    final Uri uri = Uri.parse('$_base/rxcui.json').replace(
      queryParameters: {'name': nomAnglais, 'search': '2'},
    );
    final http.Response r = await _client.get(uri).timeout(_delai);
    if (r.statusCode != 200) {
      throw http.ClientException('RxNorm ${r.statusCode}', uri);
    }
    final Object? json = jsonDecode(r.body);
    if (json is Map<String, dynamic>) {
      final Object? groupe = json['idGroup'];
      if (groupe is Map<String, dynamic>) {
        final Object? ids = groupe['rxnormId'];
        if (ids is List && ids.isNotEmpty) {
          return ids.first.toString();
        }
      }
    }
    return null;
  }

  /// Noms des produits cliniques de l'ingrédient
  /// (ex. « amlodipine 5 MG Oral Tablet »).
  Future<List<String>> produitsCliniques(String rxcui) async {
    final Uri uri = Uri.parse('$_base/rxcui/$rxcui/related.json').replace(
      queryParameters: {'tty': 'SCD'},
    );
    final http.Response r = await _client.get(uri).timeout(_delai);
    if (r.statusCode != 200) {
      throw http.ClientException('RxNorm ${r.statusCode}', uri);
    }
    final List<String> res = [];
    final Object? json = jsonDecode(r.body);
    if (json is! Map<String, dynamic>) {
      return res;
    }
    final Object? groupe = json['relatedGroup'];
    if (groupe is! Map<String, dynamic>) {
      return res;
    }
    final Object? concepts = groupe['conceptGroup'];
    if (concepts is! List) {
      return res;
    }
    for (final Object? c in concepts) {
      if (c is Map<String, dynamic>) {
        final Object? proprietes = c['conceptProperties'];
        if (proprietes is List) {
          for (final Object? p in proprietes) {
            if (p is Map<String, dynamic> && p['name'] is String) {
              res.add(p['name'] as String);
            }
          }
        }
      }
    }
    return res;
  }
}
