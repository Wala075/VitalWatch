import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

/// Distance à vol d'oiseau entre deux points GPS (formule de Haversine).
class FormuleHaversine {
  FormuleHaversine._();

  static const double rayonTerreKm = 6371.0;

  static double distanceKm(LatLng a, LatLng b) {
    final double dLat = _rad(b.latitude - a.latitude);
    final double dLng = _rad(b.longitude - a.longitude);
    final double lat1 = _rad(a.latitude);
    final double lat2 = _rad(b.latitude);

    final double h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) * math.cos(lat2) * math.sin(dLng / 2) * math.sin(dLng / 2);
    final double c = 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));
    return rayonTerreKm * c;
  }

  /// Estimation du trajet routier quand OSRM est injoignable :
  /// la route fait ~1,3 × la distance à vol d'oiseau, à 45 km/h en ville.
  static Duration dureeEstimee(double distanceKm, {double vitesseKmH = 45}) {
    final double km = distanceKm * 1.3;
    final int secondes = (km / vitesseKmH * 3600).round();
    return Duration(seconds: secondes);
  }

  static double _rad(double degres) => degres * math.pi / 180;
}
