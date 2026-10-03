import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/utils/formatters.dart';
import '../../../data/intervention_repository.dart';
import '../../../domain/dispatch_manager.dart';
import '../../../domain/dispatch_models.dart';
import '../../../domain/models/intervention.dart';
import '../../providers/dispatch_controller.dart';
import '../../widgets/carte_osm.dart';
import '../../widgets/dispatch_ui.dart';

enum _Periode { semaine, mois, tout }

/// KPI (temps moyen de réponse, missions par ambulance...) + heatmap.
class StatsTab extends StatefulWidget {
  const StatsTab({super.key});

  @override
  State<StatsTab> createState() => _StatsTabState();
}

class _StatsTabState extends State<StatsTab> {
  final DispatchController _ctrl = DispatchController.instance;
  final InterventionRepository _interventions = InterventionRepository();

  _Periode _periode = _Periode.mois;
  Gravite? _graviteHeatmap;
  KpiDispatch? _kpi;
  List<Intervention> _points = [];
  int _requete = 0;
  int _revision = -1;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_surChangement);
    _charger();
  }

  @override
  void dispose() {
    _ctrl.removeListener(_surChangement);
    super.dispose();
  }

  void _surChangement() {
    if (_ctrl.revision != _revision) {
      _charger();
    }
  }

  DateTime? get _depuis {
    final DateTime maintenant = DateTime.now();
    switch (_periode) {
      case _Periode.semaine:
        return maintenant.subtract(const Duration(days: 7));
      case _Periode.mois:
        return maintenant.subtract(const Duration(days: 30));
      case _Periode.tout:
        return null;
    }
  }

  Future<void> _charger() async {
    _revision = _ctrl.revision;
    final int requete = ++_requete;
    final KpiDispatch kpi = await _ctrl.manager.kpi(depuis: _depuis);
    final List<Intervention> points =
        await _interventions.pourHeatmap(depuis: _depuis, gravite: _graviteHeatmap);
    if (!mounted || requete != _requete) {
      return;
    }
    setState(() {
      _kpi = kpi;
      _points = points;
    });
  }

  @override
  Widget build(BuildContext context) {
    final KpiDispatch? kpi = _kpi;
    if (kpi == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _charger,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
        children: [
          SegmentedButton<_Periode>(
            segments: const [
              ButtonSegment(value: _Periode.semaine, label: Text('7 jours')),
              ButtonSegment(value: _Periode.mois, label: Text('30 jours')),
              ButtonSegment(value: _Periode.tout, label: Text('Tout')),
            ],
            selected: {_periode},
            onSelectionChanged: (Set<_Periode> s) {
              setState(() => _periode = s.first);
              _charger();
            },
          ),
          const SizedBox(height: 14),
          _TempsReponse(kpi: kpi),
          const SizedBox(height: 12),
          _tuiles(kpi),
          const SizedBox(height: 14),
          _missionsParAmbulance(kpi),
          const SizedBox(height: 14),
          _tempsParGravite(kpi),
          const SizedBox(height: 14),
          _heatmap(),
        ],
      ),
    );
  }

  Widget _tuiles(KpiDispatch kpi) {
    final Duration? depart = kpi.tempsMoyenDepart;
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.55,
      children: [
        _Tuile(
          icone: Icons.emergency_outlined,
          valeur: '${kpi.nbInterventions}',
          libelle: 'Interventions',
          detail: '${kpi.nbTerminees} terminées · ${kpi.nbEnCours} en cours',
        ),
        _Tuile(
          icone: Icons.hourglass_top,
          valeur: '${kpi.nbEnAttente}',
          libelle: "En file d'attente",
          detail: kpi.nbEnAttente == 0 ? 'Aucune urgence sans ambulance' : 'Dispatch dès libération',
        ),
        _Tuile(
          icone: Icons.airport_shuttle_outlined,
          valeur: '${kpi.flotteDisponible}/${kpi.flotteTotale}',
          libelle: 'Ambulances libres',
          detail: kpi.flotteTotale == 0
              ? '—'
              : 'Disponibilité ${Formatters.pourcentage(kpi.flotteDisponible / kpi.flotteTotale)}',
        ),
        _Tuile(
          icone: Icons.play_circle_outline,
          valeur: depart == null ? '—' : DispatchUi.duree(depart),
          libelle: 'Délai moyen de départ',
          detail: 'Appel → départ ambulance',
        ),
        _Tuile(
          icone: Icons.build_circle_outlined,
          valeur: DispatchUi.cout(kpi.coutMaintenance),
          libelle: 'Coût maintenance',
          detail: 'Entretiens terminés',
        ),
        _Tuile(
          icone: Icons.flag_outlined,
          valeur: Formatters.pourcentage(kpi.tauxObjectif),
          libelle: 'Dans l\'objectif',
          detail: 'Réponse ≤ ${KpiDispatch.objectif.inMinutes} min',
        ),
      ],
    );
  }

  /// Barres horizontales, une seule teinte, triées par volume.
  Widget _missionsParAmbulance(KpiDispatch kpi) {
    final List<MapEntry<String, int>> lignes = kpi.missionsParAmbulance.entries.toList();
    lignes.sort((MapEntry<String, int> a, MapEntry<String, int> b) => b.value.compareTo(a.value));
    int max = 1;
    for (final MapEntry<String, int> e in lignes) {
      max = math.max(max, e.value);
    }

    return Section(
      titre: 'Missions par ambulance',
      icone: Icons.bar_chart_rounded,
      children: [
        if (lignes.isEmpty) const Info(icone: Icons.info_outline, texte: 'Aucune ambulance'),
        for (final MapEntry<String, int> e in lignes)
          _Barre(
            libelle: e.key,
            valeur: e.value / max,
            texte: '${e.value}',
            couleur: AppColors.primary,
            aide: '${e.key} : ${e.value} mission(s)',
          ),
      ],
    );
  }

  Widget _tempsParGravite(KpiDispatch kpi) {
    int maxSec = KpiDispatch.objectif.inSeconds;
    for (final Duration d in kpi.tempsParGravite.values) {
      maxSec = math.max(maxSec, d.inSeconds);
    }
    final double objectif = KpiDispatch.objectif.inSeconds / maxSec;

    return Section(
      titre: 'Temps de réponse par gravité',
      icone: Icons.timer_outlined,
      children: [
        for (final Gravite g in Gravite.values)
          _Barre(
            libelle: g.libelle,
            icone: DispatchUi.iconeGravite(g),
            valeur: (kpi.tempsParGravite[g]?.inSeconds ?? 0) / maxSec,
            texte: kpi.tempsParGravite[g] == null
                ? '—'
                : '${DispatchUi.duree(kpi.tempsParGravite[g] ?? Duration.zero)} '
                    '(${kpi.parGravite[g] ?? 0})',
            couleur: DispatchUi.gravite(g),
            repere: objectif,
            aide: '${g.libelle} : ${kpi.parGravite[g] ?? 0} intervention(s)',
          ),
        Info(
          icone: Icons.more_vert,
          texte: 'Trait vertical : objectif ${KpiDispatch.objectif.inMinutes} min · '
              '(n) = nombre d\'interventions',
        ),
      ],
    );
  }

  Widget _heatmap() {
    final List<_Cellule> cellules = _Cellule.regrouper(_points);
    int max = 1;
    for (final _Cellule c in cellules) {
      max = math.max(max, c.nombre);
    }
    final List<CircleMarker> cercles = [];
    for (final _Cellule c in cellules) {
      final double t = c.nombre / max;
      final double rayon = 380 + 160 * c.nombre.toDouble();
      // Trois halos concentriques : effet « chaleur » lissé
      cercles.add(CircleMarker(
        point: c.centre,
        radius: rayon * 1.7,
        useRadiusInMeter: true,
        color: AppColors.danger.withValues(alpha: 0.06 + 0.10 * t),
      ));
      cercles.add(CircleMarker(
        point: c.centre,
        radius: rayon,
        useRadiusInMeter: true,
        color: AppColors.danger.withValues(alpha: 0.12 + 0.22 * t),
      ));
      cercles.add(CircleMarker(
        point: c.centre,
        radius: rayon * 0.45,
        useRadiusInMeter: true,
        color: AppColors.danger.withValues(alpha: 0.20 + 0.45 * t),
      ));
    }

    return Section(
      titre: 'Heatmap des interventions',
      icone: Icons.local_fire_department_outlined,
      children: [
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: const Text('Toutes'),
                  selected: _graviteHeatmap == null,
                  showCheckmark: false,
                  onSelected: (_) {
                    setState(() => _graviteHeatmap = null);
                    _charger();
                  },
                ),
              ),
              for (final Gravite g in Gravite.values)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    avatar: Icon(DispatchUi.iconeGravite(g), size: 16, color: DispatchUi.gravite(g)),
                    label: Text(g.libelle),
                    selected: _graviteHeatmap == g,
                    showCheckmark: false,
                    onSelected: (_) {
                      setState(() => _graviteHeatmap = g);
                      _charger();
                    },
                  ),
                ),
            ],
          ),
        ),
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            height: 320,
            child: CarteOsm(
              centre: DispatchManager.centreZone,
              zoom: 10.5,
              couches: [CircleLayer(circles: cercles)],
            ),
          ),
        ),
        Row(
          children: [
            const Text('Peu', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                height: 10,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(5),
                  gradient: LinearGradient(
                    colors: [
                      AppColors.danger.withValues(alpha: 0.12),
                      AppColors.danger.withValues(alpha: 0.85),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$max / zone',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
        Info(
          icone: Icons.info_outline,
          texte: '${_points.length} intervention(s) regroupées par zones de ~600 m',
        ),
        if (cellules.isNotEmpty) _zonesChaudes(cellules),
      ],
    );
  }

  /// Vue tableau : les zones les plus sollicitées (lisible sans la couleur).
  Widget _zonesChaudes(List<_Cellule> cellules) {
    final List<_Cellule> tri = List<_Cellule>.of(cellules);
    tri.sort((_Cellule a, _Cellule b) => b.nombre.compareTo(a.nombre));
    final List<Widget> lignes = [
      const Text('Zones les plus sollicitées', style: TextStyle(fontWeight: FontWeight.w800)),
    ];
    for (int k = 0; k < tri.length && k < 3; k++) {
      lignes.add(Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(
          children: [
            Text('${k + 1}.', style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(width: 8),
            Expanded(child: Text(tri[k].adresse, overflow: TextOverflow.ellipsis)),
            Text(
              '${tri[k].nombre}',
              style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.textPrimary),
            ),
          ],
        ),
      ));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: lignes);
  }
}

