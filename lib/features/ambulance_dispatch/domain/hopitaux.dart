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

/// Hôpitaux de destination (Sahel + grandes villes de Tunisie).
/// Coordonnées : OpenStreetMap / Wikipédia (« List of hospitals in Tunisia »).
class Hopitaux {
  Hopitaux._();

  static const List<Hopital> liste = [
    Hopital('CHU Sahloul', 'Sousse', 35.8336, 10.5946),
    Hopital('CHU Farhat Hached', 'Sousse', 35.8297, 10.6339),
    Hopital('CHU Fattouma Bourguiba', 'Monastir', 35.7650, 10.8125),
    Hopital('Hôpital régional de M\'saken', 'M\'saken', 35.7325, 10.5835),
    Hopital('CHU Tahar Sfar', 'Mahdia', 35.4990, 11.0560),
    Hopital('Hôpital Charles-Nicolle', 'Tunis', 36.8022, 10.1611),
    Hopital('Hôpital La Rabta', 'Tunis', 36.8019, 10.1544),
    Hopital('Hôpital Habib Thameur', 'Tunis', 36.7864, 10.1767),
    Hopital('Hôpital Mongi Slim', 'La Marsa', 36.8672, 10.2911),
    Hopital('CHU Habib Bougatfa', 'Bizerte', 37.2722, 9.8603),
    Hopital('Hôpital Taher Maamouri', 'Nabeul', 36.4381, 10.6742),
    Hopital('CHU Ibn El Jazzar', 'Kairouan', 35.7994, 10.1025),
    Hopital('CHU Hédi Chaker', 'Sfax', 34.7408, 10.7503),
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
