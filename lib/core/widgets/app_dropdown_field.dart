import 'package:flutter/material.dart';

import 'app_input_decoration.dart';

/// Liste déroulante au style des champs de l'application.
class AppDropdownField<T> extends StatelessWidget {
  const AppDropdownField({
    super.key,
    required this.label,
    required this.icon,
    required this.items,
    required this.value,
    required this.onChanged,
    this.validator,
    this.enabled = true,
  });

  final String label;
  final IconData icon;
  final List<DropdownMenuItem<T>> items;
  final T? value;
  final ValueChanged<T?> onChanged;
  final FormFieldValidator<T>? validator;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    // La valeur doit exister dans la liste, sinon Flutter lève une erreur.
    T? valeur;
    for (final DropdownMenuItem<T> item in items) {
      if (item.value == value) {
        valeur = value;
        break;
      }
    }

    return DropdownButtonFormField<T>(
      // Recrée le champ quand la valeur ou la liste change (initialValue).
      key: ValueKey<String>('${valeur}_${items.length}'),
      initialValue: valeur,
      items: items,
      onChanged: enabled ? onChanged : null,
      validator: validator,
      isExpanded: true,
      borderRadius: BorderRadius.circular(14),
      decoration: AppInputDecoration.build(context, label: label, icon: icon),
    );
  }
}
