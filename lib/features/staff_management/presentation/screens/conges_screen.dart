import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../models/utilisateur.dart';
import '../../../../shared_providers/session.dart';
import '../../data/conge_repository.dart';
import '../../domain/conge_manager.dart';
import '../../domain/conges.dart';
import '../../domain/staff_models.dart';
import '../widgets/bouton_ajout.dart';
import '../widgets/info_chip.dart';
import 'demande_conge_screen.dart';

/// Admin : demandes de congé à valider ou refuser.
/// Médecin / infirmier : ses demandes, son solde et « Demander ».
class CongesScreen extends StatefulWidget {
  const CongesScreen({super.key, required this.role});

  final Role role;

  @override
  State<CongesScreen> createState() => _CongesScreenState();
}

class _CongesScreenState extends State<CongesScreen> {
  final CongeRepository _repo = CongeRepository();
  final CongeManager _manager = CongeManager();

  List<CongeDetail> _liste = [];
  int _solde = RegleConges.soldeAnnuel;

  /// Filtre de l'admin (null = toutes).
  StatutConge? _filtre = StatutConge.enAttente;
  bool _chargement = true;

  bool get _admin => widget.role.validerConges;
  int? get _moi => Session.utilisateur?.refId;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    final int? moi = _moi;
    List<CongeDetail> liste = [];
    int solde = _solde;
    if (_admin) {
      liste = await _repo.lister();
    } else if (moi != null) {
      liste = await _repo.lister(role: widget.role, demandeurId: moi);
      solde = await _manager.soldeRestant(widget.role, moi);
    }
    if (!mounted) return;
    setState(() {
      _liste = liste;
      _solde = solde;
      _chargement = false;
    });
  }

  Future<void> _nouvelleDemande() async {
    final int? moi = _moi;
    if (moi == null) return;
    final bool? envoyee = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => DemandeCongeScreen(
          role: widget.role,
          demandeurId: moi,
          solde: _solde,
        ),
      ),
    );
    if (envoyee == true) {
      _charger();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Demande envoyée à l'administration")),
      );
    }
  }

  Future<void> _valider(CongeDetail d) async {
    final int? id = d.conge.id;
    if (id == null) return;
    try {
      final ResultatConge r = await _manager.valider(id);
      if (!mounted) return;
      if (r.validee) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(r.message)));
      } else {
        await showDialog<void>(
          context: context,
          builder: (BuildContext ctx) => AlertDialog(
            icon: const Icon(Icons.groups_outlined, color: AppColors.danger),
            title: const Text('Effectif insuffisant'),
            content: Text(r.message),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Compris'),
              ),
            ],
          ),
        );
      }
    } on StaffException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
    _charger();
  }

  Future<void> _refuser(CongeDetail d) async {
    final int? id = d.conge.id;
    if (id == null) return;
    final String? motif = await showDialog<String>(
      context: context,
      builder: (_) => const _MotifRefusDialog(),
    );
    if (motif == null || !mounted) return;
    try {
      await _manager.refuser(id, motif);
    } on StaffException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
    _charger();
  }

  Future<void> _annuler(CongeDetail d) async {
    final int? id = d.conge.id;
    if (id == null) return;
    final bool ok = await showConfirmDialog(
      context,
      titre: 'Annuler cette demande ?',
      message: 'Du ${Formatters.date(d.conge.debut)} au ${Formatters.date(d.conge.fin)}.',
      confirmer: 'Annuler la demande',
      danger: true,
    );
    if (!ok || !mounted) return;
    try {
      await _manager.annuler(id);
    } on StaffException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
    _charger();
  }

  bool _annulable(Conge c) {
    final DateTime aujourdHui = RegleConges.jour(DateTime.now());
    return c.statut == StatutConge.enAttente ||
        (c.statut == StatutConge.validee &&
            RegleConges.jour(c.debut).isAfter(aujourdHui));
  }

  @override
  Widget build(BuildContext context) {
    int compter(StatutConge s) => _liste.where((d) => d.conge.statut == s).length;
    final StatutConge? filtre = _filtre;
    final List<CongeDetail> visibles = !_admin || filtre == null
        ? _liste
        : _liste.where((d) => d.conge.statut == filtre).toList();

    return Scaffold(
      appBar: AppBar(title: Text(_admin ? 'Demandes de congé' : 'Mes congés')),
      floatingActionButton: !_admin && _moi != null
          ? FloatingActionButton.extended(
              onPressed: _nouvelleDemande,
              icon: const Icon(Icons.add),
              label: const Text('Demander un congé'),
            )
          : null,
      body: _chargement
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (!_admin) _CarteSolde(solde: _solde),
                if (_admin)
                  SizedBox(
                    height: 54,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      children: [
                        FiltreRapide(
                          libelle: 'À traiter',
                          nombre: compter(StatutConge.enAttente),
                          selectionne: _filtre == StatutConge.enAttente,
                          couleur: AppColors.warning,
                          onTap: () => setState(() => _filtre = StatutConge.enAttente),
                        ),
                        const SizedBox(width: 8),
                        FiltreRapide(
                          libelle: 'Validés',
                          nombre: compter(StatutConge.validee),
                          selectionne: _filtre == StatutConge.validee,
                          couleur: AppColors.success,
                          onTap: () => setState(() => _filtre = StatutConge.validee),
                        ),
                        const SizedBox(width: 8),
                        FiltreRapide(
                          libelle: 'Refusés',
                          nombre: compter(StatutConge.refusee),
                          selectionne: _filtre == StatutConge.refusee,
                          couleur: AppColors.danger,
                          onTap: () => setState(() => _filtre = StatutConge.refusee),
                        ),
                        const SizedBox(width: 8),
                        FiltreRapide(
                          libelle: 'Toutes',
                          nombre: _liste.length,
                          selectionne: _filtre == null,
                          onTap: () => setState(() => _filtre = null),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: visibles.isEmpty
                      ? EmptyState(
                          icon: Icons.event_available_outlined,
                          message: _admin
                              ? 'Aucune demande'
                              : 'Aucune demande de congé pour le moment',
                        )
                      : RefreshIndicator(
                          onRefresh: _charger,
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                            itemCount: visibles.length,
                            separatorBuilder: (BuildContext context, int i) =>
                                const SizedBox(height: 10),
                            itemBuilder: (BuildContext context, int i) {
                              final CongeDetail d = visibles[i];
                              final bool aTraiter =
                                  d.conge.statut == StatutConge.enAttente;
                              return _CarteConge(
                                detail: d,
                                avecNom: _admin,
                                onValider: _admin && aTraiter ? () => _valider(d) : null,
                                onRefuser: _admin && aTraiter ? () => _refuser(d) : null,
                                onAnnuler: !_admin && _annulable(d.conge)
                                    ? () => _annuler(d)
                                    : null,
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

class _CarteSolde extends StatelessWidget {
  const _CarteSolde({required this.solde});

  final int solde;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.secondary],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Icon(Icons.beach_access_rounded, color: Colors.white, size: 32),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Congé annuel ${DateTime.now().year}',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                Text(
                  '$solde / ${RegleConges.soldeAnnuel} jours restants',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CarteConge extends StatelessWidget {
  const _CarteConge({
    required this.detail,
    required this.avecNom,
    this.onValider,
    this.onRefuser,
    this.onAnnuler,
  });

  final CongeDetail detail;
  final bool avecNom;
  final VoidCallback? onValider;
  final VoidCallback? onRefuser;
  final VoidCallback? onAnnuler;

  @override
  Widget build(BuildContext context) {
    final Conge c = detail.conge;
    final String? commentaire = c.commentaire;
    final VoidCallback? valider = onValider;
    final VoidCallback? refuser = onRefuser;
    final VoidCallback? annuler = onAnnuler;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (avecNom) ...[
                      Text(
                        detail.nom ?? 'Personnel supprimé',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        '${c.role.libelle} · ${detail.serviceNom ?? 'Sans service'}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                    ],
                    Text(
                      c.type.libelle,
                      style: TextStyle(
                        fontSize: avecNom ? 13 : 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _StatutBadge(statut: c.statut),
            ],
          ),
          const SizedBox(height: 8),
          InfoChip(
            icon: Icons.date_range_rounded,
            texte: '${Formatters.date(c.debut)} → ${Formatters.date(c.fin)} · '
                '${c.nbJours} jour(s)',
          ),
          if (c.motif.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              c.motif,
              style: const TextStyle(
                fontSize: 13,
                fontStyle: FontStyle.italic,
                color: AppColors.textSecondary,
              ),
            ),
          ],
          if (commentaire != null && commentaire.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                commentaire,
                style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
              ),
            ),
          ],
          if (valider != null || refuser != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: refuser,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.danger,
                    ),
                    child: const Text('Refuser'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: valider,
                    child: const Text('Valider'),
                  ),
                ),
              ],
            ),
          ],
          if (annuler != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: annuler,
                style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                child: const Text('Annuler la demande'),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatutBadge extends StatelessWidget {
  const _StatutBadge({required this.statut});

  final StatutConge statut;

  @override
  Widget build(BuildContext context) {
    switch (statut) {
      case StatutConge.enAttente:
        return StatusBadge(
          libelle: statut.libelle,
          icon: Icons.hourglass_top_rounded,
          couleur: AppColors.warning,
        );
      case StatutConge.validee:
        return StatusBadge(
          libelle: statut.libelle,
          icon: Icons.check_circle_rounded,
          couleur: AppColors.success,
        );
      case StatutConge.refusee:
        return StatusBadge(
          libelle: statut.libelle,
          icon: Icons.cancel_rounded,
          couleur: AppColors.danger,
        );
      case StatutConge.annulee:
        return StatusBadge(
          libelle: statut.libelle,
          icon: Icons.block_rounded,
          couleur: AppColors.textSecondary,
        );
    }
  }
}

class _MotifRefusDialog extends StatefulWidget {
  const _MotifRefusDialog();

  @override
  State<_MotifRefusDialog> createState() => _MotifRefusDialogState();
}

class _MotifRefusDialogState extends State<_MotifRefusDialog> {
  final TextEditingController _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Refuser la demande'),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        maxLines: 3,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(
          labelText: 'Motif du refus',
          hintText: 'Ex : période de forte activité',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        ListenableBuilder(
          listenable: _ctrl,
          builder: (BuildContext context, Widget? _) => FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: _ctrl.text.trim().isEmpty
                ? null
                : () => Navigator.pop(context, _ctrl.text.trim()),
            child: const Text('Refuser'),
          ),
        ),
      ],
    );
  }
}
