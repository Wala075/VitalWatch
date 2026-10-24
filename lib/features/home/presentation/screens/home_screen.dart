import 'package:flutter/material.dart';

import '../../../../models/utilisateur.dart';
import '../../../appointments/presentation/screens/tabs/rdv_patient_tab.dart';
import '../../../appointments/presentation/widgets/appel_urgent_watcher.dart';
import '../../../../shared_providers/session.dart';
import '../../data/demo_store.dart';
import '../widgets/app_background.dart';
import '../widgets/floating_nav_bar.dart';
import 'tabs/doctors_tab.dart';
import 'tabs/gestion_tab.dart';
import 'tabs/health_tab.dart';
import 'tabs/home_tab.dart';
import 'tabs/schedule_tab.dart';

/// Écran principal : Accueil, Médecins, Planning, Santé
/// (+ Gestion pour le personnel) avec barre de navigation flottante.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DemoStore _store = DemoStore.instance;

  @override
  void initState() {
    super.initState();
    _store.onglet = 0;
    _store.addListener(_rafraichir);
  }

  void _rafraichir() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _store.removeListener(_rafraichir);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Utilisateur? u = Session.utilisateur;
    final Role? role = u?.role;
    final bool personnel = role != null && role != Role.patient;
    final bool patient = u != null && role == Role.patient;

    final List<Widget> pages = [
      const HomeTab(),
      const DoctorsTab(),
      // Patient : vrais RDV du module 4 (type présentiel / visio + urgence).
      if (u != null && patient) RdvPatientTab(utilisateur: u) else const ScheduleTab(),
      const HealthTab(),
      if (personnel) const GestionTab(),
    ];
    final List<NavItem> items = [
      const NavItem(Icons.home_rounded, 'Accueil'),
      const NavItem(Icons.medical_services_rounded, 'Médecins'),
      NavItem(
        Icons.calendar_month_rounded,
        'Planning',
        badge: patient ? 0 : _store.aVenir.length,
      ),
      const NavItem(Icons.monitor_heart_rounded, 'Santé'),
      if (personnel) const NavItem(Icons.dashboard_customize_rounded, 'Gestion'),
    ];
    final int index = _store.onglet < pages.length ? _store.onglet : 0;

    return Scaffold(
      extendBody: true,
      // Médecin : sonne quand un patient fait une demande urgente (module 4).
      body: AppelUrgentWatcher(
        child: AppBackground(
          child: IndexedStack(
            index: index,
            children: [
              for (int i = 0; i < pages.length; i++)
                TickerMode(enabled: i == index, child: pages[i]),
            ],
          ),
        ),
      ),
      bottomNavigationBar: FloatingNavBar(
        items: items,
        index: index,
        onTap: (int i) => _store.allerA(i),
      ),
    );
  }
}
