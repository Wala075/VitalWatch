import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../shared_providers/session.dart';
import '../../data/ambulance_repository.dart';
import '../../data/ambulancier_repository.dart';
import '../../data/maintenance_repository.dart';
import '../../domain/ambulance_permissions.dart';
import '../../domain/dispatch_models.dart';
import '../../domain/models/ambulance.dart';
import '../../domain/models/maintenance.dart';
import '../providers/dispatch_controller.dart';
import '../widgets/dispatch_ui.dart';
import 'ambulance_form_screen.dart';
import 'maintenance_form_screen.dart';

/// Fiche ambulance : état, entretien préventif, équipage, maintenances.
class AmbulanceDetailScreen extends StatefulWidget {
  const AmbulanceDetailScreen({super.key, required this.ambulanceId});

  final int ambulanceId;

  @override
  State<AmbulanceDetailScreen> createState() => _AmbulanceDetailScreenState();
}

class _AmbulanceDetailScreenState extends State<AmbulanceDetailScreen> {
  final AmbulanceRepository _ambulances = AmbulanceRepository();
  final AmbulancierRepository _equipiers = AmbulancierRepository();
  final MaintenanceRepository _maintenances = MaintenanceRepository();
  final DispatchController _ctrl = DispatchController.instance;

  AmbulanceDetail? _detail;
  List<AmbulancierDetail> _equipage = [];
  List<MaintenanceDetail> _historique = [];
  bool _chargement = true;
  bool _modifie = false;

