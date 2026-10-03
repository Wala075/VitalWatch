import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Bloc de formulaire avec titre et icône.
class FormSection extends StatelessWidget {
  const FormSection({
    super.key,
    required this.titre,
    required this.icon,
    required this.children,
  });

  final String titre;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final List<Widget> contenu = [];
    for (int i = 0; i < children.length; i++) {
      if (i > 0) {
        contenu.add(const SizedBox(height: 14));
      }
      contenu.add(children[i]);
    }

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  titre,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...contenu,
          ],
        ),
      ),
    );
  }
}
