import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Titre de page sur deux lignes : « Trouvez votre » / « Médecin ».
class PageTitle extends StatelessWidget {
  const PageTitle({
    super.key,
    required this.surtitre,
    required this.titre,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(20, 12, 20, 14),
  });

  final String surtitre;
  final String titre;
  final Widget? trailing;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final Widget? fin = trailing;

    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  surtitre,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  titre,
                  style: const TextStyle(
                    fontSize: 30,
                    height: 1.15,
                    letterSpacing: -0.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          if (fin != null) fin,
        ],
      ),
    );
  }
}

/// En-tête de section : titre + action « Voir tout ».
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.titre,
    this.action,
    this.onAction,
  });

  final String titre;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final String? libelle = action;

    return Row(
      children: [
        Expanded(
          child: Text(
            titre,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        if (libelle != null)
          GestureDetector(
            onTap: onAction,
            child: Text(
              libelle,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
      ],
    );
  }
}
