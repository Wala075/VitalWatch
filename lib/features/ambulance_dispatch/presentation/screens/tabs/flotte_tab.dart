import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/empty_state.dart';
import '../../../../../core/widgets/search_field.dart';
import '../../../domain/dispatch_models.dart';
import '../../../domain/models/ambulance.dart';
import '../../providers/dispatch_controller.dart';
import '../../widgets/dispatch_ui.dart';
import '../ambulance_detail_screen.dart';
import '../ambulance_form_screen.dart';

/// Liste de la flotte : statut, équipage, jauge d'entretien.
class FlotteTab extends StatefulWidget {
  const FlotteTab({super.key, required this.gerer});

  final bool gerer;

  @override
  State<FlotteTab> createState() => _FlotteTabState();
}

class _FlotteTabState extends State<FlotteTab> {
  final DispatchController _ctrl = DispatchController.instance;
  String _texte = '';
  StatutAmbulance? _statut;

  List<AmbulanceDetail> _filtrer(List<AmbulanceDetail> flotte) {
    final String t = _texte.trim().toUpperCase();
    final List<AmbulanceDetail> res = [];
    for (final AmbulanceDetail d in flotte) {
      if (_statut != null && d.ambulance.statut != _statut) {
        continue;
      }
      if (t.isNotEmpty && !d.ambulance.immatriculation.toUpperCase().contains(t)) {
        continue;
      }
      res.add(d);
    }
    return res;
  }

  Future<void> _ajouter() async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const AmbulanceFormScreen()),
    );
  }

  Future<void> _ouvrir(AmbulanceDetail d) async {
    final int? id = d.ambulance.id;
    if (id == null) {
      return;
    }
    final bool? modifie = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => AmbulanceDetailScreen(ambulanceId: id)),
    );
    if (modifie == true) {
      await _ctrl.rafraichir();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: widget.gerer
          ? FloatingActionButton.extended(
              heroTag: 'fab_flotte',
              onPressed: _ajouter,
              icon: const Icon(Icons.add),
              label: const Text('Ambulance'),
            )
          : null,
      body: ListenableBuilder(
        listenable: _ctrl,
        builder: (BuildContext context, Widget? _) {
          final List<AmbulanceDetail> liste = _filtrer(_ctrl.flotte);
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: SearchField(
                  hint: 'Rechercher une immatriculation',
                  onChanged: (String v) => setState(() => _texte = v),
                ),
              ),
              SizedBox(
                height: 46,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  children: [
                    _Filtre(
                      libelle: 'Toutes (${_ctrl.flotte.length})',
                      actif: _statut == null,
                      onTap: () => setState(() => _statut = null),
                    ),
                    for (final StatutAmbulance s in StatutAmbulance.values)
                      _Filtre(
                        libelle: '${s.libelle} (${_ctrl.compterFlotte(s)})',
                        actif: _statut == s,
                        couleur: DispatchUi.statutAmbulance(s),
                        onTap: () => setState(() => _statut = s),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: !_ctrl.charge
                    ? const Center(child: CircularProgressIndicator())
                    : liste.isEmpty
                        ? const EmptyState(
                            icon: Icons.airport_shuttle_outlined,
                            message: 'Aucune ambulance',
                          )
                        : RefreshIndicator(
                            onRefresh: _ctrl.rafraichir,
                            child: ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                              itemCount: liste.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 10),
                              itemBuilder: (BuildContext context, int i) => _CarteAmbulance(
                                detail: liste[i],
                                onTap: () => _ouvrir(liste[i]),
                              ),
                            ),
                          ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Filtre extends StatelessWidget {
  const _Filtre({
    required this.libelle,
    required this.actif,
    required this.onTap,
    this.couleur = AppColors.primary,
  });

  final String libelle;
  final bool actif;
  final VoidCallback onTap;
  final Color couleur;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(libelle),
        selected: actif,
        onSelected: (_) => onTap(),
        selectedColor: couleur.withValues(alpha: 0.16),
        labelStyle: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: actif ? couleur : AppColors.textSecondary,
        ),
        side: BorderSide(color: actif ? couleur : AppColors.divider),
        showCheckmark: false,
      ),
    );
  }
}

class _CarteAmbulance extends StatelessWidget {
  const _CarteAmbulance({required this.detail, required this.onTap});

  final AmbulanceDetail detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Ambulance a = detail.ambulance;
    final Color couleur = DispatchUi.statutAmbulance(a.statut);
    final int? reste = detail.kmAvantEntretien;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: couleur.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.airport_shuttle, color: couleur),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          a.immatriculation,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                        ),
                        Text(
                          '${a.type.libelle} · ${a.type.description}',
                          style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  PastilleStatutAmbulance(a.statut),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 14,
                runSpacing: 4,
                children: [
                  Info(icone: Icons.speed, texte: DispatchUi.kilometrage(a.kilometrage)),
                  Info(
                    icone: Icons.groups_outlined,
                    texte: '${detail.nbEquipiersDisponibles} équipier(s)',
                    couleur: detail.aEquipage ? null : AppColors.danger,
                  ),
                  Info(icone: Icons.task_alt, texte: '${detail.nbMissions} mission(s)'),
                ],
              ),
              if (detail.seuilDepasse || detail.entretienProche) ...[
                const SizedBox(height: 8),
                Info(
                  icone: detail.seuilDepasse ? Icons.lock_outline : Icons.warning_amber_rounded,
                  texte: detail.seuilDepasse
                      ? 'Seuil d\'entretien dépassé : bloquée automatiquement'
                      : 'Entretien dans ${DispatchUi.kilometrage(reste ?? 0)}',
                  couleur: detail.seuilDepasse ? AppColors.danger : AppColors.warning,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
