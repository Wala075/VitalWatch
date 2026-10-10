import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/api/geolocalisation_service.dart';
import '../../data/api/nominatim_api.dart';
import '../../domain/dispatch_manager.dart';
import '../../domain/dispatch_models.dart';
import '../widgets/carte_osm.dart';
import '../widgets/dispatch_ui.dart';

/// Point choisi sur la carte + adresse (géocodage inverse Nominatim).
class PositionChoisie {
  const PositionChoisie(this.position, this.adresse);

  final LatLng position;
  final String? adresse;
}

/// Plein écran : toucher la carte pour placer le repère, puis valider.
class ChoixPositionScreen extends StatefulWidget {
  const ChoixPositionScreen({super.key, this.initiale, this.titre = 'Choisir sur la carte'});

  final LatLng? initiale;
  final String titre;

  @override
  State<ChoixPositionScreen> createState() => _ChoixPositionScreenState();
}

class _ChoixPositionScreenState extends State<ChoixPositionScreen> {
  final MapController _carte = MapController();
  final NominatimApi _nominatim = NominatimApi();
  final GeolocalisationService _gps = GeolocalisationService();

  LatLng? _point;
  String? _adresse;
  bool _recherche = false;

  @override
  void initState() {
    super.initState();
    final LatLng? p = widget.initiale;
    if (p != null) {
      _choisir(p);
    }
  }

  Future<void> _choisir(LatLng p) async {
    setState(() {
      _point = p;
      _adresse = null;
      _recherche = true;
    });
    final String? adresse = await _nominatim.adresseDe(p);
    if (!mounted || _point != p) {
      return;
    }
    setState(() {
      _adresse = adresse;
      _recherche = false;
    });
  }

  Future<void> _maPosition() async {
    try {
      final LatLng p = await _gps.positionActuelle();
      if (!mounted) {
        return;
      }
      _carte.move(p, 15);
      _choisir(p);
    } on DispatchException catch (e) {
      if (mounted) {
        DispatchUi.snack(context, e.message, erreur: true);
      }
    }
  }

  void _valider() {
    final LatLng? p = _point;
    if (p == null) {
      return;
    }
    if (!DispatchManager.dansZone(p)) {
      DispatchUi.snack(context, 'Point hors de la zone couverte (Tunisie)', erreur: true);
      return;
    }
    Navigator.pop(context, PositionChoisie(p, _adresse));
  }

  @override
  Widget build(BuildContext context) {
    final LatLng? p = _point;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.titre),
        actions: [
          IconButton(
            tooltip: 'Ma position',
            icon: const Icon(Icons.my_location),
            onPressed: _maPosition,
          ),
        ],
      ),
      body: Stack(
        children: [
          CarteOsm(
            controleur: _carte,
            centre: widget.initiale ?? DispatchManager.centreZone,
            zoom: widget.initiale == null ? 11 : 15,
            surTap: _choisir,
            couches: [
              if (p != null)
                MarkerLayer(markers: [
                  Marker(
                    point: p,
                    width: 44,
                    height: 44,
                    alignment: Alignment.topCenter,
                    child: const MarqueurChoix(),
                  ),
                ]),
            ],
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: SafeArea(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.place_outlined, color: AppColors.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              p == null
                                  ? 'Touchez la carte pour placer le repère'
                                  : _recherche
                                      ? 'Recherche de l\'adresse...'
                                      : (_adresse ?? 'Adresse introuvable (coordonnées utilisées)'),
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: p == null ? null : _valider,
                        icon: const Icon(Icons.check),
                        label: const Text('Valider ce point'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