  bool get _gerer => Session.utilisateur?.role.gererFlotte ?? false;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    final AmbulanceDetail? d = await _ambulances.detailParId(widget.ambulanceId);
    final List<AmbulancierDetail> e =
        await _equipiers.rechercher(ambulanceId: widget.ambulanceId);
    final List<MaintenanceDetail> h =
        await _maintenances.rechercher(ambulanceId: widget.ambulanceId);
    if (!mounted) {
      return;
    }
    setState(() {
      _detail = d;
      _equipage = e;
      _historique = h;
      _chargement = false;
    });
  }

  Future<void> _apres(Future<bool?> action) async {
    final bool? ok = await action;
    if (ok == true) {
      _modifie = true;
      await _charger();
    }
  }

  Future<void> _modifier(Ambulance a) async {
    await _apres(Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => AmbulanceFormScreen(ambulance: a)),
    ));
  }

  Future<void> _nouvelleMaintenance(Ambulance a, [Maintenance? m]) async {
    await _apres(Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => MaintenanceFormScreen(ambulance: a, maintenance: m),
      ),
    ));
  }

  Future<void> _basculerService(Ambulance a) async {
    final int? id = a.id;
    if (id == null) {
      return;
    }
    final bool versHorsService = a.statut != StatutAmbulance.horsService;
    try {
      await _ctrl.manager.changerDisponibilite(id, horsService: versHorsService);
      await _ctrl.rafraichir();
      _modifie = true;
      await _charger();
      if (mounted) {
        DispatchUi.snack(
          context,
          versHorsService ? '${a.immatriculation} hors service' : '${a.immatriculation} remise en service',
        );
      }
    } on DispatchException catch (e) {
      if (mounted) {
        DispatchUi.snack(context, e.message, erreur: true);
      }
    }
  }

  Future<void> _supprimer(Ambulance a) async {
    final int? id = a.id;
    if (id == null) {
      return;
    }
    final bool ok = await showConfirmDialog(
      context,
      titre: 'Supprimer ${a.immatriculation}',
      message: "L'équipage sera désaffecté et l'historique des interventions conservé.",
      confirmer: 'Supprimer',
      danger: true,
    );
    if (!ok) {
      return;
    }
    try {
      await _ctrl.manager.supprimerAmbulance(id);
      await _ctrl.rafraichir();
      if (mounted) {
        Navigator.pop(context, true);
      }
    } on DispatchException catch (e) {
      if (mounted) {
        DispatchUi.snack(context, e.message, erreur: true);
      }
    }
  }

  Future<void> _terminerMaintenance(Ambulance a, Maintenance m) async {
    final bool ok =
        await showTerminerMaintenanceDialog(context, ambulance: a, maintenance: m);
    if (ok) {
      _modifie = true;
      await _charger();
      if (mounted) {
        DispatchUi.snack(context, 'Maintenance terminée, seuil kilométrique mis à jour');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AmbulanceDetail? d = _detail;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) {
          Navigator.pop(context, _modifie);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(d?.ambulance.immatriculation ?? 'Ambulance'),
          actions: [
            if (d != null && _gerer) ...[
              IconButton(
                tooltip: 'Modifier',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => _modifier(d.ambulance),
              ),
              PopupMenuButton<String>(
                onSelected: (String choix) {
                  if (choix == 'service') {
                    _basculerService(d.ambulance);
                  } else if (choix == 'supprimer') {
                    _supprimer(d.ambulance);
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'service',
                    child: Text(
                      d.ambulance.statut == StatutAmbulance.horsService
                          ? 'Remettre en service'
                          : 'Déclarer hors service',
                    ),
                  ),
                  const PopupMenuItem(value: 'supprimer', child: Text('Supprimer')),
                ],
              ),
            ],
          ],
        ),
        floatingActionButton: d != null && _gerer
            ? FloatingActionButton.extended(
                heroTag: 'fab_maintenance',
                onPressed: () => _nouvelleMaintenance(d.ambulance),
                icon: const Icon(Icons.build_outlined),
                label: const Text('Maintenance'),
              )
            : null,
        body: _chargement
            ? const Center(child: CircularProgressIndicator())
            : d == null
                ? const Center(child: Text('Ambulance introuvable'))
                : RefreshIndicator(
                    onRefresh: _charger,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                      children: [
                        _Entete(detail: d),
                        const SizedBox(height: 14),
                        _Entretien(detail: d),
                        const SizedBox(height: 14),
                        _blocEquipage(),
                        const SizedBox(height: 14),
                        _blocMaintenances(d.ambulance),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _blocEquipage() {
    return Section(
      titre: 'Équipage (${_equipage.length})',
      icone: Icons.groups_outlined,
      children: [
        if (_equipage.isEmpty)
          const Info(
            icone: Icons.warning_amber_rounded,
            texte: 'Aucun ambulancier : cette ambulance ne peut pas être dispatchée',
            couleur: AppColors.danger,
          ),
        for (final AmbulancierDetail e in _equipage)
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                child: Text(
                  e.ambulancier.initiales,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e.ambulancier.nom, style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text(
                      '${e.ambulancier.role.libelle} · ${Formatters.telephone(e.ambulancier.telephone)}',
                      style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Pastille(
                libelle: e.ambulancier.disponible ? 'Disponible' : 'Absent',
                couleur: e.ambulancier.disponible ? AppColors.success : AppColors.textSecondary,
              ),
            ],
          ),
      ],
    );
  }

  Widget _blocMaintenances(Ambulance a) {
    return Section(
      titre: 'Maintenances (${_historique.length})',
      icone: Icons.build_circle_outlined,
      children: [
        if (_historique.isEmpty)
          const Info(icone: Icons.info_outline, texte: 'Aucune maintenance enregistrée'),
        for (final MaintenanceDetail md in _historique)
          _LigneMaintenance(
            maintenance: md.maintenance,
            onTerminer: _gerer && md.maintenance.statut != StatutMaintenance.terminee
                ? () => _terminerMaintenance(a, md.maintenance)
                : null,
            onModifier: _gerer ? () => _nouvelleMaintenance(a, md.maintenance) : null,
          ),
      ],
    );
  }
}

class _Entete extends StatelessWidget {
  const _Entete({required this.detail});

  final AmbulanceDetail detail;

  @override
  Widget build(BuildContext context) {
    final Ambulance a = detail.ambulance;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: DispatchUi.statutAmbulance(a.statut).withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.airport_shuttle,
                    color: DispatchUi.statutAmbulance(a.statut),
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        a.immatriculation,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                      ),
                      Text(
                        '${a.type.libelle} · ${a.type.description}',
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                PastilleStatutAmbulance(a.statut),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 16,
              runSpacing: 6,
              children: [
                Info(icone: Icons.speed, texte: DispatchUi.kilometrage(a.kilometrage)),
                Info(
                  icone: Icons.groups_outlined,
                  texte: '${detail.nbEquipiersDisponibles}/${detail.nbEquipiers} équipier(s) dispo',
                ),
                Info(icone: Icons.task_alt, texte: '${detail.nbMissions} mission(s)'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Jauge : kilomètres restants avant l'entretien préventif.
class _Entretien extends StatelessWidget {
  const _Entretien({required this.detail});

  final AmbulanceDetail detail;

  @override
  Widget build(BuildContext context) {
    final int? seuil = detail.seuilEntretienKm;
    final int? reste = detail.kmAvantEntretien;
    Color couleur = AppColors.success;
    String texte = 'Aucun seuil défini : enregistrez un entretien';
    double valeur = 0;

    if (seuil != null && reste != null) {
      // Jauge sur un intervalle de référence de 20 000 km
      valeur = (1 - reste / 20000).clamp(0.0, 1.0).toDouble();
      if (detail.seuilDepasse) {
        couleur = AppColors.danger;
        texte = 'Seuil de ${DispatchUi.kilometrage(seuil)} dépassé : ambulance bloquée';
      } else if (detail.entretienProche) {
        couleur = AppColors.warning;
        texte = 'Entretien proche : plus que ${DispatchUi.kilometrage(reste)}';
      } else {
        texte = 'Prochain entretien à ${DispatchUi.kilometrage(seuil)} '
            '(dans ${DispatchUi.kilometrage(reste)})';
      }
    }

    return Section(
      titre: 'Maintenance préventive',
      icone: Icons.health_and_safety_outlined,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: valeur,
            minHeight: 10,
            backgroundColor: AppColors.surfaceGrey,
            color: couleur,
          ),
        ),
        Info(
          icone: detail.seuilDepasse ? Icons.lock_outline : Icons.flag_outlined,
          texte: texte,
          couleur: couleur == AppColors.success ? null : couleur,
        ),
        if (detail.nbMaintenancesEnCours > 0)
          const Info(
            icone: Icons.build,
            texte: 'Maintenance en cours : non dispatchable',
            couleur: AppColors.warning,
          ),
      ],
    );
  }
}

class _LigneMaintenance extends StatelessWidget {
  const _LigneMaintenance({required this.maintenance, this.onTerminer, this.onModifier});

  final Maintenance maintenance;
  final VoidCallback? onTerminer;
  final VoidCallback? onModifier;

  @override
  Widget build(BuildContext context) {
    final Maintenance m = maintenance;
    final int? prochain = m.prochainEntretienKm;
    final VoidCallback? terminer = onTerminer;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onModifier,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(Icons.circle, size: 10, color: DispatchUi.statutMaintenance(m.statut)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(m.type.libelle, style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text(
                    '${Formatters.date(m.date)} · ${DispatchUi.cout(m.cout)}'
                    '${prochain == null ? '' : ' · prochain à ${DispatchUi.kilometrage(prochain)}'}',
                    style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            if (terminer != null)
              TextButton(onPressed: terminer, child: const Text('Terminer'))
            else
              Pastille(
                libelle: m.statut.libelle,
                couleur: DispatchUi.statutMaintenance(m.statut),
              ),
          ],
        ),
      ),
    );
  }
}
