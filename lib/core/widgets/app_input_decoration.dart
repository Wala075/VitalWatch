import 'package:flutter/material.dart';

/// Décoration commune des champs de formulaire (texte, liste, date).
class AppInputDecoration {
  AppInputDecoration._();

  static InputDecoration build(
    BuildContext context, {
    required String label,
    required IconData icon,
    String? hint,
    Widget? suffix,
  }) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final OutlineInputBorder base = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: Colors.grey.shade300),
    );

    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon),
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.grey.shade50,
      border: base,
      enabledBorder: base,
      disabledBorder: base,
      focusedBorder: base.copyWith(
        borderSide: BorderSide(color: cs.primary, width: 2),
      ),
      errorBorder: base.copyWith(
        borderSide: BorderSide(color: cs.error),
      ),
      focusedErrorBorder: base.copyWith(
        borderSide: BorderSide(color: cs.error, width: 2),
      ),
    );
  }
}
