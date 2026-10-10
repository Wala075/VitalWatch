import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Barre du haut des fiches (médecin, patient) : retour + titre + actions.
class BarreRetour extends StatelessWidget {
  const BarreRetour({super.key, required this.titre, this.actions = const []});

  final String titre;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Retour',
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.maybePop(context),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              titre,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}

/// Carte blanche arrondie utilisée sur les fiches.
class CarteBlanche extends StatelessWidget {
  const CarteBlanche({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: child,
    );
  }
}
