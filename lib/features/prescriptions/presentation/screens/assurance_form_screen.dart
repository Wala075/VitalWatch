import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_dropdown_field.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../core/widgets/error_banner.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../data/taux_couverture_repository.dart';
import '../../domain/formats_prescriptions.dart';
import '../../domain/models/assurance.dart';
import '../../domain/models/medicament.dart';
import '../../domain/models/taux_couverture.dart';
import '../../domain/prescriptions_exception.dart';
import '../../domain/referentiels_manager.dart';
import '../../domain/saisie.dart';
import '../widgets/elements_ui.dart';

/// Ajout / modification d'une assurance et de ses taux (admin).
class AssuranceFormScreen extends StatefulWidget {
  const AssuranceFormScreen({super.key, this.assurance});

  final Assurance? assurance;

  @override
  State<AssuranceFormScreen> createState() => _AssuranceFormScreenState();
}

class _AssuranceFormScreenState extends State<AssuranceFormScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nomCtrl = TextEditingController();
  final TextEditingController _plafondCtrl = TextEditingController();
  final TextEditingController _delaiCtrl = TextEditingController(text: '30');
  final ReferentielsManager _manager = ReferentielsManager();
  final TauxCouvertureRepository _tauxRepo = TauxCouvertureRepository();

  /// Un champ « % » par catégorie de médicament, plus « tous ».
  final Map<String, TextEditingController> _tauxCtrl = {};

  TypeAssurance _type = TypeAssurance.mutuelle;
  bool _enregistrement = false;
  String? _erreur;

  bool get _edition => widget.assurance != null;

  /// Clés des champs de taux, dans l'ordre d'affichage.
  static List<String> get _categories {
    final List<String> res = [];
    for (final CategorieMedicament c in CategorieMedicament.values) {
      res.add(c.valeur);
    }
    res.add(TauxCouverture.tous);
    return res;
  }

  @override
  void initState() {
    super.initState();
    for (final String c in _categories) {
      _tauxCtrl[c] = TextEditingController();
    }
    final Assurance? a = widget.assurance;
    if (a != null) {
      _nomCtrl.text = a.nom;
      final double? plafond = a.plafondAnnuel;
      _plafondCtrl.text = plafond == null ? '' : FormatsPrescriptions.decimal(plafond);
      _delaiCtrl.text = '${a.delaiReponseJours}';
      _type = a.type;
      _chargerTaux(a.id!);
    }
  }

  Future<void> _chargerTaux(int assuranceId) async {
    final List<TauxCouverture> taux = await _tauxRepo.parAssurance(assuranceId);
    if (!mounted) {
      return;
    }
    setState(() {
      for (final TauxCouverture t in taux) {
        _tauxCtrl[t.categorie]?.text = FormatsPrescriptions.pourcent(t.taux);
      }
    });
  }

  @override
  void dispose() {
    _nomCtrl.dispose();
    _plafondCtrl.dispose();
    _delaiCtrl.dispose();
    for (final TextEditingController c in _tauxCtrl.values) {
      c.dispose();
    }
    super.dispose();
  }

  String _libelle(String categorie) {
    if (categorie == TauxCouverture.tous) {
      return 'Tous les médicaments';
    }
    return CategorieMedicament.depuis(categorie).libelle;
  }

  List<TauxCouverture> _tauxSaisis() {
    final List<TauxCouverture> res = [];
    for (final String c in _categories) {
      // La CNAM n'a pas de taux « tous ».
      if (_type == TypeAssurance.cnam && c == TauxCouverture.tous) {
        continue;
      }
      final double? pourcent = Saisie.decimal(_tauxCtrl[c]?.text);
      if (pourcent != null) {
        res.add(TauxCouverture(
          assuranceId: widget.assurance?.id ?? 0,
          categorie: c,
          taux: pourcent / 100,
        ));
      }
    }
    return res;
  }

  Future<void> _enregistrer() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _enregistrement = true;
      _erreur = null;
    });

    try {
      final Assurance a = Assurance(
        id: widget.assurance?.id,
        nom: _nomCtrl.text.trim(),
        type: _type,
        plafondAnnuel: Saisie.decimal(_plafondCtrl.text),
        delaiReponseJours: int.parse(_delaiCtrl.text.trim()),
      );
      await _manager.enregistrerAssurance(a, _tauxSaisis());
      if (!mounted) {
        return;
      }
      Navigator.pop(context, true);
    } on PrescriptionsException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => _erreur = e.message);
    } finally {
      if (mounted) {
        setState(() => _enregistrement = false);
      }
    }
  }

  Future<void> _supprimer() async {
    final Assurance? a = widget.assurance;
    final int? id = a?.id;
    if (a == null || id == null) {
      return;
    }
    final bool ok = await showConfirmDialog(
      context,
      titre: 'Supprimer « ${a.nom} » ?',
      message: 'Ses taux de prise en charge seront supprimés aussi.',
      confirmer: 'Supprimer',
      danger: true,
    );
    if (!ok) {
      return;
    }
    try {
      await _manager.supprimerAssurance(id);
      if (!mounted) {
        return;
      }
      Navigator.pop(context, true);
    } on PrescriptionsException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => _erreur = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<String> categories = [];
    for (final String c in _categories) {
      if (_type != TypeAssurance.cnam || c != TauxCouverture.tous) {
        categories.add(c);
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_edition ? "Modifier l'assurance" : 'Nouvelle assurance'),
        actions: [
          if (_edition)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppColors.danger),
              tooltip: 'Supprimer',
              onPressed: _enregistrement ? null : _supprimer,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SectionFormulaire(
              titre: 'Organisme',
              icon: Icons.shield_outlined,
              children: [
                AppTextField(
                  controller: _nomCtrl,
                  label: 'Nom',
                  icon: Icons.label_outline,
                  textCapitalization: TextCapitalization.words,
                  validator: (String? v) => Saisie.requis(v, champ: 'Le nom'),
                ),
                AppDropdownField<TypeAssurance>(
                  label: 'Type',
                  icon: Icons.category_outlined,
                  value: _type,
                  items: [
                    for (final TypeAssurance t in TypeAssurance.values)
                      DropdownMenuItem<TypeAssurance>(value: t, child: Text(t.libelle)),
                  ],
                  onChanged: (TypeAssurance? v) {
                    if (v != null) {
                      setState(() => _type = v);
                    }
                  },
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: AppTextField(
                        controller: _plafondCtrl,
                        label: 'Plafond annuel (DT)',
                        hint: 'vide = aucun',
                        icon: Icons.savings_outlined,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (String? v) =>
                            Saisie.montant(v, champ: 'Le plafond', obligatoire: false),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppTextField(
                        controller: _delaiCtrl,
                        label: 'Délai de réponse (j)',
                        icon: Icons.schedule_rounded,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        validator: (String? v) => Saisie.entier(v, champ: 'Le délai', min: 1),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            SectionFormulaire(
              titre: 'Taux de prise en charge',
              icon: Icons.percent_rounded,
              aide: _type == TypeAssurance.cnam
                  ? 'Un taux par catégorie de médicament. Laissez vide : non remboursé.'
                  : 'Une mutuelle rembourse un pourcentage du reste après la CNAM : '
                      'utilisez « Tous les médicaments », ou un taux par catégorie.',
              children: [
                for (final String c in categories)
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _libelle(c),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 120,
                        child: AppTextField(
                          controller: _tauxCtrl[c]!,
                          label: '%',
                          icon: Icons.percent_rounded,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          validator: Saisie.pourcentage,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (_erreur != null) ...[
              ErrorBanner(message: _erreur!),
              const SizedBox(height: 16),
            ],
            PrimaryButton(
              label: _edition ? 'Enregistrer' : "Ajouter l'assurance",
              icon: Icons.check,
              loading: _enregistrement,
              onPressed: _enregistrer,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
