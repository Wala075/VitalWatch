import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/error_banner.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../domain/calcul_boites.dart';
import '../../domain/formats_prescriptions.dart';
import '../../domain/models/ligne_ordonnance.dart';
import '../../domain/models/medicament.dart';
import '../../domain/models/ordonnance.dart';
import '../../domain/models/vues_ordonnance.dart';
import '../../domain/ordonnance_manager.dart';
import '../../domain/planning_prises.dart';
import '../../domain/posologie.dart';
import '../../domain/prescriptions_exception.dart';
import '../../domain/regles_ordonnance.dart';
import '../../domain/saisie.dart';
import '../widgets/dialogues_ordonnance.dart';
import '../widgets/elements_ui.dart';

/// Ajout / modification d'une ligne d'un brouillon : médicament, posologie,
/// durée. Le nombre de boîtes se calcule pendant la saisie.
class LigneFormScreen extends StatefulWidget {
  const LigneFormScreen({super.key, required this.ordonnance, this.ligne});

  final Ordonnance ordonnance;
  final LigneDetail? ligne;

  @override
  State<LigneFormScreen> createState() => _LigneFormScreenState();
}

class _LigneFormScreenState extends State<LigneFormScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _doseCtrl = TextEditingController(text: '1');
  final TextEditingController _dureeCtrl = TextEditingController(text: '7');
  final TextEditingController _instructionsCtrl = TextEditingController();
  final OrdonnanceManager _manager = OrdonnanceManager();

  Medicament? _medicament;
  Set<String> _moments = {'matin'};
  bool _substitution = true;
  bool _apci = false;
  bool _patientApci = false;
  bool _enregistrement = false;
  String? _erreur;

  bool get _edition => widget.ligne != null;

  @override
  void initState() {
    super.initState();
    final LigneDetail? d = widget.ligne;
    if (d != null) {
      final LigneOrdonnance l = d.ligne;
      _medicament = d.medicament;
      _doseCtrl.text = Posologie.nombre(l.dosePrise);
      _dureeCtrl.text = '${l.dureeJours}';
      _instructionsCtrl.text = l.instructions ?? '';
      _moments = Set<String>.of(l.moments);
      _substitution = l.substitutionAutorisee;
      _apci = l.lienApci;
    }
    _doseCtrl.addListener(_rafraichir);
    _dureeCtrl.addListener(_rafraichir);
    _verifierApci();
  }

  Future<void> _verifierApci() async {
    final bool apci = await _manager.estEnApci(
      widget.ordonnance.patientId,
      widget.ordonnance.dateEmission,
    );
    if (mounted) {
      setState(() => _patientApci = apci);
    }
  }

  void _rafraichir() => setState(() {});

  @override
  void dispose() {
    _doseCtrl.dispose();
    _dureeCtrl.dispose();
    _instructionsCtrl.dispose();
    super.dispose();
  }

  Future<void> _choisirMedicament() async {
    final Medicament? m = await choisirMedicament(context);
    if (m != null) {
      setState(() {
        _medicament = m;
        _erreur = null;
      });
    }
  }

  void _basculerMoment(String m) {
    setState(() {
      if (_moments.contains(m)) {
        _moments.remove(m);
      } else {
        _moments.add(m);
      }
    });
  }

  Future<void> _enregistrer() async {
    FocusScope.of(context).unfocus();
    final Medicament? m = _medicament;
    if (m == null) {
      setState(() => _erreur = 'Choisissez un médicament');
      return;
    }
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _enregistrement = true;
      _erreur = null;
    });

    try {
      await _manager.enregistrerLigne(
        ordonnance: widget.ordonnance,
        ligneId: widget.ligne?.ligne.id,
        medicament: m,
        dosePrise: Saisie.decimal(_doseCtrl.text) ?? 0,
        moments: _moments.toList(),
        dureeJours: int.parse(_dureeCtrl.text.trim()),
        substitutionAutorisee: _substitution,
        lienApci: _apci,
        instructions: _instructionsCtrl.text,
      );
      if (!mounted) {
        return;
      }
      Navigator.pop(context, true);
    } on PrescriptionsException catch (e) {
      if (mounted) {
        setState(() => _erreur = e.message);
      }
    } finally {
      if (mounted) {
        setState(() => _enregistrement = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final Medicament? m = _medicament;
    final double dose = Saisie.decimal(_doseCtrl.text) ?? 0;
    final String unite = m == null ? 'unité' : Posologie.unite(m.forme, dose);

    return Scaffold(
      appBar: AppBar(title: Text(_edition ? 'Modifier la ligne' : 'Ajouter un médicament')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SectionFormulaire(
              titre: 'Médicament',
              icon: Icons.medication_outlined,
              children: [
                _CarteChoix(medicament: m, onTap: _enregistrement ? null : _choisirMedicament),
              ],
            ),
            const SizedBox(height: 12),
            SectionFormulaire(
              titre: 'Posologie',
              icon: Icons.schedule_rounded,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: AppTextField(
                        controller: _doseCtrl,
                        label: 'Dose par prise',
                        hint: unite,
                        icon: Icons.medication_liquid_outlined,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (String? v) => Saisie.positif(v, champ: 'La dose'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppTextField(
                        controller: _dureeCtrl,
                        label: 'Durée (jours)',
                        icon: Icons.date_range_outlined,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        validator: (String? v) =>
                            Saisie.entier(v, champ: 'La durée', min: 1, max: 365),
                      ),
                    ),
                  ],
                ),
                const Text(
                  'Moments de prise',
                  style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final String moment in PlanningPrises.moments)
                      FilterChip(
                        label: Text(
                          '${PlanningPrises.libelles[moment]} · ${PlanningPrises.heures[moment]} h',
                        ),
                        selected: _moments.contains(moment),
                        onSelected: (_) => _basculerMoment(moment),
                      ),
                  ],
                ),
                _Apercu(
                  medicament: m,
                  dose: dose,
                  moments: _moments.length,
                  duree: int.tryParse(_dureeCtrl.text.trim()) ?? 0,
                ),
              ],
            ),
            const SizedBox(height: 12),
            SectionFormulaire(
              titre: 'Options',
              icon: Icons.tune_rounded,
              children: [
                AppTextField(
                  controller: _instructionsCtrl,
                  label: 'Instructions (facultatif)',
                  hint: 'ex. pendant les repas',
                  icon: Icons.notes_rounded,
                  maxLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Substitution par un générique autorisée'),
                  value: _substitution,
                  onChanged: (bool v) => setState(() => _substitution = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Liée à la maladie APCI (100 %)'),
                  subtitle: Text(
                    _patientApci
                        ? 'Le patient a un contrat APCI actif'
                        : "Ce patient n'est pas en APCI",
                  ),
                  value: _apci,
                  onChanged: _patientApci || _apci ? (bool v) => setState(() => _apci = v) : null,
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_erreur != null) ...[
              ErrorBanner(message: _erreur!),
              const SizedBox(height: 16),
            ],
            PrimaryButton(
              label: _edition ? 'Enregistrer la ligne' : "Ajouter à l'ordonnance",
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

/// Médicament choisi (ou invitation à choisir).
class _CarteChoix extends StatelessWidget {
  const _CarteChoix({required this.medicament, this.onTap});

  final Medicament? medicament;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Medicament? m = medicament;

    return Material(
      color: AppColors.mint,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(
                m == null ? Icons.search_rounded : StyleCategorie.iconeForme(m.forme),
                color: AppColors.primaryDark,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: m == null
                    ? const Text(
                        'Choisir dans le catalogue',
                        style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.primaryDark),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            m.libelle,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            '${m.description} · ${FormatsPrescriptions.dt(m.prixPublic)}',
                            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
              ),
              const Icon(Icons.swap_horiz_rounded, color: AppColors.primaryDark),
            ],
          ),
        ),
      ),
    );
  }
}

