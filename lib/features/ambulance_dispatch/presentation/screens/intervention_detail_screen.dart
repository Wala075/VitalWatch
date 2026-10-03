import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../models/utilisateur.dart';
import '../../../../shared_providers/session.dart';
import '../../data/intervention_repository.dart';
import '../../domain/ambulance_permissions.dart';
import '../../domain/dispatch_models.dart';
import '../../domain/haversine.dart';
import '../../domain/hopitaux.dart';
import '../../domain/models/ambulance.dart';
import '../../domain/models/intervention.dart';
import '../providers/dispatch_controller.dart';
import '../providers/suivi_mission.dart';
import '../widgets/carte_osm.dart';
import '../widgets/dispatch_ui.dart';

/// Suivi d'une intervention : carte temps réel, ETA, chronologie, actions.
class InterventionDetailScreen extends StatefulWidget {
  const InterventionDetailScreen({super.key, required this.interventionId});

  final int interventionId;

  @override
  State<InterventionDetailScreen> createState() => _InterventionDetailScreenState();
}

class _InterventionDetailScreenState extends State<InterventionDetailScreen> {
  final DispatchController _ctrl = DispatchController.instance;
  final InterventionRepository _repo = InterventionRepository();
  final MapController _carte = MapController();

  InterventionDetail? _detail;
  int _revision = -1;
  bool _action = false;
  bool _carteCadree = false;

  Role? get _role => Session.utilisateur?.role;

