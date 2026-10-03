import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../home_modules.dart';
import '../../widgets/page_title.dart';

/// Onglet réservé au personnel : accès aux 5 modules de gestion.
class GestionTab extends StatelessWidget {
  const GestionTab({super.key});

  static const List<Color> _couleurs = [
    AppColors.primary,
    AppColors.danger,
    AppColors.warning,
    AppColors.purple,
    Color(0xFF2B8FB3),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
        children: [
          const PageTitle(
            surtitre: 'Espace',
            titre: 'Gestion',
            padding: EdgeInsets.fromLTRB(0, 12, 0, 4),
          ),
          const Text(
            "Les modules de l'établissement",
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            children: [
              for (int i = 0; i < homeModules.length; i++)
                _TuileModule(
                  module: homeModules[i],
                  couleur: _couleurs[i % _couleurs.length],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TuileModule extends StatelessWidget {
  const _TuileModule({required this.module, required this.couleur});

  final HomeModule module;
  final Color couleur;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => Navigator.pushNamed(context, module.route),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: couleur.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(module.icon, color: couleur),
              ),
              const Spacer(),
              Text(
                module.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text(
                    'Ouvrir',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: couleur,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_forward_rounded, size: 14, color: couleur),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
