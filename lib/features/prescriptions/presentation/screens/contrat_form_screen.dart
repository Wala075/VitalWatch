import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_dropdown_field.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/error_banner.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../data/apci_repository.dart';
import '../../data/assurance_repository.dart';
import '../../domain/contrat_manager.dart';
import '../../domain/models/apci.dart';
import '../../domain/models/assurance.dart';
import '../../domain/models/contrat_assurance.dart';
import '../../domain/prescriptions_exception.dart';
import '../widgets/elements_ui.dart';

/// Ajout / modification / résiliation d'un contrat d'assurance (admin).
class ContratFormScreen extends StatefulWidget {
  const ContratFormScreen({super.key, required this.patientId, this.contrat});

  final int patientId;
  final ContratAssurance? contrat;

  @override
  State<ContratFormScreen> createState() => _ContratFormScreenState();
}

class _ContratFormScreenState extends State<ContratFormScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _numeroCtrl = TextEditingController();
  final ContratManager _manager = ContratManager();

  List<Assurance> _assurances = [];
  List<Apci> _codes = [];
  int? _assuranceId;
  FiliereCnam? _filiere;
  Beneficiaire _beneficiaire = Beneficiaire.assure;
  DateTime _debut = DateTime.now();
  DateTime? _fin;
  bool _apci = false;
  String? _codeApci;
  bool _enregistrement = false;
  String? _erreur;

  bool get _edition => widget.contrat != null;

  Assurance? get _assurance {
    for (final Assurance a in _assurances) {
      if (a.id == _assuranceId) {
        return a;
      }
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    final ContratAssurance? c = widget.contrat;
    if (c != null) {
      _numeroCtrl.text = c.numeroAdherent;
      _assuranceId = c.assuranceId;
      _filiere = c.filiere;
      _beneficiaire = c.beneficiaire;
      _debut = c.dateDebut;
      _fin = c.dateFin;
      _apci = c.apci;
      _codeApci = c.codeApci;
    }
    _charger();
  }

  Future<void> _charger() async {
    final List<Assurance> assurances = await AssuranceRepository().lister();
    final List<Apci> codes = await ApciRepository().lister();
    if (!mounted) {
      return;
    }
    setState(() {
      _assurances = assurances;
      _codes = codes;
      _assuranceId ??= assurances.isEmpty ? null : assurances.first.id;
    });
  }

  @override
  void dispose() {
    _numeroCtrl.dispose();
    super.dispose();
  }

  Future<void> _choisirDate({required bool debut}) async {
    final DateTime? d = await showDatePicker(
      context: context,
      initialDate: debut ? _debut : (_fin ?? DateTime.now()),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (d != null) {
      setState(() {
        if (debut) {
          _debut = d;
        } else {
          _fin = d;
        }
      });
    }
  }

  Future<void> _enregistrer() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final int? assuranceId = _assuranceId;
    if (assuranceId == null) {
      setState(() => _erreur = 'Choisissez une assurance');
      return;
    }
    final bool cnam = _assurance?.estObligatoire ?? false;
    setState(() {
      _enregistrement = true;
      _erreur = null;
    });
    try {
      await _manager.enregistrer(ContratAssurance(
        id: widget.contrat?.id,
        patientId: widget.patientId,
        assuranceId: assuranceId,
        numeroAdherent: _numeroCtrl.text.trim(),
        filiere: cnam ? _filiere : null,
        beneficiaire: _beneficiaire,
        dateDebut: _debut,
        dateFin: _fin,
        apci: cnam && _apci,
        codeApci: cnam && _apci ? _codeApci : null,
      ));
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

  Future<void> _resilier() async {
    final ContratAssurance? c = widget.contrat;
    if (c == null) {
      return;
    }
    final DateTime? fin = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: c.dateDebut.add(const Duration(days: 1)),
      lastDate: DateTime(2100),
      helpText: 'Date de résiliation',
    );
    if (fin == null) {
      return;
    }
    try {
      await _manager.resilier(c, fin);
      if (mounted) {
        Navigator.pop(context, true);
      }
    } on PrescriptionsException catch (e) {
      if (mounted) {
        setState(() => _erreur = e.message);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool cnam = _assurance?.estObligatoire ?? false;
    final DateTime? fin = _fin;

    return Scaffold(
      appBar: AppBar(
        title: Text(_edition ? 'Modifier le contrat' : 'Nouveau contrat'),
        actions: [
          if (_edition && widget.contrat?.dateFin == null)
            TextButton(
              onPressed: _enregistrement ? null : _resilier,
              child: const Text('Résilier', style: TextStyle(color: AppColors.danger)),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SectionFormulaire(
              titre: 'Assurance',
              icon: Icons.shield_outlined,
              children: [
                AppDropdownField<int>(
                  label: 'Organisme',
                  icon: Icons.account_balance_outlined,
                  value: _assuranceId,
                  items: [
                    for (final Assurance a in _assurances)
                      DropdownMenuItem<int>(value: a.id, child: Text('${a.nom} (${a.type.libelle})')),
                  ],
                  onChanged: (int? v) => setState(() => _assuranceId = v),
                ),
                AppTextField(
                  controller: _numeroCtrl,
                  label: "Numéro d'adhérent",
                  hint: '${ContratManager.longueurNumero} chiffres',
                  icon: Icons.badge_outlined,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (String? v) {
                    final String t = (v ?? '').trim();
                    if (t.length != ContratManager.longueurNumero) {
                      return "Numéro d'adhérent invalide (${ContratManager.longueurNumero} chiffres)";
                    }
                    return null;
                  },
                ),
                AppDropdownField<Beneficiaire>(
                  label: 'Bénéficiaire',
                  icon: Icons.family_restroom_rounded,
                  value: _beneficiaire,
                  items: [
                    for (final Beneficiaire b in Beneficiaire.values)
                      DropdownMenuItem<Beneficiaire>(value: b, child: Text(b.libelle)),
                  ],
                  onChanged: (Beneficiaire? v) {
                    if (v != null) {
                      setState(() => _beneficiaire = v);
                    }
                  },
                ),
                if (cnam)
                  AppDropdownField<FiliereCnam?>(
                    label: 'Filière CNAM',
                    icon: Icons.alt_route_rounded,
                    value: _filiere,
                    items: [
                      const DropdownMenuItem<FiliereCnam?>(value: null, child: Text('Non précisée')),
                      for (final FiliereCnam f in FiliereCnam.values)
                        DropdownMenuItem<FiliereCnam?>(value: f, child: Text(f.libelle)),
                    ],
                    onChanged: (FiliereCnam? v) => setState(() => _filiere = v),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            SectionFormulaire(
              titre: 'Période',
              icon: Icons.date_range_outlined,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event_outlined),
                  title: const Text('Début'),
                  subtitle: Text(Formatters.date(_debut)),
                  onTap: () => _choisirDate(debut: true),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event_busy_outlined),
                  title: const Text('Fin (facultatif)'),
                  subtitle: Text(fin == null ? 'Contrat en cours' : Formatters.date(fin)),
                  trailing: fin == null
                      ? null
                      : IconButton(
                          tooltip: 'Retirer la date de fin',
                          onPressed: () => setState(() => _fin = null),
                          icon: const Icon(Icons.close_rounded),
                        ),
                  onTap: () => _choisirDate(debut: false),
                ),
              ],
            ),
            if (cnam) ...[
              const SizedBox(height: 12),
              SectionFormulaire(
                titre: 'APCI (prise en charge à 100 %)',
                icon: Icons.favorite_border_rounded,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Patient en APCI'),
                    value: _apci,
                    onChanged: (bool v) => setState(() => _apci = v),
                  ),
                  if (_apci)
                    AppDropdownField<String>(
                      label: 'Maladie',
                      icon: Icons.medical_information_outlined,
                      value: _codeApci,
                      items: [
                        for (final Apci a in _codes)
                          DropdownMenuItem<String>(
                            value: a.codeCim10,
                            child: Text('${a.codeCim10} · ${a.libelle}'),
                          ),
                      ],
                      onChanged: (String? v) => setState(() => _codeApci = v),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            if (_erreur != null) ...[
              ErrorBanner(message: _erreur!),
              const SizedBox(height: 16),
            ],
            PrimaryButton(
              label: _edition ? 'Enregistrer' : 'Ajouter le contrat',
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
