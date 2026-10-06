import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/dispatch_manager.dart';
import '../../domain/dispatch_models.dart';
import '../../domain/haversine.dart';
import '../../domain/models/ambulance.dart';
import '../providers/dispatch_controller.dart';
import 'carte_osm.dart';
import 'dispatch_ui.dart';

/// Espace patient : sa vraie position GPS et les ambulances disponibles
/// autour de lui (positions en direct, comme la régulation), avec la plus
/// proche et son temps d'arrivée estimé. C'est celle-ci que le dispatch
/// enverra (selon la gravité et le type d'ambulance).
class CarteAmbulancesProches extends StatefulWidget {
  const CarteAmbulancesProches({super.key});

  @override
  State<CarteAmbulancesProches> createState() => _CarteAmbulancesProchesState();
}

class _CarteAmbulancesProchesState extends State<CarteAmbulancesProches> {
  static const Duration _frequenceGps = Duration(seconds: 30);

  final DispatchController _ctrl = DispatchController.instance;
  final MapController _carte = MapController();
  LatLng? _position;
  String? _avertissement;
  bool _prete = false;
  bool _cadree = false;
  bool _visible = false;
  bool _demande = false;
  Timer? _minuterie;

  @override
  void initState() {
    super.initState();
    // GPS seulement quand l'onglet SOS est affiché (onglet caché de l'accueil
    // → TickerMode désactivé).
    _minuterie = Timer.periodic(_frequenceGps, (_) {
      if (_visible) {
        _localiser();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _visible = TickerMode.valuesOf(context).enabled;
    if (_visible && !_demande) {
      _demande = true;
      _localiser();
    }
  }

  @override
  void dispose() {
    _minuterie?.cancel();
    super.dispose();
  }

  Future<void> _localiser() async {
    LatLng p;
    String? avertissement;
    try {
      p = await _ctrl.gps.positionActuelle();
      if (!DispatchManager.dansZone(p)) {
        avertissement = 'Position hors de Tunisie : position de démonstration (Sousse)';
        p = DispatchManager.centreZone;
      }
    } on DispatchException catch (e) {
      avertissement = '${e.message} : position de démonstration (Sousse)';
      p = _position ?? DispatchManager.centreZone;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _position = p;
      _avertissement = avertissement;
    });
    _cadrer();
  }

  /// Ma position + les 3 ambulances disponibles les plus proches.
  void _cadrer({bool forcer = false}) {
    final LatLng? moi = _position;
    if (moi == null || !_prete || (_cadree && !forcer)) {
      return;
    }
    final List<LatLng> points = [moi];
    final List<_Proche> proches = _proches(moi);
    for (int i = 0; i < proches.length && i < 3; i++) {
      points.add(proches[i].position);
    }
    _cadree = true;
    if (points.length < 2) {
      _carte.move(moi, 14);
      return;
    }
    _carte.fitCamera(CameraFit.bounds(
      bounds: LatLngBounds.fromPoints(points),
      padding: const EdgeInsets.all(40),
      maxZoom: 15,
    ));
  }

  /// Ambulances disponibles avec équipage, de la plus proche à la plus loin.
  List<_Proche> _proches(LatLng moi) {
    final List<_Proche> res = [];
    for (final AmbulanceDetail d in _ctrl.flotte) {
      final Ambulance a = d.ambulance;
      // Mêmes critères que le dispatch automatique.
      if (!a.estDisponible || !d.aEquipage) {
        continue;
      }
      final LatLng p = _ctrl.positionAmbulance(a);
      res.add(_Proche(a, p, FormuleHaversine.distanceKm(moi, p)));
    }
    res.sort((_Proche x, _Proche y) => x.km.compareTo(y.km));
    return res;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _ctrl,
      builder: (BuildContext context, Widget? _) {
        final LatLng moi = _position ?? DispatchManager.centreZone;
        final List<_Proche> proches = _proches(moi);
        final _Proche? premier = proches.isEmpty ? null : proches.first;
        final String? avertissement = _avertissement;

        return Section(
          titre: 'Ambulances autour de vous',
          icone: Icons.airport_shuttle_outlined,
          action: IconButton(
            tooltip: 'Recentrer',
            icon: const Icon(Icons.my_location),
            onPressed: () {
              _localiser();
              _cadrer(forcer: true);
            },
          ),
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                height: 240,
                child: CarteOsm(
                  controleur: _carte,
                  centre: moi,
                  zoom: 13,
                  surPrete: () {
                    _prete = true;
                    _cadrer();
                  },
                  couches: [
                    MarkerLayer(
                      markers: [
                        for (final _Proche p in proches)
                          Marker(
                            point: p.position,
                            width: 46,
                            height: 46,
                            child: MarqueurAmbulance(
                              ambulance: p.ambulance,
                              selection: identical(p, premier),
                            ),
                          ),
                        if (_position != null)
                          Marker(
                            point: moi,
                            width: 22,
                            height: 22,
                            child: const MarqueurMaPosition(),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (avertissement != null)
              Info(icone: Icons.gps_off, texte: avertissement, couleur: AppColors.warning),
            if (premier == null)
              const Info(
                icone: Icons.info_outline,
                texte: 'Aucune ambulance libre pour le moment : votre SOS sera mis '
                    'en file d\'attente prioritaire',
                couleur: AppColors.danger,
              )
            else ...[
              Row(
                children: [
                  const Icon(Icons.near_me, size: 18, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'La plus proche : ${premier.ambulance.immatriculation} '
                      '(${premier.ambulance.type.libelle})',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              Info(
                icone: Icons.schedule,
                texte: '${DispatchUi.distance(premier.km)} · environ '
                    '${DispatchUi.duree(FormuleHaversine.dureeEstimee(premier.km))} · '
                    '${proches.length} ambulance(s) libre(s)',
              ),
            ],
          ],
        );
      },
    );
  }
}

class _Proche {
  _Proche(this.ambulance, this.position, this.km);

  final Ambulance ambulance;
  final LatLng position;
  final double km;
}
