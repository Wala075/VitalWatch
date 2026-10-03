import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_dropdown_field.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../core/widgets/error_banner.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../models/service.dart';
import '../../data/medecin_repository.dart';
import '../../domain/staff_manager.dart';
import '../../domain/staff_models.dart';
import '../widgets/form_section.dart';

class ServiceFormScreen extends StatefulWidget {
  const ServiceFormScreen({super.key, this.service, this.peutSupprimer = false});

  final Service? service;
  final bool peutSupprimer;

  @override
  State<ServiceFormScreen> createState() => _ServiceFormScreenState();
}

class _ServiceFormScreenState extends State<ServiceFormScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nomCtrl = TextEditingController();
  final TextEditingController _etageCtrl = TextEditingController();
  final TextEditingController _telCtrl = TextEditingController();
  final TextEditingController _capaciteCtrl = TextEditingController();
  final StaffManager _manager = StaffManager();
  final MedecinRepository _medecinRepo = MedecinRepository();

  int? _chefId;
  List<MedecinDetail> _medecins = [];
  bool _enregistrement = false;
  String? _erreur;

  bool get _edition => widget.service != null;

  @override
  void initState() {
    super.initState();
    final Service? s = widget.service;
    if (s != null) {
      _nomCtrl.text = s.nom;
      _etageCtrl.text = s.etage?.toString() ?? '';
      _telCtrl.text = s.telephone;
      _capaciteCtrl.text = '${s.capacite}';
      _chefId = s.chefServiceId;
      _chargerMedecins(s.id);
    }
  }

  Future<void> _chargerMedecins(int? serviceId) async {
    if (serviceId == null) {
      return;
    }
    final List<MedecinDetail> res =
        await _medecinRepo.rechercher(MedecinFiltre(serviceId: serviceId));
    if (!mounted) {
      return;
    }
    setState(() => _medecins = res);
  }

  @override
  void dispose() {
    _nomCtrl.dispose();
    _etageCtrl.dispose();
    _telCtrl.dispose();
    _capaciteCtrl.dispose();
    super.dispose();
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
      final Service s = Service(
        id: widget.service?.id,
        nom: _nomCtrl.text.trim(),
        etage: int.tryParse(_etageCtrl.text.trim()),
        telephone: Validators.normaliserTelephone(_telCtrl.text),
        capacite: int.parse(_capaciteCtrl.text.trim()),
        chefServiceId: _chefId,
      );
      await _manager.enregistrerService(s);
      if (!mounted) return;
      Navigator.pop(context, true);
    } on StaffException catch (e) {
      if (!mounted) return;
      setState(() => _erreur = e.message);
    } finally {
      if (mounted) {
        setState(() => _enregistrement = false);
      }
    }
  }

  Future<void> _supprimer() async {
    final Service? s = widget.service;
    final int? id = s?.id;
    if (s == null || id == null) {
      return;
    }
    final bool ok = await showConfirmDialog(
      context,
      titre: 'Supprimer « ${s.nom} » ?',
      message: 'Les médecins et patients de ce service ne seront plus '
          'rattachés à aucun service.',
      confirmer: 'Supprimer',
      danger: true,
    );
    if (!ok) return;
    await _manager.supprimerService(id);
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_edition ? 'Modifier le service' : 'Nouveau service'),
        actions: [
          if (_edition && widget.peutSupprimer)
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
            FormSection(
              titre: 'Informations',
              icon: Icons.apartment,
              children: [
                AppTextField(
                  controller: _nomCtrl,
                  label: 'Nom du service',
                  icon: Icons.apartment,
                  textCapitalization: TextCapitalization.words,
                  validator: (String? v) =>
                      Validators.requis(v, champ: 'Le nom'),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: AppTextField(
                        controller: _etageCtrl,
                        label: 'Étage',
                        icon: Icons.stairs_outlined,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        validator: Validators.entierOptionnel,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppTextField(
                        controller: _capaciteCtrl,
                        label: 'Capacité',
                        icon: Icons.bed_outlined,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        validator: (String? v) =>
                            Validators.entier(v, champ: 'La capacité', min: 1),
                      ),
                    ),
                  ],
                ),
                AppTextField(
                  controller: _telCtrl,
                  label: 'Téléphone',
                  hint: '+216 73 000 000',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  validator: Validators.telephone,
                ),
              ],
            ),
            const SizedBox(height: 12),
            FormSection(
              titre: 'Chef de service',
              icon: Icons.workspace_premium_outlined,
              children: [
                if (!_edition)
                  const Text(
                    'Vous pourrez choisir le chef après avoir ajouté des '
                    'médecins à ce service.',
                    style: TextStyle(color: AppColors.textSecondary),
                  )
                else if (_medecins.isEmpty)
                  const Text(
                    'Aucun médecin dans ce service pour le moment.',
                    style: TextStyle(color: AppColors.textSecondary),
                  )
                else
                  AppDropdownField<int?>(
                    label: 'Chef de service',
                    icon: Icons.person_outline,
                    value: _chefId,
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('Aucun'),
                      ),
                      for (final MedecinDetail d in _medecins)
                        DropdownMenuItem<int?>(
                          value: d.medecin.id,
                          child: Text(d.medecin.nomComplet),
                        ),
                    ],
                    onChanged: (int? v) => setState(() => _chefId = v),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (_erreur != null) ...[
              ErrorBanner(message: _erreur!),
              const SizedBox(height: 16),
            ],
            PrimaryButton(
              label: _edition ? 'Enregistrer' : 'Ajouter le service',
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