  bool get _piloter => _role?.piloterMission ?? false;

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
    } else if (mounted) {
      setState(() {});
    }
  }

  Future<void> _charger() async {
    _revision = _ctrl.revision;
    final InterventionDetail? d = _ctrl.ouverteParId(widget.interventionId) ??
        await _repo.detailParId(widget.interventionId);
    if (!mounted) {
      return;
    }
    setState(() => _detail = d);
  }

  Future<void> _executer(Future<void> Function() action, {String? succes}) async {
    setState(() => _action = true);
    try {
      await action();
      _carteCadree = false;
      if (mounted && succes != null) {
        DispatchUi.snack(context, succes);
      }
    } on DispatchException catch (e) {
      if (mounted) {
        DispatchUi.snack(context, e.message, erreur: true);
      }
    } finally {
      if (mounted) {
        setState(() => _action = false);
      }
      await _charger();
    }
  }

  Future<void> _transporter(Intervention i) async {
    final Hopital conseille = Hopitaux.plusProche(i.position);
    final String? choix = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext ctx) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(
                  'Hôpital de destination',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ),
              for (final Hopital h in Hopitaux.liste)
                ListTile(
                  leading: const Icon(Icons.local_hospital, color: DispatchUi.bleu),
                  title: Text(h.nom),
                  subtitle: Text(
                    '${h.ville} · ${DispatchUi.distance(FormuleHaversine.distanceKm(i.position, h.position))}',
                  ),
                  trailing: h.nom == conseille.nom
                      ? const Pastille(libelle: 'Le plus proche', couleur: AppColors.success)
                      : null,
                  onTap: () => Navigator.pop(ctx, h.nom),
                ),
            ],
          ),
        );
      },
    );
    final int? id = i.id;
    if (choix == null || id == null) {
      return;
    }
    await _executer(() => _ctrl.transporter(id, choix), succes: 'Transport vers $choix');
  }

  Future<void> _annuler(Intervention i) async {
    final int? id = i.id;
    if (id == null) {
      return;
    }
    final bool ok = await showConfirmDialog(
      context,
      titre: "Annuler l'intervention",
      message: "L'ambulance engagée redevient disponible.",
      confirmer: 'Annuler l\'intervention',
      danger: true,
    );
    if (ok) {
      await _executer(() async {
        await _ctrl.annuler(id);
      }, succes: 'Intervention annulée');
    }
  }

  Future<void> _relancer(int id) async {
    await _executer(() async {
      final ResultatDispatch r = await _ctrl.relancerDispatch(id);
      if (mounted) {
        DispatchUi.snack(context, r.justification ?? 'Dispatch relancé');
      }
    });
  }

  Future<void> _basculerGps(int ambulanceId, bool actif) async {
    try {
      if (actif) {
        await _ctrl.partagerPosition(ambulanceId);
      } else {
        await _ctrl.arreterPartage();
      }
    } on DispatchException catch (e) {
      if (mounted) {
        DispatchUi.snack(context, e.message, erreur: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final InterventionDetail? d = _detail;
    return Scaffold(
      appBar: AppBar(
        title: Text(d == null ? 'Intervention' : 'Intervention n°${d.intervention.id}'),
      ),
      body: d == null
          ? const Center(child: CircularProgressIndicator())
          : _contenu(d),
    );
  }

  Widget _contenu(InterventionDetail d) {
    final Intervention i = d.intervention;
    final int? id = i.id;
    final SuiviMission? suivi = id == null ? null : _ctrl.suiviDe(id);
    final int? ambId = i.ambulanceId;
    final Ambulance? amb = ambId == null ? null : _ctrl.ambulanceParId(ambId);

    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        SizedBox(height: 280, child: _carteSuivi(i, suivi, amb)),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _BandeauEta(intervention: i, suivi: suivi),
              const SizedBox(height: 14),
              _infos(d, amb),
              const SizedBox(height: 14),
              _Chronologie(intervention: i),
              const SizedBox(height: 16),
              if (_piloter) ..._actions(i),
              if (_role == Role.ambulancier && amb != null && amb.id != null) ...[
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.gps_fixed),
                  title: const Text('Partager ma position GPS'),
                  subtitle: const Text("La position du téléphone remplace la simulation"),
                  value: _ctrl.ambulanceGps == amb.id,
                  onChanged: (bool v) => _basculerGps(amb.id ?? 0, v),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _carteSuivi(Intervention i, SuiviMission? suivi, Ambulance? amb) {
    final List<LatLng> points = [i.position];
    final List<Marker> marqueurs = [
      Marker(
        point: i.position,
        width: 40,
        height: 48,
        alignment: Alignment.topCenter,
        child: MarqueurIntervention(
          gravite: i.gravite,
          enAttente: i.statut == StatutIntervention.enAttente,
        ),
      ),
    ];
    final Hopital? hopital = Hopitaux.parNom(i.hopitalDestination);
    if (hopital != null &&
        (i.statut == StatutIntervention.transport || i.statut == StatutIntervention.surPlace)) {
      points.add(hopital.position);
      marqueurs.add(Marker(
        point: hopital.position,
        width: 30,
        height: 30,
        child: MarqueurHopital(nom: hopital.nom),
      ));
    }
    if (amb != null && i.statut.estActive) {
      final LatLng p = _ctrl.positionAmbulance(amb);
      points.add(p);
      marqueurs.add(Marker(
        point: p,
        width: 46,
        height: 46,
        child: MarqueurAmbulance(ambulance: amb, selection: true),
      ));
    }

    return CarteOsm(
      controleur: _carte,
      centre: i.position,
      zoom: 14,
      surPrete: () => _cadrer(points),
      couches: [
        if (suivi != null)
          PolylineLayer(polylines: [
            Polyline(
              points: suivi.resteDuTrajet,
              strokeWidth: 6,
              color: suivi.phase == StatutIntervention.transport
                  ? AppColors.primary
                  : DispatchUi.bleu,
              borderStrokeWidth: 2,
              borderColor: Colors.white,
            ),
          ]),
        MarkerLayer(markers: marqueurs),
      ],
    );
  }

  void _cadrer(List<LatLng> points) {
    if (_carteCadree || points.length < 2) {
      return;
    }
    _carteCadree = true;
    _carte.fitCamera(CameraFit.bounds(
      bounds: LatLngBounds.fromPoints(points),
      padding: const EdgeInsets.all(48),
      maxZoom: 16,
    ));
  }

  Widget _infos(InterventionDetail d, Ambulance? amb) {
    final Intervention i = d.intervention;
    return Section(
      titre: i.adresse,
      icone: Icons.place_outlined,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            PastilleGravite(i.gravite, plein: true),
            PastilleStatutIntervention(i.statut),
            Pastille(
              libelle: i.origine.libelle,
              couleur: AppColors.textSecondary,
              icone: i.origine == OrigineIntervention.sos
                  ? Icons.sos
                  : i.origine == OrigineIntervention.alerte
                      ? Icons.monitor_heart_outlined
                      : Icons.phone_in_talk_outlined,
            ),
          ],
        ),
        Info(icone: Icons.person_outline, texte: d.patientNom ?? 'Patient non identifié'),
        Info(
          icone: Icons.airport_shuttle,
          texte: amb == null
              ? (d.immatriculation ?? 'Aucune ambulance affectée')
              : '${amb.immatriculation} · ${amb.type.libelle} · ${amb.type.description}',
        ),
        Info(
          icone: Icons.local_hospital_outlined,
          texte: 'Destination : ${i.hopitalDestination ?? 'à définir'}',
        ),
      ],
    );
  }

  List<Widget> _actions(Intervention i) {
    final int? id = i.id;
    if (id == null || !i.statut.estOuverte) {
      return [];
    }
    final List<Widget> res = [];

    Widget bouton(String libelle, IconData icone, VoidCallback action, {Color? couleur}) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: SizedBox(
          height: 50,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: couleur ?? AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: _action ? null : action,
            icon: Icon(icone),
            label: Text(libelle),
          ),
        ),
      );
    }

    switch (i.statut) {
      case StatutIntervention.enAttente:
        res.add(bouton('Relancer le dispatch', Icons.refresh, () => _relancer(id)));
        break;
      case StatutIntervention.assignee:
        res.add(bouton(
          "Départ de l'ambulance",
          Icons.play_arrow_rounded,
          () => _executer(() => _ctrl.demarrerMission(id), succes: 'Ambulance en route'),
          couleur: DispatchUi.bleu,
        ));
        break;
      case StatutIntervention.enRoute:
        res.add(bouton(
          'Arrivée sur place',
          Icons.place,
          () => _executer(() => _ctrl.arriverSurPlace(id), succes: 'Équipe sur place'),
          couleur: DispatchUi.orange,
        ));
        break;
      case StatutIntervention.surPlace:
        res.add(bouton(
          "Transporter vers l'hôpital",
          Icons.local_hospital,
          () => _transporter(i),
        ));
        res.add(bouton(
          'Terminer sur place (sans transport)',
          Icons.task_alt,
          () => _executer(() async {
            await _ctrl.terminer(id);
          }, succes: 'Intervention terminée'),
          couleur: AppColors.success,
        ));
        break;
      case StatutIntervention.transport:
        res.add(bouton(
          "Arrivée à l'hôpital (terminer)",
          Icons.task_alt,
          () => _executer(() async {
            await _ctrl.terminer(id);
          }, succes: 'Intervention terminée'),
          couleur: AppColors.success,
        ));
        break;
      case StatutIntervention.terminee:
      case StatutIntervention.annulee:
        break;
    }
    if (i.statut != StatutIntervention.transport) {
      res.add(OutlinedButton.icon(
        onPressed: _action ? null : () => _annuler(i),
        icon: const Icon(Icons.cancel_outlined, color: AppColors.danger),
        label: const Text("Annuler l'intervention", style: TextStyle(color: AppColors.danger)),
      ));
    }
    return res;
  }
}