/// Calcul en direct : unités nécessaires, boîtes, dose journalière.
class _Apercu extends StatelessWidget {
  const _Apercu({
    required this.medicament,
    required this.dose,
    required this.moments,
    required this.duree,
  });

  final Medicament? medicament;
  final double dose;
  final int moments;
  final int duree;

  @override
  Widget build(BuildContext context) {
    final Medicament? m = medicament;
    if (m == null || dose <= 0 || moments == 0 || duree < 1) {
      return const Text(
        'Choisissez le médicament, la dose, les moments et la durée '
        'pour calculer le nombre de boîtes.',
        style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
      );
    }

    final int boites = CalculBoites.calculer(
      dosePrise: dose,
      prisesParJour: moments,
      dureeJours: duree,
      unitesParBoite: m.unitesParBoite,
    );
    final double total = dose * moments * duree;
    final double doseJour = dose * moments;
    final String? alerte = ReglesOrdonnance.ligne(
      medicament: m,
      dosePrise: dose,
      moments: List<String>.filled(moments, 'matin'),
      dureeJours: duree,
    );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: (alerte == null ? AppColors.primary : AppColors.danger).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.inventory_2_outlined, color: AppColors.primaryDark),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${Posologie.boites(boites)} à délivrer',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${Posologie.nombre(total)} ${Posologie.unite(m.forme, total)} au total '
            '(${Posologie.nombre(dose)} × $moments par jour × $duree j) · '
            '${m.unitesParBoite} par boîte',
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            alerte ??
                'Dose journalière : ${Posologie.nombre(doseJour)} ${Posologie.unite(m.forme, doseJour)}'
                    '${m.doseMaxJour == null ? '' : ' (max ${Posologie.nombre(m.doseMaxJour!)})'}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: alerte == null ? FontWeight.w400 : FontWeight.w700,
              color: alerte == null ? AppColors.textSecondary : AppColors.danger,
            ),
          ),
        ],
      ),
    );
  }
}
