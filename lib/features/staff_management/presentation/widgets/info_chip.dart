import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Petite étiquette icône + texte (ex : « 3 médecins »).
class InfoChip extends StatelessWidget {
  const InfoChip({
    super.key,
    required this.icon,
    required this.texte,
    this.couleur = AppColors.textSecondary,
  });

  final IconData icon;
  final String texte;
  final Color couleur;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: couleur),
        const SizedBox(width: 4),
        Text(
          texte,
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

/// Badge d'état (Disponible, Complet...) : icône + libellé, jamais la couleur seule.
class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.libelle,
    required this.icon,
    required this.couleur,
  });

  final String libelle;
  final IconData icon;
  final Color couleur;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: couleur.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: couleur),
          const SizedBox(width: 4),
          Text(
            libelle,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: couleur,
            ),
          ),
        ],
      ),
    );
  }
}
