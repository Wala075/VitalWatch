import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../core/widgets/error_banner.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../models/pharmacien.dart';
import '../../domain/staff_manager.dart';
import '../../domain/staff_models.dart';
import '../widgets/avatar_initiales.dart';
import '../widgets/compte_cree_dialog.dart';
import '../widgets/form_section.dart';
import '../widgets/info_compte.dart';

/// Ajout / modification / suppression d'un pharmacien (admin).
/// À l'ajout, son compte est créé et les identifiants envoyés par mail.
class PharmacienFormScreen extends StatefulWidget {
  const PharmacienFormScreen({super.key, this.pharmacien});

  final Pharmacien? pharmacien;

  @override
  State<PharmacienFormScreen> createState() => _PharmacienFormScreenState();
}

class _PharmacienFormScreenState extends State<PharmacienFormScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nomCtrl = TextEditingController();
  final TextEditingController _prenomCtrl = TextEditingController();
  final TextEditingController _matriculeCtrl = TextEditingController();
  final TextEditingController _telCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  final StaffManager _manager = StaffManager();

  bool _disponible = true;
  bool _enregistrement = false;
  String? _erreur;

  bool get _edition => widget.pharmacien != null;

  @override
  void initState() {
    super.initState();
    final Pharmacien? i = widget.pharmacien;
    if (i != null) {
      _nomCtrl.text = i.nom;
      _prenomCtrl.text = i.prenom;
      _matriculeCtrl.text = i.matricule;
      _telCtrl.text = i.telephone;
      _emailCtrl.text = i.email;
      _disponible = i.disponible;
    }
  }

  @override
  void dispose() {
    _nomCtrl.dispose();
    _prenomCtrl.dispose();
    _matriculeCtrl.dispose();
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
      final Pharmacien i = Pharmacien(
        id: widget.pharmacien?.id,
        nom: _nomCtrl.text.trim(),
        prenom: _prenomCtrl.text.trim(),
        matricule: _matriculeCtrl.text.trim().toUpperCase(),
        telephone: Validators.normaliserTelephone(_telCtrl.text),
        email: _emailCtrl.text.trim().toLowerCase(),
        disponible: _disponible,
      );
      final ResultatEnregistrement res = await _manager.enregistrerPharmacien(i);
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
    final Pharmacien? i = widget.pharmacien;
    final int? id = i?.id;
    if (i == null || id == null) return;
    final bool ok = await showConfirmDialog(
      context,
      titre: 'Supprimer ${i.nomComplet} ?',
      message: 'Sa fiche et son compte de connexion seront supprimés.',
      confirmer: 'Supprimer',
      danger: true,
    );
    if (!ok) return;
    await _manager.supprimerPharmacien(id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${i.nomComplet} supprimé(e)')),
    );
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final String? erreur = _erreur;

    return Scaffold(
      appBar: AppBar(
        title: Text(_edition ? 'Modifier le pharmacien' : 'Nouveau pharmacien'),
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
            Center(
              child: ListenableBuilder(
                listenable: Listenable.merge([_prenomCtrl, _nomCtrl]),
                builder: (BuildContext context, Widget? _) => AvatarInitiales(
                  prenom: _prenomCtrl.text,
                  nom: _nomCtrl.text,
                  couleur: AppColors.purple,
                  rayon: 40,
                ),
              ),
            ),
            const SizedBox(height: 16),
            FormSection(
              titre: 'Identité',
              icon: Icons.person_outline,
              children: [
                AppTextField(
                  controller: _prenomCtrl,
                  label: 'Prénom',
                  icon: Icons.person_outline,
                  textCapitalization: TextCapitalization.words,
                  validator: (String? v) =>
                      Validators.requis(v, champ: 'Le prénom'),
                ),
                AppTextField(
                  controller: _nomCtrl,
                  label: 'Nom',
                  icon: Icons.person,
                  textCapitalization: TextCapitalization.words,
                  validator: (String? v) => Validators.requis(v, champ: 'Le nom'),
                ),
                AppTextField(
                  controller: _matriculeCtrl,
                  label: 'Matricule',
                  hint: 'PH-3003',
                  icon: Icons.badge_outlined,
                  textCapitalization: TextCapitalization.characters,
                  validator: (String? v) =>
                      Validators.requis(v, champ: 'Le matricule'),
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
              ],
            ),
            const SizedBox(height: 12),
            FormSection(
              titre: 'Disponibilité',
              icon: Icons.event_available_outlined,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Disponible'),
                  subtitle: const Text('Désactivez pendant un congé'),
                  value: _disponible,
                  onChanged: (bool v) => setState(() => _disponible = v),
                ),
              ],
            ),
            if (!_edition) ...[
              const SizedBox(height: 12),
              const EncadreInfo(
                texte: 'Un compte de connexion sera créé automatiquement et '
                    'les identifiants envoyés par mail.',
              ),
            ],
            const SizedBox(height: 16),
            if (erreur != null) ...[
              ErrorBanner(message: erreur),
              const SizedBox(height: 16),
            ],
            PrimaryButton(
              label: _edition ? 'Enregistrer' : 'Ajouter le pharmacien',
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
