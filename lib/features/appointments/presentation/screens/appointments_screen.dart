import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/placeholder_view.dart';
import '../../../../models/utilisateur.dart';
import '../../../../shared_providers/session.dart';
import '../../domain/rdv_permissions.dart';
import 'demande_urgente_screen.dart';
import 'prise_rdv_screen.dart';
import 'tabs/creneaux_tab.dart';
import 'tabs/file_attente_tab.dart';
import 'tabs/rdv_liste_tab.dart';
import 'tabs/rdv_patient_tab.dart';
import 'tabs/stats_rdv_tab.dart';

/// MODULE 4 — Rendez-vous & Téléconsultation.
///
/// Onglets selon le rôle connecté :
/// - Patient   : Mes RDV avec les boutons « Prendre RDV » et « Urgence » en haut
/// - Médecin   : File du jour · Mes RDV · Créneaux · Stats
/// - Infirmier : File du jour · Tous les RDV (+ RDV et urgence pour un patient)
/// - Admin     : Tous les RDV · File du jour · Créneaux · Stats
class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  /// Incrémenté après une création pour recharger les onglets.
  final ValueNotifier<int> _rafraichir = ValueNotifier<int>(0);

  @override
  void dispose() {
    _rafraichir.dispose();
    super.dispose();
  }

  Future<void> _prendreRdv(Utilisateur u) async {
    final bool? cree = await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(builder: (_) => PriseRdvScreen(utilisateur: u)),
    );
    if (cree == true) {
      _rafraichir.value++;
    }
  }

  Future<void> _urgence(Utilisateur u) async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(builder: (_) => DemandeUrgenteScreen(utilisateur: u)),
    );
    _rafraichir.value++;
  }

  @override
  Widget build(BuildContext context) {
    final Utilisateur? u = Session.utilisateur;
    if (u == null || !u.role.accesRdv) {
      return const PlaceholderView(
        title: 'Rendez-vous',
        icon: Icons.lock_outline,
        message: 'Connectez-vous pour accéder aux rendez-vous',
      );
    }

    final List<_Onglet> onglets = _onglets(u);
    final Widget? fab = _boutons(u);

    if (onglets.length == 1) {
      return Scaffold(
        appBar: AppBar(title: const Text('Mes rendez-vous')),
        floatingActionButton: fab,
        body: onglets.first.vue,
      );
    }

    return DefaultTabController(
      length: onglets.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Rendez-vous'),
          bottom: TabBar(
            isScrollable: onglets.length > 3,
            tabAlignment: onglets.length > 3 ? TabAlignment.start : null,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primary,
            indicatorSize: TabBarIndicatorSize.tab,
            tabs: [
              for (final _Onglet o in onglets) Tab(icon: Icon(o.icon), text: o.titre),
            ],
          ),
        ),
        floatingActionButton: fab,
        body: TabBarView(children: [for (final _Onglet o in onglets) o.vue]),
      ),
    );
  }

  List<_Onglet> _onglets(Utilisateur u) {
    final _Onglet liste = _Onglet(
      u.role.voirTousLesRdv ? 'Tous les RDV' : 'Mes RDV',
      Icons.event_note_rounded,
      RdvListeTab(utilisateur: u, rafraichir: _rafraichir),
    );
    final _Onglet file = _Onglet(
      'File du jour',
      Icons.format_list_numbered_rounded,
      FileAttenteTab(utilisateur: u, rafraichir: _rafraichir),
    );
    final _Onglet creneaux = _Onglet(
      'Créneaux',
      Icons.schedule_rounded,
      CreneauxTab(utilisateur: u),
    );
    final _Onglet stats = _Onglet(
      'Stats',
      Icons.insights_rounded,
      StatsRdvTab(utilisateur: u),
    );

    switch (u.role) {
      case Role.patient:
        // Boutons « Prendre RDV » et « Urgence » intégrés en haut de la page.
        return [
          _Onglet(
            'Mes RDV',
            Icons.event_note_rounded,
            RdvPatientTab(utilisateur: u, avecTitre: false),
          ),
        ];
      case Role.medecin:
        return [file, liste, creneaux, stats];
      case Role.infirmier:
        return [file, liste];
      case Role.admin:
        return [liste, file, creneaux, stats];
      case Role.ambulancier:
        return [];
    }
  }

  /// Boutons flottants : « Prendre RDV » et, si autorisé, « Urgence ».
  Widget? _boutons(Utilisateur u) {
    if (u.role == Role.patient) {
      return null; // déjà dans RdvPatientTab
    }
    final bool urgence = u.role.demandeUrgente;
    final bool rdv = u.role == Role.patient || u.role.prendreRdvPourAutrui;
    if (!urgence && !rdv) {
      return null;
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (urgence) ...[
          FloatingActionButton.extended(
            heroTag: 'fab_urgence',
            backgroundColor: AppColors.danger,
            foregroundColor: Colors.white,
            onPressed: () => _urgence(u),
            icon: const Icon(Icons.emergency_rounded),
            label: const Text('Urgence'),
          ),
          const SizedBox(height: 12),
        ],
        if (rdv)
          FloatingActionButton.extended(
            heroTag: 'fab_rdv',
            onPressed: () => _prendreRdv(u),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Prendre RDV'),
          ),
      ],
    );
  }
}

class _Onglet {
  const _Onglet(this.titre, this.icon, this.vue);

  final String titre;
  final IconData icon;
  final Widget vue;
}
