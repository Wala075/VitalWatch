import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/empty_state.dart';
import '../../../../../shared_providers/session.dart';
import '../../../data/ambulancier_repository.dart';
import '../../../domain/dispatch_models.dart';
import '../../../domain/models/ambulance.dart';
import '../../../domain/models/ambulancier.dart';
import '../../providers/dispatch_controller.dart';
import '../../widgets/dispatch_ui.dart';
import '../intervention_detail_screen.dart';
import 'interventions_tab.dart';

/// Vue ambulancier : son ambulance, sa mission en cours, partage GPS.
class MaMissionTab extends StatefulWidget {
  const MaMissionTab({super.key, required this.surAmbulance});

  /// Remonte l'ambulance de l'ambulancier (filtre de l'onglet Interventions).
  final ValueChanged<int?> surAmbulance;

  @override
  State<MaMissionTab> createState() => _MaMissionTabState();
}

class _MaMissionTabState extends State<MaMissionTab> {
  final DispatchController _ctrl = DispatchController.instance;
  final AmbulancierRepository _repo = AmbulancierRepository();

  Ambulancier? _moi;
  bool _chargement = true;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    final int? ref = Session.utilisateur?.refId;
    final Ambulancier? a = ref == null ? null : await _repo.parId(ref);
    if (!mounted) {
      return;
    }
    setState(() {
      _moi = a;
      _chargement = false;
    });
    widget.surAmbulance(a?.ambulanceId);
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
    if (_chargement) {
      return const Center(child: CircularProgressIndicator());
    }
    final Ambulancier? moi = _moi;
    final int? ambId = moi?.ambulanceId;
    if (moi == null || ambId == null) {
      return const EmptyState(
        icon: Icons.airport_shuttle_outlined,
        message: "Vous n'êtes affecté à aucune ambulance.\nContactez le régulateur.",
      );
    }

    return ListenableBuilder(
      listenable: _ctrl,
      builder: (BuildContext context, Widget? _) {
        final Ambulance? amb = _ctrl.ambulanceParId(ambId);
        final InterventionDetail? mission = _ctrl.missionDe(ambId);
        final int? missionId = mission?.intervention.id;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Bonjour ${moi.nom}',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            Text(moi.role.libelle, style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            if (amb != null)
              Section(
                titre: amb.immatriculation,
                icone: Icons.airport_shuttle,
                action: PastilleStatutAmbulance(amb.statut),
                children: [
                  Info(icone: Icons.category_outlined, texte: '${amb.type.libelle} · ${amb.type.description}'),
                  Info(icone: Icons.speed, texte: DispatchUi.kilometrage(amb.kilometrage)),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    secondary: const Icon(Icons.gps_fixed),
                    title: const Text('Partager ma position GPS'),
                    subtitle: const Text("Le centre suit l'ambulance en temps réel"),
                    value: _ctrl.ambulanceGps == ambId,
                    onChanged: (bool v) => _basculerGps(ambId, v),
                  ),
                ],
              ),
            const SizedBox(height: 16),
            const Text(
              'Mission en cours',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            if (mission == null)
              const Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'Aucune mission : vous êtes en attente de dispatch.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              )
            else
              CarteIntervention(
                detail: mission,
                suivi: missionId == null ? null : _ctrl.suiviDe(missionId),
                onTap: missionId == null
                    ? null
                    : () => Navigator.push<void>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => InterventionDetailScreen(interventionId: missionId),
                          ),
                        ),
              ),
          ],
        );
      },
    );
  }
}
