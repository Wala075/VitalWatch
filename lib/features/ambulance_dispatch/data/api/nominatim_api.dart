import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class AdresseTrouvee {
  const AdresseTrouvee({required this.libelle, required this.position});

  final String libelle;
  final LatLng position;
}

/// API Nominatim (OpenStreetMap) : adresse ↔ coordonnées GPS.
/// Règles d'usage : un User-Agent explicite et au plus 1 requête / seconde
/// (la recherche se lance sur validation, pas à chaque touche).
class NominatimApi {
  NominatimApi({http.Client? client}) : _client = client ?? http.Client();

  static const String _base = 'https://nominatim.openstreetmap.org';
  static const Map<String, String> _entetes = {
    'User-Agent': 'VitalWatch/1.0 (projet etudiant)',
    'Accept-Language': 'fr',
  };
  static const Duration _delai = Duration(seconds: 8);

  final http.Client _client;

  /// Géocodage : texte → liste de positions (Tunisie uniquement).
  Future<List<AdresseTrouvee>> rechercher(String texte) async {
    final String q = texte.trim();
    if (q.length < 3) {
      return [];
    }
    final Uri uri = Uri.parse('$_base/search').replace(queryParameters: {
      'q': q,
      'format': 'jsonv2',
      'limit': '6',
      'countrycodes': 'tn',
      'addressdetails': '1',
    });
    try {
      final http.Response rep = await _client.get(uri, headers: _entetes).timeout(_delai);
      if (rep.statusCode != 200) {
        return [];
      }
      final List<dynamic> json = jsonDecode(rep.body) as List<dynamic>;
      final List<AdresseTrouvee> res = [];
      for (final dynamic e in json) {
        final Map<String, dynamic> m = e as Map<String, dynamic>;
        res.add(AdresseTrouvee(
          libelle: _libelle(m),
          position: LatLng(
            double.parse(m['lat'] as String),
            double.parse(m['lon'] as String),
          ),
        ));
      }
      return res;
    } catch (_) {
      return [];
    }
  }

  /// Géocodage inverse : position → adresse lisible (null si indisponible).
  Future<String?> adresseDe(LatLng position) async {
    final Uri uri = Uri.parse('$_base/reverse').replace(queryParameters: {
      'lat': position.latitude.toStringAsFixed(6),
      'lon': position.longitude.toStringAsFixed(6),
      'format': 'jsonv2',
      'zoom': '18',
      'addressdetails': '1',
    });
    try {
      final http.Response rep = await _client.get(uri, headers: _entetes).timeout(_delai);
      if (rep.statusCode != 200) {
        return null;
      }
      final Map<String, dynamic> json = jsonDecode(rep.body) as Map<String, dynamic>;
      if (json.containsKey('error')) {
        return null;
      }
      return _libelle(json);
    } catch (_) {
      return null;
    }
  }

  /// « Rue, quartier, ville » plutôt que le display_name complet.
  String _libelle(Map<String, dynamic> m) {
    final Object? details = m['address'];
    if (details is Map<String, dynamic>) {
      final List<String> parties = [];
      final Object? numero = details['house_number'];
      final Object? rue = details['road'] ?? details['pedestrian'];
      if (rue is String) {
        parties.add(numero is String ? '$numero $rue' : rue);
      }
      for (final String cle in ['suburb', 'neighbourhood', 'quarter']) {
        final Object? v = details[cle];
        if (v is String && parties.length < 2) {
          parties.add(v);
          break;
        }
      }
      for (final String cle in ['city', 'town', 'village', 'municipality', 'county']) {
        final Object? v = details[cle];
        if (v is String) {
          parties.add(v);
          break;
        }
      }
      if (parties.isNotEmpty) {
        return parties.join(', ');
      }
    }
    final String complet = (m['display_name'] as String?) ?? 'Adresse inconnue';
    final List<String> morceaux = complet.split(', ');
    if (morceaux.length <= 3) {
      return complet;
    }
    return morceaux.sublist(0, 3).join(', ');
  }
}
