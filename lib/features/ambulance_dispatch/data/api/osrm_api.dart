import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../../domain/haversine.dart';

/// Trajet routier entre deux points.
class Itineraire {
  const Itineraire({
    required this.points,
    required this.distanceKm,
    required this.duree,
    this.estime = false,
  });

  final List<LatLng> points;
  final double distanceKm;
  final Duration duree;

  /// true : OSRM injoignable, tracé en ligne droite + durée estimée.
  final bool estime;
}

/// API OSRM (Open Source Routing Machine) : itinéraire routier + durée (ETA).
/// Serveur de démonstration public, sans clé.
class OsrmApi {
  OsrmApi({http.Client? client}) : _client = client ?? http.Client();

  static const String _base = 'https://router.project-osrm.org/route/v1/driving';
  static const Duration _delai = Duration(seconds: 8);

  final http.Client _client;

  Future<Itineraire> itineraire(LatLng depart, LatLng arrivee) async {
    // OSRM attend « longitude,latitude »
    final Uri uri = Uri.parse(
      '$_base/${depart.longitude},${depart.latitude};'
      '${arrivee.longitude},${arrivee.latitude}'
      '?overview=full&geometries=geojson',
    );
    try {
      final http.Response rep = await _client.get(
        uri,
        headers: {'User-Agent': 'VitalWatch/1.0 (projet etudiant)'},
      ).timeout(_delai);
      if (rep.statusCode != 200) {
        return estimation(depart, arrivee);
      }
      final Map<String, dynamic> json = jsonDecode(rep.body) as Map<String, dynamic>;
      final List<dynamic> routes = (json['routes'] as List<dynamic>?) ?? [];
      if (json['code'] != 'Ok' || routes.isEmpty) {
        return estimation(depart, arrivee);
      }

      final Map<String, dynamic> route = routes.first as Map<String, dynamic>;
      final Map<String, dynamic> geometrie = route['geometry'] as Map<String, dynamic>;
      final List<dynamic> coordonnees = geometrie['coordinates'] as List<dynamic>;
      final List<LatLng> points = [];
      for (final dynamic c in coordonnees) {
        final List<dynamic> lngLat = c as List<dynamic>;
        points.add(LatLng(
          (lngLat[1] as num).toDouble(),
          (lngLat[0] as num).toDouble(),
        ));
      }
      if (points.length < 2) {
        return estimation(depart, arrivee);
      }
      return Itineraire(
        points: points,
        distanceKm: (route['distance'] as num).toDouble() / 1000,
        duree: Duration(seconds: (route['duration'] as num).round()),
      );
    } catch (_) {
      // Pas de réseau, délai dépassé ou réponse inattendue
      return estimation(depart, arrivee);
    }
  }

  /// Repli hors ligne : ligne droite + durée estimée par FormuleHaversine.
  Itineraire estimation(LatLng depart, LatLng arrivee) {
    final double km = FormuleHaversine.distanceKm(depart, arrivee);
    return Itineraire(
      points: [depart, arrivee],
      distanceKm: km * 1.3,
      duree: FormuleHaversine.dureeEstimee(km),
      estime: true,
    );
  }
}
