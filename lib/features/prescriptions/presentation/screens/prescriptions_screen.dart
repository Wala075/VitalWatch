import 'package:flutter/material.dart';

import '../../../../core/widgets/placeholder_view.dart';
import '../../../../models/utilisateur.dart';
import '../../../../shared_providers/session.dart';
import '../../domain/prescriptions_permissions.dart';
import '../widgets/ui_commun.dart';
import 'tabs/apci_tab.dart';
import 'tabs/assurances_tab.dart';
import 'tabs/catalogue_tab.dart';

/// MODULE 5 — Ordonnances & Assurance.
/// Les onglets dépendent du profil connecté (voir PrescriptionsPermissions).
class PrescriptionsScreen extends StatefulWidget {
  const PrescriptionsScreen({super.key});

  @override
  State<PrescriptionsScreen> createState() => _PrescriptionsScreenState();
}

class _PrescriptionsScreenState extends State<PrescriptionsScreen> {
  int _onglet = 0;

  @override
  Widget build(BuildContext context) {
    final Role? role = Session.utilisateur?.role;
    if (role == null || !role.accesOrdonnances) {
      return const PlaceholderView(
        title: 'Ordonnances & Assurance',
        icon: Icons.lock_outline,
        message: 'Accès non autorisé pour ce profil',
      );
    }

    final List<_Onglet> onglets = [
      _Onglet(
        const NavItem(Icons.medication_rounded, 'Catalogue'),
        (Key k) => CatalogueTab(key: k, role: role),
      ),
      if (role.gererReferentiels) ...[
        _Onglet(
          const NavItem(Icons.shield_rounded, 'Assurances'),
          (Key k) => AssurancesTab(key: k, role: role),
        ),
        _Onglet(
          const NavItem(Icons.favorite_rounded, 'APCI'),
          (Key k) => ApciTab(key: k, role: role),
        ),
      ],
    ];
    final int index = _onglet < onglets.length ? _onglet : 0;

    // Seul l'onglet affiché est construit : ses données sont rechargées
    // à chaque fois qu'on y revient.
    return Scaffold(
      extendBody: true,
      body: AppBackground(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: onglets[index].construire(ValueKey<int>(index)),
        ),
      ),
      bottomNavigationBar: onglets.length < 2
          ? null
          : FloatingNavBar(
              items: [for (final _Onglet o in onglets) o.item],
              index: index,
              onTap: (int i) => setState(() => _onglet = i),
            ),
    );
  }
}

class _Onglet {
  const _Onglet(this.item, this.construire);

  final NavItem item;
  final Widget Function(Key key) construire;
}
