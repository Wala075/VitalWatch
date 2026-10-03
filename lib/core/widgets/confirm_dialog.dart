import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Boîte de confirmation. Renvoie true si l'utilisateur confirme.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String titre,
  required String message,
  String confirmer = 'Confirmer',
  bool danger = false,
}) async {
  final bool? reponse = await showDialog<bool>(
    context: context,
    builder: (BuildContext ctx) {
      return AlertDialog(
        title: Text(titre),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: danger
                ? FilledButton.styleFrom(backgroundColor: AppColors.danger)
                : null,
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmer),
          ),
        ],
      );
    },
  );
  return reponse ?? false;
}
