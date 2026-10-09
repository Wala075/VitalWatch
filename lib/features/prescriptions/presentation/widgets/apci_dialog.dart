import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/error_banner.dart';
import '../../domain/models/apci.dart';
import '../../domain/prescriptions_exception.dart';
import '../../domain/referentiels_manager.dart';
import '../../domain/saisie.dart';

/// Ajout (apci == null) ou modification d'une maladie APCI.
/// Renvoie true si la liste a changé.
Future<bool> afficherApciDialog(BuildContext context, {Apci? apci}) async {
  final bool? res = await showDialog<bool>(
    context: context,
    builder: (_) => _ApciDialog(apci: apci),
  );
  return res ?? false;
}

class _ApciDialog extends StatefulWidget {
  const _ApciDialog({this.apci});

  final Apci? apci;

  @override
  State<_ApciDialog> createState() => _ApciDialogState();
}

class _ApciDialogState extends State<_ApciDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _codeCtrl = TextEditingController();
  final TextEditingController _libelleCtrl = TextEditingController();
  final ReferentielsManager _manager = ReferentielsManager();

  bool _occupe = false;
  bool _confirmerSuppression = false;
  String? _erreur;

  bool get _edition => widget.apci != null;

  @override
  void initState() {
    super.initState();
    final Apci? a = widget.apci;
    if (a != null) {
      _codeCtrl.text = a.codeCim10;
      _libelleCtrl.text = a.libelle;
    }
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _libelleCtrl.dispose();
    super.dispose();
  }

  Future<void> _executer(Future<void> Function() action) async {
    setState(() {
      _occupe = true;
      _erreur = null;
    });
    try {
      await action();
      if (!mounted) {
        return;
      }
      Navigator.pop(context, true);
    } on PrescriptionsException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _erreur = e.message;
        _occupe = false;
        _confirmerSuppression = false;
      });
    }
  }

  void _enregistrer() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final Apci? a = widget.apci;
    _executer(() {
      if (a == null) {
        return _manager.ajouterApci(_codeCtrl.text, _libelleCtrl.text);
      }
      return _manager.modifierLibelleApci(a.codeCim10, _libelleCtrl.text);
    });
  }

  void _supprimer() {
    final Apci? a = widget.apci;
    if (a == null) {
      return;
    }
    // Deuxième appui pour confirmer.
    if (!_confirmerSuppression) {
      setState(() => _confirmerSuppression = true);
      return;
    }
    _executer(() => _manager.supprimerApci(a.codeCim10));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_edition ? 'Maladie APCI' : 'Nouvelle maladie APCI'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppTextField(
                controller: _codeCtrl,
                label: 'Code CIM-10',
                hint: 'ex. E11',
                icon: Icons.tag_rounded,
                enabled: !_edition,
                textCapitalization: TextCapitalization.characters,
                validator: Saisie.codeCim10,
              ),
              const SizedBox(height: 14),
              AppTextField(
                controller: _libelleCtrl,
                label: 'Maladie',
                hint: 'ex. Diabète de type 2',
                icon: Icons.favorite_border_rounded,
                textCapitalization: TextCapitalization.sentences,
                validator: (String? v) => Saisie.requis(v, champ: 'Le libellé'),
              ),
              if (_erreur != null) ...[
                const SizedBox(height: 14),
                ErrorBanner(message: _erreur!),
              ],
            ],
          ),
        ),
      ),
      actions: [
        if (_edition)
          TextButton(
            onPressed: _occupe ? null : _supprimer,
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: Text(_confirmerSuppression ? 'Confirmer ?' : 'Supprimer'),
          ),
        TextButton(
          onPressed: _occupe ? null : () => Navigator.pop(context, false),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: _occupe ? null : _enregistrer,
          child: Text(_edition ? 'Enregistrer' : 'Ajouter'),
        ),
      ],
    );
  }
}
