import 'package:flutter/material.dart';

import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../models/utilisateur.dart';
import '../../../../shared_providers/session.dart';
import '../home_modules.dart';

class HomeDrawer extends StatelessWidget {
  const HomeDrawer({super.key});

  void _ouvrir(BuildContext context, String route) {
    final NavigatorState nav = Navigator.of(context);
    nav.pop();
    nav.pushNamed(route);
  }

  void _deconnexion(BuildContext context) {
    final NavigatorState nav = Navigator.of(context);
    Session.fermer();
    nav.pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
  }

  String _initiales(Utilisateur? u) {
    if (u == null) {
      return '?';
    }
    final String p = u.prenom.isNotEmpty ? u.prenom[0] : '';
    final String n = u.nom.isNotEmpty ? u.nom[0] : '';
    return (p + n).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final Utilisateur? u = Session.utilisateur;

    return Drawer(
      backgroundColor: Colors.white,
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(color: AppColors.primary),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              child: Text(
                _initiales(u),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ),
            accountName: Text(
              u?.nomComplet ?? 'Invité',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            accountEmail: Text(u == null ? '' : '${u.role.libelle} · ${u.email}'),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                for (final HomeModule m in homeModules)
                  ListTile(
                    leading: Icon(m.icon, color: AppColors.primary),
                    title: Text(m.label),
                    onTap: () => _ouvrir(context, m.route),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          SafeArea(
            top: false,
            child: ListTile(
              leading: const Icon(Icons.logout, color: AppColors.danger),
              title: const Text(
                'Déconnexion',
                style: TextStyle(
                  color: AppColors.danger,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: () => _deconnexion(context),
            ),
          ),
        ],
      ),
    );
  }
}
