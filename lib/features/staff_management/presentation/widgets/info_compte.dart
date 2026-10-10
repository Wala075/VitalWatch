import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Encadré d'information des formulaires du personnel
/// (création du compte, affectation gérée ailleurs...).
class EncadreInfo extends StatelessWidget {
  const EncadreInfo({
    super.key,
    required this.texte,
    this.icon = Icons.info_outline,
    this.couleur = AppColors.primary,
  });

  final String texte;
  final IconData icon;
  final Color couleur;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: couleur.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: couleur, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              texte,
              style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
