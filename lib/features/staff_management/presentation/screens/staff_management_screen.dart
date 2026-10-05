import 'package:flutter/material.dart';

import '../../../../core/widgets/app_background.dart';
import '../../../../core/widgets/floating_nav_bar.dart';
import '../../../../core/widgets/placeholder_view.dart';
import '../../../../models/utilisateur.dart';
import '../../../../shared_providers/session.dart';
import 'tabs/accueil_tab.dart';
import 'tabs/medecins_tab.dart';
import 'tabs/patients_tab.dart';
import 'tabs/services_tab.dart';

/// MODULE 1 — Espace du personnel (admin, médecins, infirmiers).
/// L'admin a accès à tout ; médecins et infirmiers ont des droits limités
/// (voir RolePermissions dans models/utilisateur.dart).
class StaffManagementScreen extends StatefulWidget {
  const StaffManagementScreen({super.key});

  @override
  State<StaffManagementScreen> createState() => _StaffManagementScreenState();
}

class _StaffManagementScreenState extends State<StaffManagementScreen> {
  int _onglet = 0;

  void _aller(int index) => setState(() => _onglet = index);

  @override
  Widget build(BuildContext context) {
    final Role? role = Session.utilisateur?.role;
    if (role == null || !role.accesPersonnel) {
      return const PlaceholderView(
        title: 'Espace personnel',
        icon: Icons.lock_outline,
        message: 'Accès réservé au personnel',
      );
    }

    // Seul l'onglet affiché est construit : ses données sont rechargées
    // à chaque fois qu'on y revient.
    final Widget page = switch (_onglet) {
      1 => MedecinsTab(key: const ValueKey<int>(1), role: role),
      2 => PatientsTab(key: const ValueKey<int>(2), role: role),
      3 => ServicesTab(key: const ValueKey<int>(3), role: role),
      _ => AccueilTab(key: const ValueKey<int>(0), role: role, onAller: _aller),
    };

    return Scaffold(
      extendBody: true,
      body: AppBackground(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: page,
        ),
      ),
      bottomNavigationBar: FloatingNavBar(
        items: const [
          NavItem(Icons.dashboard_rounded, 'Accueil'),
          NavItem(Icons.medical_services_rounded, 'Médecins'),
          NavItem(Icons.people_alt_rounded, 'Patients'),
          NavItem(Icons.apartment_rounded, 'Services'),
        ],
        index: _onglet,
        onTap: _aller,
      ),
    );
  }
}