/// ETA + progression du trajet (ou état d'attente).
class _BandeauEta extends StatelessWidget {
  const _BandeauEta({required this.intervention, this.suivi});

  final Intervention intervention;
  final SuiviMission? suivi;

  @override
  Widget build(BuildContext context) {
    final SuiviMission? s = suivi;
    final StatutIntervention statut = intervention.statut;

    String titre;
    String detail;
    IconData icone;
    Color couleur;
    double? progression;

    if (statut == StatutIntervention.enAttente) {
      titre = "En file d'attente";
      detail = 'Priorité ${intervention.gravite.libelle.toLowerCase()} : '
          "dispatch automatique dès qu'une ambulance adaptée se libère";
      icone = Icons.hourglass_top;
      couleur = AppColors.danger;
    } else if (s != null && statut == StatutIntervention.assignee) {
      titre = 'Mobilisation de l\'équipage';
      detail = 'Trajet prévu : ${DispatchUi.distance(s.itineraire.distanceKm)} · '
          '${DispatchUi.duree(s.itineraire.duree)}';
      icone = Icons.assignment_ind_outlined;
      couleur = AppColors.purple;
    } else if (s != null && s.enMouvement) {
      final bool versHopital = statut == StatutIntervention.transport;
      titre = '${versHopital ? 'Hôpital' : 'Arrivée'} dans ${DispatchUi.duree(s.etaRestant)}';
      detail = 'Vers ${DispatchUi.heure(s.heureArriveePrevue)} · '
          '${DispatchUi.distance(s.resteKm)} restants'
          '${s.itineraire.estime ? ' · estimation hors ligne' : ' · itinéraire OSRM'}';
      icone = versHopital ? Icons.local_hospital : Icons.navigation;
      couleur = versHopital ? AppColors.primary : DispatchUi.bleu;
      progression = s.fraction;
    } else if (statut == StatutIntervention.surPlace) {
      final Duration? r = intervention.tempsReponse;
      titre = 'Équipe sur place';
      detail = r == null ? 'Prise en charge en cours' : 'Temps de réponse : ${DispatchUi.duree(r)}';
      icone = Icons.medical_services_outlined;
      couleur = DispatchUi.orange;
    } else if (statut == StatutIntervention.terminee) {
      final Duration? r = intervention.tempsReponse;
      titre = 'Intervention terminée';
      detail = r == null ? 'Clôturée' : 'Temps de réponse : ${DispatchUi.duree(r)}';
      icone = Icons.task_alt;
      couleur = AppColors.success;
    } else if (statut == StatutIntervention.annulee) {
      titre = 'Intervention annulée';
      detail = 'Aucune ambulance engagée';
      icone = Icons.cancel_outlined;
      couleur = AppColors.textSecondary;
    } else {
      titre = 'Calcul de l\'itinéraire...';
      detail = 'OSRM';
      icone = Icons.route;
      couleur = DispatchUi.bleu;
    }

    final double? p = progression;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: couleur.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: couleur.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icone, color: couleur, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titre,
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: couleur),
                    ),
                    const SizedBox(height: 2),
                    Text(detail, style: const TextStyle(color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          if (p != null) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: p,
                minHeight: 8,
                color: couleur,
                backgroundColor: Colors.white,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Étapes horodatées : appel → départ → arrivée → transport → fin.
class _Chronologie extends StatelessWidget {
  const _Chronologie({required this.intervention});

  final Intervention intervention;

  @override
  Widget build(BuildContext context) {
    final Intervention i = intervention;
    final DateTime? depart = i.heureDepart;
    final DateTime? arrivee = i.heureArrivee;
    final int rang = _rang(i.statut);

    return Section(
      titre: 'Chronologie',
      icone: Icons.timeline,
      children: [
        _Etape(
          libelle: 'Appel reçu',
          detail: DispatchUi.dateHeure(i.heureAppel),
          fait: true,
        ),
        _Etape(
          libelle: 'Ambulance assignée',
          detail: rang >= 1 ? 'Dispatch automatique' : 'En attente',
          fait: rang >= 1,
        ),
        _Etape(
          libelle: 'Départ',
          detail: depart == null
              ? '—'
              : '${DispatchUi.heure(depart)} (+${DispatchUi.duree(depart.difference(i.heureAppel))})',
          fait: depart != null,
        ),
        _Etape(
          libelle: 'Arrivée sur place',
          detail: arrivee == null
              ? '—'
              : '${DispatchUi.heure(arrivee)} · réponse ${DispatchUi.duree(arrivee.difference(i.heureAppel))}',
          fait: arrivee != null,
        ),
        _Etape(
          libelle: 'Transport hôpital',
          detail: i.statut == StatutIntervention.transport || rang >= 5
              ? (i.hopitalDestination ?? '—')
              : '—',
          fait: i.statut == StatutIntervention.transport || rang >= 5,
        ),
        _Etape(
          libelle: i.statut == StatutIntervention.annulee ? 'Annulée' : 'Clôture',
          detail: i.statut.estOuverte ? '—' : i.statut.libelle,
          fait: !i.statut.estOuverte,
          dernier: true,
        ),
      ],
    );
  }

  int _rang(StatutIntervention s) {
    switch (s) {
      case StatutIntervention.enAttente:
        return 0;
      case StatutIntervention.assignee:
        return 1;
      case StatutIntervention.enRoute:
        return 2;
      case StatutIntervention.surPlace:
        return 3;
      case StatutIntervention.transport:
        return 4;
      case StatutIntervention.terminee:
        return 5;
      case StatutIntervention.annulee:
        return -1;
    }
  }
}

class _Etape extends StatelessWidget {
  const _Etape({
    required this.libelle,
    required this.detail,
    required this.fait,
    this.dernier = false,
  });

  final String libelle;
  final String detail;
  final bool fait;
  final bool dernier;

  @override
  Widget build(BuildContext context) {
    final Color c = fait ? AppColors.primary : AppColors.divider;
    return Row(
      children: [
        Icon(fait ? Icons.check_circle : Icons.radio_button_unchecked, color: c, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            libelle,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: fait ? AppColors.textPrimary : AppColors.textSecondary,
            ),
          ),
        ),
        Flexible(
          child: Text(
            detail,
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }
}
