import 'package:latlong2/latlong.dart';

import 'haversine.dart';

class Hopital {
  const Hopital(this.nom, this.ville, this.latitude, this.longitude);

  final String nom;
  final String ville;
  final double latitude;
  final double longitude;

  LatLng get position => LatLng(latitude, longitude);
}

/// Hôpitaux de destination (région du Sahel).
class Hopitaux {
  Hopitaux._();

  static const List<Hopital> liste = [
    Hopital('CHU Sahloul', 'Sousse', 35.8336, 10.5946),
    Hopital('CHU Farhat Hached', 'Sousse', 35.8297, 10.6339),
    Hopital('CHU Fattouma Bourguiba', 'Monastir', 35.7650, 10.8125),
    Hopital('Hôpital régional de M\'saken', 'M\'saken', 35.7325, 10.5835),
    Hopital('CHU Tahar Sfar', 'Mahdia', 35.4990, 11.0560),
  ];

  static Hopital plusProche(LatLng point) {
    Hopital meilleur = liste.first;
    double min = double.infinity;
    for (final Hopital h in liste) {
      final double d = FormuleHaversine.distanceKm(point, h.position);
      if (d < min) {
        min = d;
        meilleur = h;
      }
    }
    return meilleur;
  }

  static Hopital? parNom(String? nom) {
    for (final Hopital h in liste) {
      if (h.nom == nom) {
        return h;
      }
    }
    return null;
  }
}
