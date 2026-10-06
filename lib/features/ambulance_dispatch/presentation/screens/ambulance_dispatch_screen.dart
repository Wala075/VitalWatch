import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../models/utilisateur.dart';
import '../../../../shared_providers/session.dart';
import '../../domain/ambulance_permissions.dart';
import '../providers/dispatch_controller.dart';
import '../widgets/dispatch_ui.dart';
import 'sos_screen.dart';
import 'suivi_cardiaque_screen.dart';
import 'tabs/carte_tab.dart';
import 'tabs/equipages_tab.dart';
import 'tabs/flotte_tab.dart';
import 'tabs/interventions_tab.dart';
import 'tabs/ma_mission_tab.dart';
import 'tabs/stats_tab.dart';

/// MODULE 3 — Ambulances & Interventions.
///
/// - Régulation (admin, médecin, infirmier) : carte temps réel,
///   interventions, flotte, équipages ; KPI + heatmap (admin, médecin).
/// - Ambulancier : sa mission, la carte, ses interventions.
/// - Patient : bouton SOS + suivi de l'ambulance ; sa montre (rythme
///   cardiaque) se connecte depuis son espace uniquement.
/// - Suivi cardiaque (admin, médecin, infirmier) : mesures envoyées par les
///   téléphones des patients, lues dans la base.
class AmbulanceDispatchScreen extends StatefulWidget {
  const AmbulanceDispatchScreen({super.key});

  @override
  State<AmbulanceDispatchScreen> createState() => _AmbulanceDispatchScreenState();
}

class _AmbulanceDispatchScreenState extends State<AmbulanceDispatchScreen> {
  final DispatchController _ctrl = DispatchController.instance;
  int? _ambulanceAmbulancier;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_afficherEvenements);
    _ctrl.demarrer();
  }

  @override
  void dispose() {
    _ctrl.removeListener(_afficherEvenements);
    super.dispose();
  }

  /// Affiche les décisions automatiques (dispatch, blocage, arrivée...).
  void _afficherEvenements() {
    final List<String> evenements = _ctrl.prendreEvenements();
    if (evenements.isEmpty || !mounted) {
      return;
    }
    DispatchUi.snack(context, evenements.join('\n'));
  }

  @override
  Widget build(BuildContext context) {
    final Role role = Session.utilisateur?.role ?? Role.patient;
    if (!role.accesRegulation) {
      return const SosScreen();
    }

    final bool ambulancier = role == Role.ambulancier;
    final List<Tab> onglets = [];
    final List<Widget> vues = [];

    if (ambulancier) {
      onglets.add(const Tab(icon: Icon(Icons.assignment_ind_outlined), text: 'Ma mission'));
      vues.add(MaMissionTab(
        surAmbulance: (int? id) {
          if (mounted && id != _ambulanceAmbulancier) {
            setState(() => _ambulanceAmbulancier = id);
          }
        },
      ));
    }
    onglets.add(const Tab(icon: Icon(Icons.map_outlined), text: 'Carte'));
    vues.add(CarteTab(peutCreer: role.creerIntervention));
    onglets.add(const Tab(icon: Icon(Icons.emergency_outlined), text: 'Interventions'));
    vues.add(InterventionsTab(
      peutCreer: role.creerIntervention,
      ambulanceId: ambulancier ? _ambulanceAmbulancier : null,
    ));
    if (!ambulancier) {
      onglets.add(const Tab(icon: Icon(Icons.airport_shuttle_outlined), text: 'Flotte'));
      vues.add(FlotteTab(gerer: role.gererFlotte));
      onglets.add(const Tab(icon: Icon(Icons.groups_outlined), text: 'Équipages'));
      vues.add(EquipagesTab(gerer: role.gererFlotte));
    }
    if (role.voirKpi) {
      onglets.add(const Tab(icon: Icon(Icons.insights), text: 'Statistiques'));
      vues.add(const StatsTab());
    }

    return DefaultTabController(
      length: onglets.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Ambulances & Interventions'),
          actions: [
            if (role.suiviCardiaque)
              IconButton(
                tooltip: 'Suivi cardiaque des patients',
                icon: const Icon(Icons.monitor_heart_outlined, color: AppColors.danger),
                onPressed: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute(builder: (_) => const SuiviCardiaqueScreen()),
                ),
              ),
            _menuSimulation(),
          ],
          bottom: TabBar(
            tabs: onglets,
            isScrollable: onglets.length > 4,
            tabAlignment: onglets.length > 4 ? TabAlignment.start : null,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primary,
            indicatorSize: TabBarIndicatorSize.tab,
          ),
        ),
        body: TabBarView(
          // La carte capte les glissements : pas de swipe entre onglets
          physics: const NeverScrollableScrollPhysics(),
          children: vues,
        ),
      ),
    );
  }

  /// Simulation du déplacement des ambulances (démo sans GPS embarqué).
  Widget _menuSimulation() {
    return ListenableBuilder(
      listenable: _ctrl,
      builder: (BuildContext context, Widget? _) {
        return PopupMenuButton<int>(
          tooltip: 'Simulation',
          icon: Icon(
            _ctrl.simulation ? Icons.speed : Icons.pause_circle_outline,
            color: _ctrl.simulation ? AppColors.purple : AppColors.textSecondary,
          ),
          onSelected: (int v) {
            if (v == 0) {
              _ctrl.basculerSimulation(!_ctrl.simulation);
            } else {
              _ctrl.basculerSimulation(true);
              _ctrl.changerVitesse(v);
            }
          },
          itemBuilder: (_) => [
            PopupMenuItem<int>(
              value: 0,
              child: Text(_ctrl.simulation ? 'Mettre la simulation en pause' : 'Reprendre la simulation'),
            ),
            const PopupMenuDivider(),
            for (final int v in [1, 5, 10, 30])
              CheckedPopupMenuItem<int>(
                value: v,
                checked: _ctrl.simulation && _ctrl.vitesse == v,
                child: Text(v == 1 ? 'Temps réel (×1)' : 'Accéléré ×$v'),
              ),
          ],
        );
      },
    );
  }
}
