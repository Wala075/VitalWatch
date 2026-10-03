import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/empty_state.dart';
import '../../../../../core/widgets/search_field.dart';
import '../../../data/intervention_repository.dart';
import '../../../domain/dispatch_models.dart';
import '../../../domain/models/intervention.dart';
import '../../providers/dispatch_controller.dart';
import '../../providers/suivi_mission.dart';
import '../../widgets/dispatch_ui.dart';
import '../intervention_detail_screen.dart';
import '../intervention_form_screen.dart';

enum _FiltreInterventions { enCours, enAttente, terminees, annulees, toutes }

/// Historique et suivi des interventions (filtres + recherche).
class InterventionsTab extends StatefulWidget {
  const InterventionsTab({super.key, required this.peutCreer, this.ambulanceId});

  final bool peutCreer;

  /// Vue ambulancier : seulement les missions de son ambulance.
  final int? ambulanceId;

  @override
  State<InterventionsTab> createState() => _InterventionsTabState();
}

class _InterventionsTabState extends State<InterventionsTab> {
  final InterventionRepository _repo = InterventionRepository();
  final DispatchController _ctrl = DispatchController.instance;

  _FiltreInterventions _filtre = _FiltreInterventions.enCours;
  String _texte = '';
  List<InterventionDetail> _liste = [];
  bool _chargement = true;
  int _revision = -1;
  int _requete = 0;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_surChangement);
    _charger();
  }

  @override
  void didUpdateWidget(InterventionsTab ancien) {
    super.didUpdateWidget(ancien);
    if (ancien.ambulanceId != widget.ambulanceId) {
      _charger();
    }
  }

  @override
  void dispose() {
    _ctrl.removeListener(_surChangement);
    super.dispose();
  }

  void _surChangement() {
    if (_ctrl.revision != _revision) {
      _charger();
    } else if (mounted && _filtre == _FiltreInterventions.enCours) {
      setState(() {}); // ETA en direct
    }
  }

  List<StatutIntervention> get _statuts {
    switch (_filtre) {
      case _FiltreInterventions.enCours:
        return [
          StatutIntervention.assignee,
          StatutIntervention.enRoute,
          StatutIntervention.surPlace,
          StatutIntervention.transport,
          StatutIntervention.enAttente,
        ];
      case _FiltreInterventions.enAttente:
        return [StatutIntervention.enAttente];
      case _FiltreInterventions.terminees:
        return [StatutIntervention.terminee];
      case _FiltreInterventions.annulees:
        return [StatutIntervention.annulee];
      case _FiltreInterventions.toutes:
        return [];
    }
  }

  Future<void> _charger() async {
    _revision = _ctrl.revision;
    final int requete = ++_requete;
    final List<InterventionDetail> res = await _repo.rechercher(
      texte: _texte,
      statuts: _statuts,
      ambulanceId: widget.ambulanceId,
      limite: 200,
    );
    if (!mounted || requete != _requete) {
      return;
    }
    setState(() {
      _liste = res;
      _chargement = false;
    });
  }

  String _libelle(_FiltreInterventions f) {
    switch (f) {
      case _FiltreInterventions.enCours:
        return 'En cours';
      case _FiltreInterventions.enAttente:
        return 'En attente (${_ctrl.nbEnAttente})';
      case _FiltreInterventions.terminees:
        return 'Terminées';
      case _FiltreInterventions.annulees:
        return 'Annulées';
      case _FiltreInterventions.toutes:
        return 'Toutes';
    }
  }

  void _ouvrir(int? id) {
    if (id == null) {
      return;
    }
    Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => InterventionDetailScreen(interventionId: id)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: widget.peutCreer
          ? FloatingActionButton.extended(
              heroTag: 'fab_interventions',
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
              onPressed: () => Navigator.push<void>(
                context,
                MaterialPageRoute(builder: (_) => const InterventionFormScreen()),
              ),
              icon: const Icon(Icons.add_alert),
              label: const Text('Urgence'),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: SearchField(
              hint: 'Adresse, patient, immatriculation',
              onChanged: (String v) {
                _texte = v;
                _charger();
              },
            ),
          ),
          SizedBox(
            height: 46,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              children: [
                for (final _FiltreInterventions f in _FiltreInterventions.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(_libelle(f)),
                      selected: _filtre == f,
                      showCheckmark: false,
                      onSelected: (_) {
                        setState(() {
                          _filtre = f;
                          _chargement = true;
                        });
                        _charger();
                      },
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _chargement
                ? const Center(child: CircularProgressIndicator())
                : _liste.isEmpty
                    ? const EmptyState(
                        icon: Icons.emergency_outlined,
                        message: 'Aucune intervention',
                      )
                    : RefreshIndicator(
                        onRefresh: _charger,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                          itemCount: _liste.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 10),
                          itemBuilder: (BuildContext context, int k) {
                            final InterventionDetail d = _liste[k];
                            final int? id = d.intervention.id;
                            return CarteIntervention(
                              detail: d,
                              suivi: id == null ? null : _ctrl.suiviDe(id),
                              onTap: () => _ouvrir(id),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

/// Carte d'une intervention (liste, vue patient).
class CarteIntervention extends StatelessWidget {
  const CarteIntervention({super.key, required this.detail, this.suivi, this.onTap});

  final InterventionDetail detail;
  final SuiviMission? suivi;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Intervention i = detail.intervention;
    final SuiviMission? s = suivi;
    final Duration? reponse = i.tempsReponse;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: DispatchUi.gravite(i.gravite), width: 5),
            ),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  PastilleGravite(i.gravite),
                  const SizedBox(width: 6),
                  PastilleStatutIntervention(i.statut),
                  const Spacer(),
                  Text(
                    'n°${i.id}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                i.adresse,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 14,
                runSpacing: 4,
                children: [
                  Info(icone: Icons.schedule, texte: DispatchUi.ilYa(i.heureAppel)),
                  Info(
                    icone: Icons.airport_shuttle,
                    texte: detail.immatriculation ?? 'Non affectée',
                  ),
                  if (detail.patientNom != null)
                    Info(icone: Icons.person_outline, texte: detail.patientNom ?? ''),
                  Info(
                    icone: i.origine == OrigineIntervention.sos
                        ? Icons.sos
                        : i.origine == OrigineIntervention.alerte
                            ? Icons.monitor_heart_outlined
                            : Icons.phone_in_talk_outlined,
                    texte: i.origine.libelle,
                  ),
                ],
              ),
              if (s != null && s.enMouvement) ...[
                const SizedBox(height: 8),
                Info(
                  icone: Icons.timer_outlined,
                  texte: 'ETA ${DispatchUi.duree(s.etaRestant)} · '
                      '${DispatchUi.distance(s.resteKm)} restants',
                  couleur: DispatchUi.bleu,
                ),
              ] else if (reponse != null) ...[
                const SizedBox(height: 8),
                Info(
                  icone: Icons.timer_outlined,
                  texte: 'Temps de réponse : ${DispatchUi.duree(reponse)}',
                  couleur: AppColors.success,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
