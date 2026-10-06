import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../domain/dispatch_manager.dart';
import '../../../domain/dispatch_models.dart';
import '../../../domain/hopitaux.dart';
import '../../../domain/models/ambulance.dart';
import '../../../domain/models/intervention.dart';
import '../../providers/dispatch_controller.dart';
import '../../providers/suivi_mission.dart';
import '../../widgets/carte_osm.dart';
import '../../widgets/dispatch_ui.dart';
import '../ambulance_detail_screen.dart';
import '../intervention_detail_screen.dart';
import '../intervention_form_screen.dart';

/// Carte de régulation temps réel : ambulances, urgences, hôpitaux,
/// itinéraires OSRM et ETA des missions en cours.
class CarteTab extends StatefulWidget {
  const CarteTab({super.key, required this.peutCreer});

  final bool peutCreer;

  @override
  State<CarteTab> createState() => _CarteTabState();
}

class _CarteTabState extends State<CarteTab> {
  final DispatchController _ctrl = DispatchController.instance;
  final MapController _carte = MapController();
  LatLng? _maPosition;

  Future<void> _nouvelle([LatLng? p]) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => InterventionFormScreen(position: p)),
    );
  }

  void _ouvrirIntervention(int? id) {
    if (id == null) {
      return;
    }
    Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => InterventionDetailScreen(interventionId: id)),
    );
  }

  Future<void> _localiser() async {
    try {
      final LatLng p = await _ctrl.gps.positionActuelle();
      if (!mounted) {
        return;
      }
      setState(() => _maPosition = p);
      if (DispatchManager.dansZone(p)) {
        _carte.move(p, 14);
      } else {
        DispatchUi.snack(context, 'Vous êtes hors de la zone couverte (Tunisie)');
      }
    } on DispatchException catch (e) {
      if (mounted) {
        DispatchUi.snack(context, e.message, erreur: true);
      }
    }
  }

  void _recentrer() {
    final List<LatLng> points = [];
    for (final AmbulanceDetail d in _ctrl.flotte) {
      points.add(_ctrl.positionAmbulance(d.ambulance));
    }
    for (final InterventionDetail d in _ctrl.ouvertes) {
      points.add(d.intervention.position);
    }
    if (points.length < 2) {
      _carte.move(DispatchManager.centreZone, 11);
      return;
    }
    _carte.fitCamera(CameraFit.bounds(
      bounds: LatLngBounds.fromPoints(points),
      padding: const EdgeInsets.fromLTRB(40, 90, 40, 170),
    ));
  }

  void _ficheAmbulance(AmbulanceDetail d) {
    final Ambulance a = d.ambulance;
    final int? id = a.id;
    final InterventionDetail? mission = id == null ? null : _ctrl.missionDe(id);
    final int? missionId = mission?.intervention.id;
    final SuiviMission? suivi = missionId == null ? null : _ctrl.suiviDe(missionId);

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        a.immatriculation,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                      ),
                    ),
                    PastilleStatutAmbulance(a.statut),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '${a.type.libelle} · ${a.type.description} · '
                  '${d.nbEquipiersDisponibles} équipier(s)',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                if (mission != null) ...[
                  const SizedBox(height: 12),
                  Info(
                    icone: Icons.place_outlined,
                    texte: '${mission.intervention.statut.libelle} : ${mission.intervention.adresse}',
                    couleur: AppColors.textPrimary,
                  ),
                  if (suivi != null && suivi.enMouvement)
                    Info(
                      icone: Icons.timer_outlined,
                      texte: 'ETA ${DispatchUi.duree(suivi.etaRestant)} · '
                          '${DispatchUi.distance(suivi.resteKm)} restants',
                      couleur: DispatchUi.bleu,
                    ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: id == null
                            ? null
                            : () {
                                Navigator.pop(ctx);
                                Navigator.push<bool>(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => AmbulanceDetailScreen(ambulanceId: id),
                                  ),
                                );
                              },
                        child: const Text('Fiche ambulance'),
                      ),
                    ),
                    if (mission != null) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _ouvrirIntervention(missionId);
                          },
                          child: const Text('Suivre la mission'),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _ctrl,
      builder: (BuildContext context, Widget? _) {
        return Stack(
          children: [
            CarteOsm(
              controleur: _carte,
              centre: DispatchManager.centreZone,
              zoom: 11,
              surAppuiLong: widget.peutCreer ? (LatLng p) => _nouvelle(p) : null,
              couches: _couches(),
            ),
            Positioned(top: 12, left: 12, right: 12, child: _bandeau()),
            Positioned(
              right: 12,
              top: 76,
              child: Column(
                children: [
                  _BoutonCarte(icone: Icons.my_location, aide: 'Ma position', onTap: _localiser),
                  const SizedBox(height: 8),
                  _BoutonCarte(icone: Icons.center_focus_strong, aide: 'Tout afficher', onTap: _recentrer),
                ],
              ),
            ),
            Positioned(left: 0, right: 0, bottom: 12, child: _missions()),
          ],
        );
      },
    );
  }

  List<Widget> _couches() {
    final List<Polyline> trajets = [];
    for (final SuiviMission s in _ctrl.suivis.values) {
      trajets.add(Polyline(
        points: s.resteDuTrajet,
        strokeWidth: 5,
        color: s.phase == StatutIntervention.transport ? AppColors.primary : DispatchUi.bleu,
        borderStrokeWidth: 1.5,
        borderColor: Colors.white,
      ));
    }

    final List<Marker> hopitaux = [];
    for (final Hopital h in Hopitaux.liste) {
      hopitaux.add(Marker(
        point: h.position,
        width: 30,
        height: 30,
        child: MarqueurHopital(nom: h.nom),
      ));
    }

    final List<Marker> urgences = [];
    for (final InterventionDetail d in _ctrl.ouvertes) {
      final Intervention i = d.intervention;
      urgences.add(Marker(
        point: i.position,
        width: 40,
        height: 48,
        alignment: Alignment.topCenter,
        child: GestureDetector(
          onTap: () => _ouvrirIntervention(i.id),
          child: MarqueurIntervention(
            gravite: i.gravite,
            enAttente: i.statut == StatutIntervention.enAttente,
          ),
        ),
      ));
    }

    final List<Marker> ambulances = [];
    for (final AmbulanceDetail d in _ctrl.flotte) {
      ambulances.add(Marker(
        point: _ctrl.positionAmbulance(d.ambulance),
        width: 42,
        height: 42,
        child: GestureDetector(
          onTap: () => _ficheAmbulance(d),
          child: MarqueurAmbulance(ambulance: d.ambulance),
        ),
      ));
    }

    final LatLng? moi = _maPosition;
    return [
      PolylineLayer(polylines: trajets),
      MarkerLayer(markers: hopitaux),
      MarkerLayer(markers: urgences),
      MarkerLayer(markers: ambulances),
      if (moi != null)
        MarkerLayer(markers: [
          Marker(point: moi, width: 22, height: 22, child: const MarqueurMaPosition()),
        ]),
    ];
  }

  Widget _bandeau() {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            // Réduit les compteurs sur les petits écrans au lieu de déborder
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _Compteur(
                      valeur: _ctrl.compterFlotte(StatutAmbulance.disponible),
                      libelle: 'libres',
                      couleur: AppColors.success,
                    ),
                    _Compteur(
                      valeur: _ctrl.compterFlotte(StatutAmbulance.enMission),
                      libelle: 'en mission',
                      couleur: DispatchUi.bleu,
                    ),
                    _Compteur(
                      valeur: _ctrl.nbEnAttente,
                      libelle: 'en attente',
                      couleur: AppColors.danger,
                    ),
                  ],
                ),
              ),
            ),
            if (_ctrl.simulation)
              Pastille(
                libelle: '×${_ctrl.vitesse}',
                couleur: AppColors.purple,
                icone: Icons.speed,
              ),
          ],
        ),
      ),
    );
  }

  Widget _missions() {
    final List<InterventionDetail> actives = [];
    for (final InterventionDetail d in _ctrl.ouvertes) {
      if (d.intervention.statut != StatutIntervention.terminee) {
        actives.add(d);
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.peutCreer)
          Padding(
            padding: const EdgeInsets.only(right: 12, bottom: 10),
            child: FloatingActionButton.extended(
              heroTag: 'fab_urgence',
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
              onPressed: () => _nouvelle(),
              icon: const Icon(Icons.add_alert),
              label: const Text('Urgence'),
            ),
          ),
        if (actives.isNotEmpty)
          SizedBox(
            height: 96,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: actives.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (BuildContext context, int k) {
                final InterventionDetail d = actives[k];
                final int? id = d.intervention.id;
                return _CarteMission(
                  detail: d,
                  suivi: id == null ? null : _ctrl.suiviDe(id),
                  onTap: () => _ouvrirIntervention(id),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _Compteur extends StatelessWidget {
  const _Compteur({required this.valeur, required this.libelle, required this.couleur});

  final int valeur;
  final String libelle;
  final Color couleur;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 14),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$valeur',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: couleur),
          ),
          const SizedBox(width: 4),
          Text(libelle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _BoutonCarte extends StatelessWidget {
  const _BoutonCarte({required this.icone, required this.aide, required this.onTap});

  final IconData icone;
  final String aide;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 3,
      child: IconButton(
        tooltip: aide,
        icon: Icon(icone, color: AppColors.primary),
        onPressed: onTap,
      ),
    );
  }
}

/// Mini-carte d'une mission en cours (bas de la carte).
class _CarteMission extends StatelessWidget {
  const _CarteMission({required this.detail, this.suivi, required this.onTap});

  final InterventionDetail detail;
  final SuiviMission? suivi;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Intervention i = detail.intervention;
    final SuiviMission? s = suivi;
    String ligne;
    if (i.statut == StatutIntervention.enAttente) {
      ligne = "En file d'attente";
    } else if (s != null && s.enMouvement) {
      ligne = 'ETA ${DispatchUi.duree(s.etaRestant)} · ${DispatchUi.distance(s.resteKm)}';
    } else {
      ligne = i.statut.libelle;
    }

    return SizedBox(
      width: 250,
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 6,
                  decoration: BoxDecoration(
                    color: DispatchUi.gravite(i.gravite),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        i.adresse,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${detail.immatriculation ?? '—'} · ${i.gravite.libelle}',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        ligne,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: DispatchUi.statutIntervention(i.statut),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