/// Indicateur principal : temps moyen de réponse vs objectif.
class _TempsReponse extends StatelessWidget {
  const _TempsReponse({required this.kpi});

  final KpiDispatch kpi;

  @override
  Widget build(BuildContext context) {
    final Duration? t = kpi.tempsMoyenReponse;
    final bool ok = t != null && t <= KpiDispatch.objectif;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Temps moyen de réponse',
                  style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  t == null ? '—' : DispatchUi.duree(t),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 40,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1,
                  ),
                ),
                Text(
                  'Appel → arrivée sur place · objectif ${KpiDispatch.objectif.inMinutes} min',
                  style: const TextStyle(color: Colors.white60, fontSize: 12.5),
                ),
              ],
            ),
          ),
          if (t != null)
            Pastille(
              libelle: ok ? 'Objectif tenu' : 'Au-dessus',
              couleur: ok ? AppColors.ecg : AppColors.warning,
              icone: ok ? Icons.check_circle_outline : Icons.warning_amber_rounded,
            ),
        ],
      ),
    );
  }
}

class _Tuile extends StatelessWidget {
  const _Tuile({
    required this.icone,
    required this.valeur,
    required this.libelle,
    required this.detail,
  });

  final IconData icone;
  final String valeur;
  final String libelle;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icone, size: 18, color: AppColors.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    libelle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
            const Spacer(),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                valeur,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
              ),
            ),
            Text(
              detail,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

/// Barre horizontale : libellé, barre arrondie, valeur (+ repère optionnel).
class _Barre extends StatelessWidget {
  const _Barre({
    required this.libelle,
    required this.valeur,
    required this.texte,
    required this.couleur,
    required this.aide,
    this.icone,
    this.repere,
  });

  final String libelle;
  final double valeur;
  final String texte;
  final Color couleur;
  final String aide;
  final IconData? icone;

  /// Position (0..1) d'un trait vertical (objectif).
  final double? repere;

  @override
  Widget build(BuildContext context) {
    final IconData? i = icone;
    final double? r = repere;
    return Tooltip(
      message: aide,
      child: Row(
        children: [
          SizedBox(
            width: 108,
            child: Row(
              children: [
                if (i != null) ...[
                  Icon(i, size: 15, color: couleur),
                  const SizedBox(width: 4),
                ],
                Expanded(
                  child: Text(
                    libelle,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12.5, color: AppColors.textPrimary),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints c) {
                final double largeur = c.maxWidth;
                return SizedBox(
                  height: 18,
                  child: Stack(
                    children: [
                      Container(
                        height: 18,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceGrey,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      Container(
                        width: largeur * valeur.clamp(0.0, 1.0),
                        height: 18,
                        decoration: BoxDecoration(
                          color: couleur,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      if (r != null)
                        Positioned(
                          left: (largeur * r.clamp(0.0, 1.0)) - 1,
                          top: 0,
                          bottom: 0,
                          child: Container(width: 2, color: AppColors.textPrimary),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
          SizedBox(
            width: 84,
            child: Text(
              texte,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

/// Regroupement des interventions par zone (~600 m) pour la heatmap.
class _Cellule {
  _Cellule(this.centre, this.nombre, this.adresse);

  final LatLng centre;
  final int nombre;
  final String adresse;

  static const double _pas = 0.006;

  static List<_Cellule> regrouper(List<Intervention> points) {
    final Map<String, List<Intervention>> zones = {};
    for (final Intervention i in points) {
      final String cle = '${(i.lat / _pas).floor()}_${(i.lng / _pas).floor()}';
      zones.putIfAbsent(cle, () => []).add(i);
    }
    final List<_Cellule> res = [];
    for (final List<Intervention> zone in zones.values) {
      double lat = 0;
      double lng = 0;
      for (final Intervention i in zone) {
        lat += i.lat;
        lng += i.lng;
      }
      res.add(_Cellule(
        LatLng(lat / zone.length, lng / zone.length),
        zone.length,
        zone.first.adresse,
      ));
    }
    return res;
  }
}
