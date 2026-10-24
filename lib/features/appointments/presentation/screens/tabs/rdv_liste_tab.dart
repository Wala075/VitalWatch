import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/app_dropdown_field.dart';
import '../../../../../core/widgets/empty_state.dart';
import '../../../../../core/widgets/search_field.dart';
import '../../../../../models/medecin.dart';
import '../../../../../models/utilisateur.dart';
import '../../../domain/rdv_manager.dart';
import '../../../domain/rdv_models.dart';
import '../../../domain/rdv_permissions.dart';
import '../../widgets/rdv_widgets.dart';
import '../rdv_detail_screen.dart';

/// Liste des rendez-vous visibles par l'utilisateur, « À venir » / « Passés ».
/// - patient / médecin : uniquement les siens (+ rappels J-1 / H-1)
/// - admin / infirmier : tous, avec recherche et filtres.
class RdvListeTab extends StatefulWidget {
  const RdvListeTab({super.key, required this.utilisateur, this.rafraichir});

  final Utilisateur utilisateur;

  /// Change de valeur quand l'écran parent veut forcer un rechargement.
  final ValueNotifier<int>? rafraichir;

  @override
  State<RdvListeTab> createState() => _RdvListeTabState();
}

class _RdvListeTabState extends State<RdvListeTab> {
  final RdvManager _manager = RdvManager();

  List<RdvDetail> _rdvs = [];
  List<Rappel> _rappels = [];
  RdvFiltre _filtre = const RdvFiltre();
  int _segment = 0;
  bool _chargement = true;
  int _requete = 0;

  Utilisateur get _u => widget.utilisateur;

  bool get _recherche => _u.role.voirTousLesRdv || _u.role == Role.medecin;

  @override
  void initState() {
    super.initState();
    widget.rafraichir?.addListener(_charger);
    _charger();
  }

  @override
  void dispose() {
    widget.rafraichir?.removeListener(_charger);
    super.dispose();
  }

  Future<void> _charger() async {
    final int requete = ++_requete;
    final List<RdvDetail> res = await _manager.mesRdv(_u, filtre: _filtre);
    final List<Rappel> rappels = await _manager.rappels(_u);
    if (!mounted || requete != _requete) {
      return;
    }
    setState(() {
      _rdvs = res;
      _rappels = rappels;
      _chargement = false;
    });
  }

  Future<void> _ouvrir(RdvDetail d) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => RdvDetailScreen(rdvId: d.rdv.id ?? 0, utilisateur: _u),
      ),
    );
    _charger();
  }

  Future<void> _ouvrirFiltres() async {
    final List<Medecin> medecins = await _manager.medecins();
    if (!mounted) {
      return;
    }
    final RdvFiltre? res = await showModalBottomSheet<RdvFiltre>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _FiltreSheet(
        initial: _filtre,
        medecins: medecins,
        choixMedecin: _u.role.voirTousLesRdv,
      ),
    );
    if (res != null) {
      setState(() => _filtre = res);
      _charger();
    }
  }

  @override
  Widget build(BuildContext context) {
    final DateTime n = DateTime.now();
    final List<RdvDetail> aVenir = [];
    final List<RdvDetail> passes = [];
    for (final RdvDetail d in _rdvs) {
      final bool futur = d.rdv.statut.estActif &&
          d.rdv.fin.isAfter(n.subtract(const Duration(hours: 1)));
      (futur ? aVenir : passes).add(d);
    }
    passes.sort((RdvDetail a, RdvDetail b) => b.rdv.dateHeure.compareTo(a.rdv.dateHeure));
    final List<RdvDetail> liste = _segment == 0 ? aVenir : passes;
    final bool estPatient = _u.role == Role.patient;

    return RefreshIndicator(
      onRefresh: _charger,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
        children: [
          if (_recherche) ...[
            SearchField(
              hint: 'Patient, médecin, motif...',
              nbFiltres: _filtre.nbFiltresActifs,
              onFilterTap: _ouvrirFiltres,
              onChanged: (String v) {
                _filtre = _filtre.avecTexte(v);
                _charger();
              },
            ),
            const SizedBox(height: 12),
          ],
          RappelsBanner(rappels: _rappels, onTap: _ouvrir),
          Segments(
            libelles: ['À venir (${aVenir.length})', 'Passés (${passes.length})'],
            index: _segment,
            onChanged: (int i) => setState(() => _segment = i),
          ),
          const SizedBox(height: 12),
          if (_chargement)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (liste.isEmpty)
            EmptyState(
              icon: Icons.event_busy_rounded,
              message: _segment == 0 ? 'Aucun rendez-vous à venir' : 'Aucun rendez-vous passé',
            )
          else
            for (final RdvDetail d in liste)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: RdvCard(
                  detail: d,
                  onTap: () => _ouvrir(d),
                  afficherPatient: !estPatient,
                  afficherMedecin: _u.role != Role.medecin,
                ),
              ),
        ],
      ),
    );
  }
}

