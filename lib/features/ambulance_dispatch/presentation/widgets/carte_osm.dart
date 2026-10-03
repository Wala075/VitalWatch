import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/models/ambulance.dart';
import '../../domain/models/intervention.dart';
import 'dispatch_ui.dart';

/// Carte OpenStreetMap (flutter_map) commune aux écrans du module.
class CarteOsm extends StatelessWidget {
  const CarteOsm({
    super.key,
    required this.centre,
    this.zoom = 12.5,
    this.controleur,
    this.couches = const [],
    this.surTap,
    this.surAppuiLong,
    this.interactive = true,
    this.surPrete,
  });

  final LatLng centre;
  final double zoom;
  final MapController? controleur;
  final List<Widget> couches;
  final ValueChanged<LatLng>? surTap;
  final ValueChanged<LatLng>? surAppuiLong;
  final bool interactive;
  final VoidCallback? surPrete;

  @override
  Widget build(BuildContext context) {
    final ValueChanged<LatLng>? tap = surTap;
    final ValueChanged<LatLng>? appuiLong = surAppuiLong;

    return FlutterMap(
      mapController: controleur,
      options: MapOptions(
        initialCenter: centre,
        initialZoom: zoom,
        minZoom: 6,
        maxZoom: 18,
        onMapReady: surPrete,
        onTap: tap == null ? null : (TapPosition _, LatLng p) => tap(p),
        onLongPress: appuiLong == null ? null : (TapPosition _, LatLng p) => appuiLong(p),
        interactionOptions: InteractionOptions(
          flags: interactive
              ? InteractiveFlag.all & ~InteractiveFlag.rotate
              : InteractiveFlag.none,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.projet',
        ),
        ...couches,
        SimpleAttributionWidget(source: const Text('OpenStreetMap contributors')),
      ],
    );
  }
}

/// Pastille ronde avec icône (base des marqueurs).
class _Rond extends StatelessWidget {
  const _Rond({
    required this.couleur,
    required this.icone,
    this.taille = 38,
    this.selection = false,
  });

  final Color couleur;
  final IconData icone;
  final double taille;
  final bool selection;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: taille,
      height: taille,
      decoration: BoxDecoration(
        color: couleur,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: selection ? 4 : 2.5),
        boxShadow: const [
          BoxShadow(color: Color(0x44000000), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Icon(icone, color: Colors.white, size: taille * 0.5),
    );
  }
}

class MarqueurAmbulance extends StatelessWidget {
  const MarqueurAmbulance({super.key, required this.ambulance, this.selection = false});

  final Ambulance ambulance;
  final bool selection;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '${ambulance.immatriculation} · ${ambulance.statut.libelle}',
      child: _Rond(
        couleur: DispatchUi.statutAmbulance(ambulance.statut),
        icone: Icons.airport_shuttle,
        taille: selection ? 46 : 38,
        selection: selection,
      ),
    );
  }
}

class MarqueurIntervention extends StatelessWidget {
  const MarqueurIntervention({super.key, required this.gravite, this.enAttente = false});

  final Gravite gravite;
  final bool enAttente;

  @override
  Widget build(BuildContext context) {
    final Color c = DispatchUi.gravite(gravite);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Rond(
          couleur: c,
          icone: enAttente ? Icons.hourglass_top : DispatchUi.iconeGravite(gravite),
          taille: 34,
        ),
        Container(width: 3, height: 10, color: c),
      ],
    );
  }
}

class MarqueurHopital extends StatelessWidget {
  const MarqueurHopital({super.key, required this.nom});

  final String nom;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: nom,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: DispatchUi.bleu, width: 2),
        ),
        child: const Icon(Icons.local_hospital, color: DispatchUi.bleu, size: 22),
      ),
    );
  }
}

/// Point bleu « ma position ».
class MarqueurMaPosition extends StatelessWidget {
  const MarqueurMaPosition({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2563EB),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withValues(alpha: 0.35),
            blurRadius: 12,
            spreadRadius: 6,
          ),
        ],
      ),
    );
  }
}

/// Repère du point choisi (formulaires).
class MarqueurChoix extends StatelessWidget {
  const MarqueurChoix({super.key});

  @override
  Widget build(BuildContext context) {
    return const Icon(Icons.location_on, color: AppColors.danger, size: 44);
  }
}
