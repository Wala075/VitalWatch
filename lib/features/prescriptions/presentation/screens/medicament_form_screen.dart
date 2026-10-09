import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_dropdown_field.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../core/widgets/error_banner.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../data/medicament_repository.dart';
import '../../domain/formats_prescriptions.dart';
import '../../domain/models/medicament.dart';
import '../../domain/prescriptions_exception.dart';
import '../../domain/referentiels_manager.dart';
import '../../domain/saisie.dart';
import '../widgets/elements_ui.dart';

/// Ajout / modification d'un médicament du catalogue (admin).
class MedicamentFormScreen extends StatefulWidget {
  const MedicamentFormScreen({super.key, this.medicament});

  final Medicament? medicament;

  @override
  State<MedicamentFormScreen> createState() => _MedicamentFormScreenState();
}

class _MedicamentFormScreenState extends State<MedicamentFormScreen> {
  static const List<String> _formes = [
    'comprimé',
    'gélule',
    'sachet',
    'sirop',
    'solution buvable',
    'aérosol doseur',
    'stylo injectable',
    'solution injectable',
    'pommade',
    'collyre',
    'suppositoire',
  ];

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nomCtrl = TextEditingController();
  final TextEditingController _dciCtrl = TextEditingController();
  final TextEditingController _classeCtrl = TextEditingController();
  final TextEditingController _dosageCtrl = TextEditingController();
  final TextEditingController _unitesCtrl = TextEditingController();
  final TextEditingController _doseMaxCtrl = TextEditingController();
  final TextEditingController _codeCtrl = TextEditingController();
  final TextEditingController _prixCtrl = TextEditingController();
  final TextEditingController _referenceCtrl = TextEditingController();
  final ReferentielsManager _manager = ReferentielsManager();
  final MedicamentRepository _repo = MedicamentRepository();

  String _forme = 'comprimé';
  CategorieMedicament _categorie = CategorieMedicament.essentiel;
  bool _generique = false;
  bool _enregistrement = false;
  String? _erreur;

  bool get _edition => widget.medicament != null;

  @override
  void initState() {
    super.initState();
    final Medicament? m = widget.medicament;
    if (m != null) {
      _nomCtrl.text = m.nomCommercial;
      _dciCtrl.text = m.dci;
      _classeCtrl.text = m.classe ?? '';
      _dosageCtrl.text = m.dosage;
      _unitesCtrl.text = '${m.unitesParBoite}';
      final double? doseMax = m.doseMaxJour;
      _doseMaxCtrl.text = doseMax == null ? '' : _nombre(doseMax);
      _codeCtrl.text = m.codeBarres ?? '';
      _prixCtrl.text = FormatsPrescriptions.decimal(m.prixPublic);
      final double? reference = m.prixReference;
      _referenceCtrl.text = reference == null ? '' : FormatsPrescriptions.decimal(reference);
      _forme = m.forme;
      _categorie = m.categorie;
      _generique = m.generique;
    }
  }

  @override
  void dispose() {
    _nomCtrl.dispose();
    _dciCtrl.dispose();
    _classeCtrl.dispose();
    _dosageCtrl.dispose();
    _unitesCtrl.dispose();
    _doseMaxCtrl.dispose();
    _codeCtrl.dispose();
    _prixCtrl.dispose();
    _referenceCtrl.dispose();
    super.dispose();
  }

  /// 4.0 → « 4 », 2.5 → « 2,5 ».
  static String _nombre(double v) {
    if (v == v.roundToDouble()) {
      return v.round().toString();
    }
    return v.toString().replaceAll('.', ',');
  }

  static String? _vide(String texte) {
    final String t = texte.trim();
    return t.isEmpty ? null : t;
  }

