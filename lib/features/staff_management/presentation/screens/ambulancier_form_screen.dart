import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_dropdown_field.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../core/widgets/error_banner.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../models/ambulancier.dart';
import '../../domain/staff_manager.dart';
import '../../domain/staff_models.dart';
import '../widgets/compte_cree_dialog.dart';
import '../widgets/form_section.dart';
import '../widgets/info_compte.dart';

/// Ajout / modification / suppression d'un ambulancier (admin) et de son
/// compte de connexion. L'affectation à une ambulance se fait dans le
/// module Ambulances.
class AmbulancierFormScreen extends StatefulWidget {
  const AmbulancierFormScreen({super.key, this.fiche});

  final AmbulancierCompte? fiche;

  @override
  State<AmbulancierFormScreen> createState() => _AmbulancierFormScreenState();
}

class _AmbulancierFormScreenState extends State<AmbulancierFormScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nomCtrl = TextEditingController();
  final TextEditingController _telCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  final StaffManager _manager = StaffManager();

  RoleAmbulancier _fonction = RoleAmbulancier.conducteur;
  bool _disponible = true;
  bool _enregistrement = false;
  String? _erreur;

  bool get _edition => widget.fiche != null;

  @override
  void initState() {
    super.initState();
    final AmbulancierCompte? f = widget.fiche;
    if (f != null) {
      _nomCtrl.text = f.ambulancier.nom;
      _telCtrl.text = f.ambulancier.telephone;
      _emailCtrl.text = f.email ?? '';
      _fonction = f.ambulancier.role;
      _disponible = f.ambulancier.disponible;
    }
  }

  @override
  void dispose() {
    _nomCtrl.dispose();
    _telCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _enregistrer() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _enregistrement = true;
      _erreur = null;
    });

    try {
      final Ambulancier? ancien = widget.fiche?.ambulancier;
      final Ambulancier a = Ambulancier(
        id: ancien?.id,
        nom: _nomCtrl.text,
        role: _fonction,
        telephone: _telCtrl.text,
        disponible: _disponible,
        ambulanceId: ancien?.ambulanceId,
      );
      final ResultatEnregistrement res =
          await _manager.enregistrerAmbulancier(a, _emailCtrl.text);
      if (!mounted) return;

      await informerResultat(context, res);
      if (!mounted) return;
      Navigator.pop(context, true);
    } on StaffException catch (e) {
      if (!mounted) return;
      setState(() => _erreur = e.message);
    } finally {
      if (mounted) setState(() => _enregistrement = false);
    }
  }

  Future<void> _supprimer() async {
    final Ambulancier? a = widget.fiche?.ambulancier;
    final int? id = a?.id;
    if (a == null || id == null) return;
    final bool ok = await showConfirmDialog(
      context,
      titre: 'Supprimer ${a.nom} ?',
      message: 'Sa fiche et son compte de connexion seront supprimés.',
      confirmer: 'Supprimer',
      danger: true,
    );
    if (!ok || !mounted) return;
    try {
      await _manager.supprimerAmbulancier(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${a.nom} supprimé(e)')),
      );
      Navigator.pop(context, true);
    } on StaffException catch (e) {
      if (!mounted) return;
      setState(() => _erreur = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AmbulancierCompte? fiche = widget.fiche;
    final bool affecte = fiche?.ambulancier.ambulanceId != null;
    final bool sansCompte = fiche != null && fiche.email == null;
    final String? erreur = _erreur;

    return Scaffold(
      appBar: AppBar(
        title: Text(_edition ? "Modifier l'ambulancier" : 'Nouvel ambulancier'),
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
            FormSection(
              titre: 'Identité',
              icon: Icons.person_outline,
              children: [
                AppTextField(
                  controller: _nomCtrl,
                  label: 'Prénom et nom',
                  hint: 'Ali Ben Amor',
                  icon: Icons.person_outline,
                  textCapitalization: TextCapitalization.words,
                  validator: (String? v) {
                    final String t = (v ?? '').trim();
                    if (t.isEmpty) return 'Le nom est obligatoire';
                    if (t.length < 3) return 'Au moins 3 caractères';
                    return null;
                  },
                ),
                AppDropdownField<RoleAmbulancier>(
                  label: 'Fonction',
                  icon: Icons.medical_information_outlined,
                  value: _fonction,
                  items: [
                    for (final RoleAmbulancier r in RoleAmbulancier.values)
                      DropdownMenuItem<RoleAmbulancier>(
                        value: r,
                        child: Text(r.libelle),
                      ),
                  ],
                  onChanged: (RoleAmbulancier? v) {
                    if (v != null) setState(() => _fonction = v);
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            FormSection(
              titre: 'Contact',
              icon: Icons.contact_phone_outlined,
              children: [
                AppTextField(
                  controller: _telCtrl,
                  label: 'Téléphone',
                  hint: '+216 22 123 456',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  validator: Validators.telephone,
                ),
                AppTextField(
                  controller: _emailCtrl,
                  label: 'Email (identifiant de connexion)',
                  hint: 'prenom.nom@vitalwatch.tn',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: Validators.email,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Disponible'),
                  subtitle: const Text('Désactivez pendant un congé'),
                  value: _disponible,
                  onChanged: (bool v) => setState(() => _disponible = v),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (!_edition || sansCompte)
              const EncadreInfo(
                texte: 'Un compte de connexion sera créé automatiquement et '
                    'les identifiants envoyés par mail.',
              ),
            if (affecte) ...[
              const SizedBox(height: 8),
              const EncadreInfo(
                icon: Icons.local_hospital_outlined,
                couleur: AppColors.warning,
                texte: "Affecté à une ambulance. L'affectation se gère dans le "
                    'module Ambulances.',
              ),
            ],
            const SizedBox(height: 16),
            if (erreur != null) ...[
              ErrorBanner(message: erreur),
              const SizedBox(height: 16),
            ],
            PrimaryButton(
              label: _edition ? 'Enregistrer' : "Ajouter l'ambulancier",
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
