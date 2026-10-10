import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import '../../data/api/osrm_api.dart';
import '../../domain/haversine.dart';
import '../../domain/models/intervention.dart';

/// Suivi temps réel d'une ambulance sur son itinéraire OSRM :
/// position courante, distance parcourue et ETA recalculée.
class SuiviMission {
  SuiviMission({
    required this.interventionId,
    required this.ambulanceId,
    required this.phase,
    required this.itineraire,
    required this.cible,
  })  : position = itineraire.points.first,
        debut = DateTime.now() {
    double cumul = 0;
    _cumuls.add(0);
    for (int i = 1; i < itineraire.points.length; i++) {
      cumul += FormuleHaversine.distanceKm(itineraire.points[i - 1], itineraire.points[i]);
      _cumuls.add(cumul);
    }
  }

  final int interventionId;
  final int ambulanceId;

  /// assignée (mobilisation), en route (vers le patient) ou transport (vers l'hôpital).
  final StatutIntervention phase;
  final Itineraire itineraire;
  final LatLng cible;
  final DateTime debut;
  final List<double> _cumuls = [];

  LatLng position;
  double parcouruKm = 0;

  double get longueurKm => _cumuls.last;

  double get fraction {
    if (longueurKm <= 0) {
      return 1;
    }
    return (parcouruKm / longueurKm).clamp(0.0, 1.0).toDouble();
  }

  bool get enMouvement =>
      phase == StatutIntervention.enRoute || phase == StatutIntervention.transport;

  bool get arrive => fraction >= 1;

  /// ETA = durée OSRM restante au prorata du trajet.
  Duration get etaRestant =>
      Duration(seconds: (itineraire.duree.inSeconds * (1 - fraction)).round());

  DateTime get heureArriveePrevue => DateTime.now().add(etaRestant);

  double get resteKm => itineraire.distanceKm * (1 - fraction);

  /// Vitesse moyenne du trajet (km/s) déduite d'OSRM.
  double get vitesseKmS {
    final int s = itineraire.duree.inSeconds;
    if (s <= 0) {
      return longueurKm;
    }
    return longueurKm / s;
  }

  /// Simulation : avance de [km] le long du tracé.
  void avancer(double km) {
    parcouruKm = math.min(longueurKm, parcouruKm + km);
    position = _pointA(parcouruKm);
  }

  /// GPS réel : se cale sur le point du tracé le plus proche.
  void placer(LatLng p) {
    position = p;
    int meilleur = 0;
    double min = double.infinity;
    for (int i = 0; i < itineraire.points.length; i++) {
      final double d = FormuleHaversine.distanceKm(p, itineraire.points[i]);
      if (d < min) {
        min = d;
        meilleur = i;
      }
    }
    parcouruKm = math.max(parcouruKm, _cumuls[meilleur]);
  }

  /// Portion du tracé encore à parcourir (affichée sur la carte).
  List<LatLng> get resteDuTrajet {
    final List<LatLng> res = [position];
    for (int i = 0; i < itineraire.points.length; i++) {
      if (_cumuls[i] > parcouruKm) {
        res.add(itineraire.points[i]);
      }
    }
    if (res.length == 1) {
      res.add(cible);
    }
    return res;
  }

  LatLng _pointA(double km) {
    final List<LatLng> pts = itineraire.points;
    for (int i = 1; i < pts.length; i++) {
      if (_cumuls[i] >= km) {
        final double segment = _cumuls[i] - _cumuls[i - 1];
        final double t = segment <= 0 ? 1 : (km - _cumuls[i - 1]) / segment;
        return LatLng(
          pts[i - 1].latitude + (pts[i].latitude - pts[i - 1].latitude) * t,
          pts[i - 1].longitude + (pts[i].longitude - pts[i - 1].longitude) * t,
        );
      }
    }
    return pts.last;
  }
}