  String? _validerReference(String? v) {
    final String? erreur = Saisie.montant(v, champ: 'Le prix de référence', obligatoire: false);
    if (erreur != null) {
      return erreur;
    }
    final double? reference = Saisie.decimal(v);
    final double? prix = Saisie.decimal(_prixCtrl.text);
    if (reference != null && prix != null && reference > prix) {
      return 'Le prix de référence ne peut pas dépasser le prix public';
    }
    return null;
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
      final Medicament? initial = widget.medicament;
      final Medicament m = Medicament(
        id: initial?.id,
        nomCommercial: _nomCtrl.text.trim(),
        dci: _dciCtrl.text.trim(),
        rxcui: initial?.rxcui,
        classe: _vide(_classeCtrl.text),
        forme: _forme,
        dosage: _dosageCtrl.text.trim(),
        unitesParBoite: int.parse(_unitesCtrl.text.trim()),
        doseMaxJour: Saisie.decimal(_doseMaxCtrl.text),
        codeBarres: _vide(_codeCtrl.text),
        prixPublic: Saisie.decimal(_prixCtrl.text) ?? 0,
        prixReference: Saisie.decimal(_referenceCtrl.text),
        categorie: _categorie,
        generique: _generique,
        actif: initial?.actif ?? true,
      );
      await _manager.enregistrerMedicament(m);
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
    final Medicament? m = widget.medicament;
    final int? id = m?.id;
    if (m == null || id == null) {
      return;
    }
    final bool prescrit = await _repo.estDejaPrescrit(id);
    if (!mounted) {
      return;
    }
    final bool ok = await showConfirmDialog(
      context,
      titre: prescrit ? 'Archiver « ${m.libelle} » ?' : 'Supprimer « ${m.libelle} » ?',
      message: prescrit
          ? 'Ce médicament figure déjà sur des ordonnances : il est archivé au lieu '
              "d'être supprimé. Il ne sera plus proposé pour les nouvelles ordonnances."
          : 'Ce médicament sera définitivement retiré du catalogue.',
      confirmer: prescrit ? 'Archiver' : 'Supprimer',
      danger: true,
    );
    if (!ok) {
      return;
    }
    final bool archive = await _manager.supprimerMedicament(id);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(archive ? 'Médicament archivé' : 'Médicament supprimé')),
    );
    Navigator.pop(context, true);
  }

  Future<void> _reactiver() async {
    final Medicament? m = widget.medicament;
    if (m == null) {
      return;
    }
    await _manager.reactiverMedicament(m);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Médicament remis dans le catalogue')),
    );
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final bool archive = widget.medicament?.actif == false;
    final List<String> formes = List<String>.of(_formes);
    if (!formes.contains(_forme)) {
      formes.add(_forme);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_edition ? 'Modifier le médicament' : 'Nouveau médicament'),
        actions: [
          if (archive)
            IconButton(
              icon: const Icon(Icons.unarchive_outlined, color: AppColors.success),
              tooltip: 'Remettre dans le catalogue',
              onPressed: _enregistrement ? null : _reactiver,
            )
          else if (_edition)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppColors.danger),
              tooltip: 'Supprimer ou archiver',
              onPressed: _enregistrement ? null : _supprimer,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (archive) ...[
              const ErrorBanner(
                message: 'Médicament archivé : il ne peut plus être prescrit.',
              ),
              const SizedBox(height: 12),
            ],
            SectionFormulaire(
              titre: 'Identification',
              icon: Icons.medication_outlined,
              children: [
                AppTextField(
                  controller: _nomCtrl,
                  label: 'Nom commercial',
                  icon: Icons.label_outline,
                  textCapitalization: TextCapitalization.words,
                  validator: (String? v) => Saisie.requis(v, champ: 'Le nom commercial'),
                ),
                AppTextField(
                  controller: _dciCtrl,
                  label: 'DCI (principe actif)',
                  hint: 'ex. paracétamol',
                  icon: Icons.science_outlined,
                  validator: (String? v) => Saisie.requis(v, champ: 'La DCI'),
                ),
                AppTextField(
                  controller: _classeCtrl,
                  label: 'Classe thérapeutique (facultatif)',
                  hint: 'ex. pénicilline',
                  icon: Icons.category_outlined,
                ),
                AppTextField(
                  controller: _codeCtrl,
                  label: 'Code-barres (facultatif)',
                  icon: Icons.qr_code_2_rounded,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
              ],
            ),
            const SizedBox(height: 12),
            SectionFormulaire(
              titre: 'Présentation',
              icon: Icons.inventory_2_outlined,
              children: [
                AppDropdownField<String>(
                  label: 'Forme',
                  icon: StyleCategorie.iconeForme(_forme),
                  value: _forme,
                  items: [
                    for (final String f in formes)
                      DropdownMenuItem<String>(value: f, child: Text(f)),
                  ],
                  onChanged: (String? v) {
                    if (v != null) {
                      setState(() => _forme = v);
                    }
                  },
                ),
                AppTextField(
                  controller: _dosageCtrl,
                  label: 'Dosage',
                  hint: 'ex. 500 mg',
                  icon: Icons.straighten_rounded,
                  validator: (String? v) => Saisie.requis(v, champ: 'Le dosage'),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: AppTextField(
                        controller: _unitesCtrl,
                        label: 'Unités / boîte',
                        icon: Icons.grid_view_rounded,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        validator: (String? v) =>
                            Saisie.entier(v, champ: 'Le nombre', min: 1),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppTextField(
                        controller: _doseMaxCtrl,
                        label: 'Dose max / jour',
                        hint: 'en unités',
                        icon: Icons.warning_amber_rounded,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (String? v) =>
                            Saisie.positif(v, champ: 'La dose', obligatoire: false),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            SectionFormulaire(
              titre: 'Prix et remboursement',
              icon: Icons.payments_outlined,
              aide: 'Le remboursement se calcule sur le plus petit des deux prix. '
                  'Prix de référence : prix du générique le moins cher.',
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: AppTextField(
                        controller: _prixCtrl,
                        label: 'Prix public (DT)',
                        hint: '12,500',
                        icon: Icons.sell_outlined,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (String? v) => Saisie.montant(v, champ: 'Le prix public'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppTextField(
                        controller: _referenceCtrl,
                        label: 'Prix de référence',
                        hint: 'facultatif',
                        icon: Icons.price_check_rounded,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: _validerReference,
                      ),
                    ),
                  ],
                ),
                AppDropdownField<CategorieMedicament>(
                  label: 'Catégorie de remboursement',
                  icon: StyleCategorie.icone(_categorie),
                  value: _categorie,
                  items: [
                    for (final CategorieMedicament c in CategorieMedicament.values)
                      DropdownMenuItem<CategorieMedicament>(value: c, child: Text(c.libelle)),
                  ],
                  onChanged: (CategorieMedicament? v) {
                    if (v != null) {
                      setState(() => _categorie = v);
                    }
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Médicament générique'),
                  subtitle: const Text('Proposé en substitution des princeps de même DCI'),
                  value: _generique,
                  onChanged: (bool v) => setState(() => _generique = v),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_erreur != null) ...[
              ErrorBanner(message: _erreur!),
              const SizedBox(height: 16),
            ],
            PrimaryButton(
              label: _edition ? 'Enregistrer' : 'Ajouter au catalogue',
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
