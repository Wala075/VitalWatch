import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:projet/features/ambulance_dispatch/domain/dispatch_manager.dart';
import 'package:projet/features/ambulance_dispatch/domain/dispatch_models.dart';
import 'package:projet/features/ambulance_dispatch/domain/haversine.dart';
import 'package:projet/features/ambulance_dispatch/domain/hopitaux.dart';
import 'package:projet/features/ambulance_dispatch/domain/models/ambulance.dart';
import 'package:projet/features/ambulance_dispatch/domain/models/intervention.dart';

AmbulanceDetail _amb(int id, TypeAmbulance type, LatLng p, {bool equipage = true}) {
  return AmbulanceDetail(
    ambulance: Ambulance(
      id: id,
      immatriculation: '$id TU 1000',
      type: type,
      latitude: p.latitude,
      longitude: p.longitude,
    ),
    nbEquipiers: equipage ? 2 : 0,
    nbEquipiersDisponibles: equipage ? 2 : 0,
    nbMissions: 0,
  );
}

void main() {
  final LatLng sousse = LatLng(35.8256, 10.6084);
  final LatLng monastir = LatLng(35.7643, 10.8113);

  group('Haversine', () {
    test('distance Sousse - Monastir ≈ 19,5 km', () {
      expect(FormuleHaversine.distanceKm(sousse, monastir), closeTo(19.5, 0.5));
    });

    test('distance nulle pour un même point', () {
      expect(FormuleHaversine.distanceKm(sousse, sousse), 0);
    });
  });

  group('Dispatch', () {
    // ~1 km ≈ 0,009° de latitude
    LatLng aKm(double km) => LatLng(sousse.latitude + km * 0.009, sousse.longitude);

    test('critique : le type A est exclu', () {
      final List<CandidatDispatch> c = DispatchManager.classer(
        [_amb(1, TypeAmbulance.a, aKm(1))],
        sousse,
        Gravite.critique,
      );
      expect(c, isEmpty);
    });

    test('critique : type B proche préféré à un type C plus loin', () {
      final List<CandidatDispatch> c = DispatchManager.classer(
        [_amb(1, TypeAmbulance.c, aKm(5)), _amb(2, TypeAmbulance.b, aKm(3))],
        sousse,
        Gravite.critique,
      );
      expect(c.first.ambulance.id, 2); // 3 × 1,25 < 5 × 1,0
    });

    test('critique : type C préféré si l\'écart est faible', () {
      final List<CandidatDispatch> c = DispatchManager.classer(
        [_amb(1, TypeAmbulance.c, aKm(4)), _amb(2, TypeAmbulance.b, aKm(3.5))],
        sousse,
        Gravite.critique,
      );
      expect(c.first.ambulance.id, 1); // 4 × 1,0 < 3,5 × 1,25
    });

    test('une ambulance sans équipage disponible est ignorée', () {
      final List<CandidatDispatch> c = DispatchManager.classer(
        [_amb(1, TypeAmbulance.b, aKm(1), equipage: false), _amb(2, TypeAmbulance.b, aKm(8))],
        sousse,
        Gravite.urgente,
      );
      expect(c.length, 1);
      expect(c.first.ambulance.id, 2);
    });
  });

  test('immatriculation normalisée', () {
    expect(DispatchManager.normaliserImmatriculation('214tu5521'), '214 TU 5521');
    expect(DispatchManager.normaliserImmatriculation('ABC 12'), isNull);
  });

  test('hôpital le plus proche de Monastir', () {
    expect(Hopitaux.plusProche(monastir).nom, 'CHU Fattouma Bourguiba');
  });
}