class _FiltreSheet extends StatefulWidget {
  const _FiltreSheet({
    required this.initial,
    required this.medecins,
    required this.choixMedecin,
  });

  final RdvFiltre initial;
  final List<Medecin> medecins;
  final bool choixMedecin;

  @override
  State<_FiltreSheet> createState() => _FiltreSheetState();
}

class _FiltreSheetState extends State<_FiltreSheet> {
  late int? _medecinId = widget.initial.medecinId;
  late StatutRdv? _statut = widget.initial.statut;
  late TypeRdv? _type = widget.initial.type;
  late DateTime? _jour = widget.initial.jour;

  Future<void> _choisirJour() async {
    final DateTime n = DateTime.now();
    final DateTime? d = await showDatePicker(
      context: context,
      initialDate: _jour ?? n,
      firstDate: DateTime(n.year - 2),
      lastDate: DateTime(n.year + 2),
    );
    if (d != null) {
      setState(() => _jour = d);
    }
  }

  @override
  Widget build(BuildContext context) {
    final DateTime? jour = _jour;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Filtres', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          if (widget.choixMedecin) ...[
            AppDropdownField<int?>(
              label: 'Médecin',
              icon: Icons.medical_services_outlined,
              value: _medecinId,
              items: [
                const DropdownMenuItem<int?>(value: null, child: Text('Tous')),
                for (final Medecin m in widget.medecins)
                  DropdownMenuItem<int?>(value: m.id, child: Text(m.nomComplet)),
              ],
              onChanged: (int? v) => setState(() => _medecinId = v),
            ),
            const SizedBox(height: 14),
          ],
          AppDropdownField<StatutRdv?>(
            label: 'Statut',
            icon: Icons.flag_outlined,
            value: _statut,
            items: [
              const DropdownMenuItem<StatutRdv?>(value: null, child: Text('Tous')),
              for (final StatutRdv s in StatutRdv.values)
                DropdownMenuItem<StatutRdv?>(value: s, child: Text(s.libelle)),
            ],
            onChanged: (StatutRdv? v) => setState(() => _statut = v),
          ),
          const SizedBox(height: 14),
          AppDropdownField<TypeRdv?>(
            label: 'Type',
            icon: Icons.videocam_outlined,
            value: _type,
            items: [
              const DropdownMenuItem<TypeRdv?>(value: null, child: Text('Tous')),
              for (final TypeRdv t in TypeRdv.values)
                DropdownMenuItem<TypeRdv?>(value: t, child: Text(t.libelle)),
            ],
            onChanged: (TypeRdv? v) => setState(() => _type = v),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: _choisirJour,
            icon: const Icon(Icons.today_rounded),
            label: Text(
              jour == null ? 'Tous les jours' : '${jour.day}/${jour.month}/${jour.year}',
            ),
          ),
          if (jour != null)
            TextButton(
              onPressed: () => setState(() => _jour = null),
              child: const Text('Retirer le jour', style: TextStyle(color: AppColors.danger)),
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(
                    context,
                    RdvFiltre(texte: widget.initial.texte),
                  ),
                  child: const Text('Réinitialiser'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.pop(
                    context,
                    RdvFiltre(
                      texte: widget.initial.texte,
                      medecinId: _medecinId,
                      statut: _statut,
                      type: _type,
                      jour: _jour,
                    ),
                  ),
                  child: const Text('Appliquer'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
