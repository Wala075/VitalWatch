import 'package:flutter/material.dart';

import '../../../../core/widgets/placeholder_view.dart';
import '../../../../models/utilisateur.dart';
import '../../../../shared_providers/session.dart';
import '../../domain/prescriptions_permissions.dart';
import '../widgets/ui_commun.dart';
import 'tabs/apci_tab.dart';
import 'tabs/assurances_tab.dart';
import 'tabs/aujourdhui_tab.dart';
import 'tabs/catalogue_tab.dart';
import 'tabs/delivrance_tab.dart';
import 'tabs/dossiers_tab.dart';
import 'tabs/mes_ordonnances_tab.dart';
import 'tabs/ordonnances_tab.dart';
import 'tabs/patients_tab.dart';
import 'tabs/remboursements_tab.dart';
import 'tabs/stats_tab.dart';
import 'tabs/stock_tab.dart';

/// MODULE 5 — Ordonnances & Assurance.
/// Les onglets dépendent du profil connecté (voir PrescriptionsPermissions) :
/// - admin : catalogue, assurances, patients (contrats), dossiers, statistiques ;
/// - médecin : ses ordonnances, APCI (maladies), catalogue, statistiques ;
/// - pharmacien : délivrance, stock, APCI (médicaments couverts) ;
/// - infirmier : patients, catalogue ;
/// - patient : aujourd'hui, ses ordonnances, ses remboursements.
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

    // Le compte pointe vers medecins.id ou patients.id via utilisateurs.ref_id.
    final int? refId = Session.utilisateur?.refId;
    if ((role.prescrire || role.espacePatient) && refId == null) {
      return const PlaceholderView(
        title: 'Ordonnances & Assurance',
        icon: Icons.link_off_rounded,
        message: "Ce compte n'est relié à aucune fiche",
      );
    }

    final List<_Onglet> onglets = [];
    if (role.espacePatient && refId != null) {
      onglets.add(_Onglet(
        const NavItem(Icons.today_rounded, "Aujourd'hui"),
        (Key k) => AujourdhuiTab(key: k, patientId: refId),
      ));
      onglets.add(_Onglet(
        const NavItem(Icons.description_rounded, 'Ordonnances'),
        (Key k) => MesOrdonnancesTab(key: k, patientId: refId),
      ));
      onglets.add(_Onglet(
        const NavItem(Icons.receipt_long_rounded, 'Remboursements'),
        (Key k) => RemboursementsTab(key: k, patientId: refId),
      ));
    } else {
      if (role.prescrire && refId != null) {
        onglets.add(_Onglet(
          const NavItem(Icons.description_rounded, 'Ordonnances'),
          (Key k) => OrdonnancesTab(key: k, medecinId: refId),
        ));
      }
      if (role.delivrer) {
        onglets.add(_Onglet(
          const NavItem(Icons.qr_code_scanner_rounded, 'Délivrance'),
          (Key k) => DelivranceTab(key: k),
        ));
      }
      if (role.gererStock) {
        onglets.add(_Onglet(
          const NavItem(Icons.inventory_2_rounded, 'Stock'),
          (Key k) => StockTab(key: k),
        ));
      }
      // Médecin : avant le catalogue ; pharmacien : après le stock.
      if (role.voirApci) {
        onglets.add(_Onglet(
          const NavItem(Icons.favorite_rounded, 'APCI'),
          (Key k) => ApciTab(key: k, role: role),
        ));
      }
      if (role.voirPatients && !role.gererReferentiels) {
        onglets.add(_Onglet(
          const NavItem(Icons.people_alt_rounded, 'Patients'),
          (Key k) => PatientsTab(key: k, role: role),
        ));
      }
      // Le pharmacien consulte les médicaments dans l'onglet Stock.
      if (!role.gererStock) {
        onglets.add(_Onglet(
          const NavItem(Icons.medication_rounded, 'Catalogue'),
          (Key k) => CatalogueTab(key: k, role: role),
        ));
      }
      if (role.gererReferentiels) {
        onglets.add(_Onglet(
          const NavItem(Icons.shield_rounded, 'Assurances'),
          (Key k) => AssurancesTab(key: k, role: role),
        ));
        onglets.add(_Onglet(
          const NavItem(Icons.people_alt_rounded, 'Patients'),
          (Key k) => PatientsTab(key: k, role: role),
        ));
      }
      if (role.traiterDossiers) {
        onglets.add(_Onglet(
          const NavItem(Icons.receipt_long_rounded, 'Dossiers'),
          (Key k) => DossiersTab(key: k),
        ));
      }
      if (role.voirStatistiques) {
        final int? medecinId = role.prescrire ? refId : null;
        onglets.add(_Onglet(
          const NavItem(Icons.insights_rounded, 'Stats'),
          (Key k) => StatsTab(key: k, medecinId: medecinId),
        ));
      }
    }
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
