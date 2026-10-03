import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Barre de recherche arrondie + bouton filtres (optionnel) avec compteur.
class SearchField extends StatelessWidget {
  const SearchField({
    super.key,
    required this.hint,
    required this.onChanged,
    this.onFilterTap,
    this.nbFiltres = 0,
  });

  final String hint;
  final ValueChanged<String> onChanged;
  final VoidCallback? onFilterTap;
  final int nbFiltres;

  @override
  Widget build(BuildContext context) {
    final VoidCallback? filtrer = onFilterTap;

    return Row(
      children: [
        Expanded(
          child: TextField(
            onChanged: onChanged,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: hint,
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.white,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: const BorderSide(color: AppColors.divider),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: const BorderSide(color: AppColors.divider),
              ),
            ),
          ),
        ),
        if (filtrer != null) ...[
          const SizedBox(width: 8),
          Badge(
            isLabelVisible: nbFiltres > 0,
            label: Text('$nbFiltres'),
            child: IconButton.filledTonal(
              icon: const Icon(Icons.tune),
              tooltip: 'Filtres',
              onPressed: filtrer,
            ),
          ),
        ],
      ],
    );
  }
}
