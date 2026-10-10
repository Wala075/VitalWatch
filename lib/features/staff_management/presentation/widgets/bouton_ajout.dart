import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Bouton rond « + » placé à droite du titre de page
/// (remplace le FAB, caché par la barre de navigation flottante).
class BoutonAjout extends StatelessWidget {
  const BoutonAjout({super.key, required this.tooltip, required this.onPressed});

  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton.filled(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        fixedSize: const Size(48, 48),
      ),
      icon: const Icon(Icons.add_rounded, size: 26),
    );
  }
}

/// Puce de filtre rapide avec compteur : « Critique · 2 ».
class FiltreRapide extends StatelessWidget {
  const FiltreRapide({
    super.key,
    required this.libelle,
    required this.nombre,
    required this.selectionne,
    required this.onTap,
    this.couleur = AppColors.primary,
  });

  final String libelle;
  final int nombre;
  final bool selectionne;
  final VoidCallback onTap;
  final Color couleur;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selectionne ? couleur : Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            '$libelle · $nombre',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: selectionne ? Colors.white : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
