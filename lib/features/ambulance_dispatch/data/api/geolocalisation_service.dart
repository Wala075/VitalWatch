import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../domain/dispatch_models.dart';

/// Position GPS de l'appareil (package geolocator).
class GeolocalisationService {
  static const LocationSettings _precis = LocationSettings(
    accuracy: LocationAccuracy.high,
    timeLimit: Duration(seconds: 15),
  );

  /// Vérifie le service + la permission, puis lit la position actuelle.
  Future<LatLng> positionActuelle() async {
    await _verifierAcces();
    try {
      final Position p = await Geolocator.getCurrentPosition(locationSettings: _precis);
      return LatLng(p.latitude, p.longitude);
    } on TimeoutException {
      final Position? derniere = await Geolocator.getLastKnownPosition();
      if (derniere == null) {
        throw const DispatchException('Position GPS introuvable, réessayez à découvert');
      }
      return LatLng(derniere.latitude, derniere.longitude);
    }
  }

  /// Flux de positions (mode ambulancier : partage de position en mission).
  Future<StreamSubscription<Position>> suivre(void Function(LatLng) surPosition) async {
    await _verifierAcces();
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 15,
      ),
    ).listen((Position p) => surPosition(LatLng(p.latitude, p.longitude)));
  }

  Future<void> _verifierAcces() async {
    final bool actif = await Geolocator.isLocationServiceEnabled();
    if (!actif) {
      throw const DispatchException("Activez la localisation (GPS) de l'appareil");
    }
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw const DispatchException('Permission de localisation refusée');
    }
    if (permission == LocationPermission.deniedForever) {
      throw const DispatchException(
        'Localisation bloquée : autorisez-la dans les paramètres du téléphone',
      );
    }
  }
}
