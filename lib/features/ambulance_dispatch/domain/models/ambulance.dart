import 'package:latlong2/latlong.dart';

/// Type de véhicule (norme EN 1789).
enum TypeAmbulance {
  a('A', 'Type A', 'Transport sanitaire'),
  b('B', 'Type B', "Secours d'urgence"),
  c('C', 'Type C', 'Réanimation (SMUR)');

  const TypeAmbulance(this.code, this.libelle, this.description);

  final String code;
  final String libelle;
  final String description;

  static TypeAmbulance depuisCode(String? code) {
    for (final TypeAmbulance t in TypeAmbulance.values) {
      if (t.code == code) {
        return t;
      }
    }
    return TypeAmbulance.b;
  }
}

enum StatutAmbulance {
  disponible('disponible', 'Disponible'),
  enMission('en_mission', 'En mission'),
  maintenance('maintenance', 'Maintenance'),
  horsService('hors_service', 'Hors service');

  const StatutAmbulance(this.code, this.libelle);

  final String code;
  final String libelle;

  static StatutAmbulance depuisCode(String? code) {
    for (final StatutAmbulance s in StatutAmbulance.values) {
      if (s.code == code) {
        return s;
      }
    }
    return StatutAmbulance.disponible;
  }
}

class Ambulance {
  final int? id;
  final String immatriculation;
  final TypeAmbulance type;
  final StatutAmbulance statut;
  final double latitude;
  final double longitude;
  final int kilometrage;

  const Ambulance({
    this.id,
    required this.immatriculation,
    required this.type,
    this.statut = StatutAmbulance.disponible,
    required this.latitude,
    required this.longitude,
    this.kilometrage = 0,
  });

  LatLng get position => LatLng(latitude, longitude);

  bool get estDisponible => statut == StatutAmbulance.disponible;

  Ambulance copyWith({
    int? id,
    StatutAmbulance? statut,
    double? latitude,
    double? longitude,
    int? kilometrage,
  }) {
    return Ambulance(
      id: id ?? this.id,
      immatriculation: immatriculation,
      type: type,
      statut: statut ?? this.statut,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      kilometrage: kilometrage ?? this.kilometrage,
    );
  }

  factory Ambulance.fromMap(Map<String, Object?> map) {
    return Ambulance(
      id: map['id'] as int?,
      immatriculation: map['immatriculation'] as String,
      type: TypeAmbulance.depuisCode(map['type'] as String?),
      statut: StatutAmbulance.depuisCode(map['statut'] as String?),
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      kilometrage: (map['kilometrage'] as int?) ?? 0,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'immatriculation': immatriculation,
      'type': type.code,
      'statut': statut.code,
      'latitude': latitude,
      'longitude': longitude,
      'kilometrage': kilometrage,
    };
  }
}
