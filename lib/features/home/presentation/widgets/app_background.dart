import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Fond dégradé menthe → crème de l'espace santé.
class AppBackground extends StatelessWidget {
  const AppBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.mint, AppColors.background, AppColors.cream],
        ),
      ),
      child: child,
    );
  }
}
