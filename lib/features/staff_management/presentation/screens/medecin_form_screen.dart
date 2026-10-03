import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_dropdown_field.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../core/widgets/error_banner.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../models/medecin.dart';
import '../../../../models/service.dart';
import '../../data/service_repository.dart';
import '../../domain/staff_manager.dart';
import '../../domain/staff_models.dart';
import '../widgets/avatar_initiales.dart';
import '../widgets/compte_cree_dialog.dart';
import '../widgets/form_section.dart';

class MedecinFormScreen extends StatefulWidget {
  const MedecinFormScreen({super.key, this.medecin});

  final Medecin? medecin;

  @override
  State<MedecinFormScreen> createState() => _MedecinFormScreenState();
}

class _MedecinFormScreenState extends State<MedecinFormScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nomCtrl = TextEditingController();
  final TextEditingController _prenomCtrl = TextEditingController();
  final TextEditingController _matriculeCtrl = TextEditingController();
  final TextEditingController _specialiteCtrl = TextEditingController();
  final TextEditingController _telCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  final StaffManager _manager = StaffManager();
  final ServiceRepository _serviceRepo = ServiceRepository();

  List<Service> _services = [];
  int? _serviceId;
  bool _disponible = true;
  bool _enregistrement = false;
  String? _erreur;

  bool get _edition => widget.medecin != null;

  @override
  void initState() {
    super.initState();
    final Medecin? m = widget.medecin;
    if (m != null) {
      _nomCtrl.text = m.nom;
      _prenomCtrl.text = m.prenom;
      _matriculeCtrl.text = m.matricule;
      _specialiteCtrl.text = m.specialite;
      _telCtrl.text = m.telephone;
      _emailCtrl.text = m.email;
      _serviceId = m.serviceId;
      _disponible = m.disponible;
    }
    _chargerServices();
  }

  Future<void> _chargerServices() async {
    final List<Service> res = await _serviceRepo.lister();
    if (!mounted) return;
    setState(() => _services = res);
  }

  @override
  void dispose() {
    _nomCtrl.dispose();
    _prenomCtrl.dispose();
    _matriculeCtrl.dispose();
    _specialiteCtrl.dispose();
    _telCtrl.dispose();
    _emailCtrl.dispose();
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
      final Medecin m = Medecin(
        id: widget.medecin?.id,
        nom: _nomCtrl.text.trim(),
        prenom: _prenomCtrl.text.trim(),
        matricule: _matriculeCtrl.text.trim().toUpperCase(),
        specialite: _specialiteCtrl.text.trim(),
        telephone: Validators.normaliserTelephone(_telCtrl.text),
        email: _emailCtrl.text.trim().toLowerCase(),
        photo: widget.medecin?.photo,
        serviceId: _serviceId,
        disponible: _disponible,
      );
      final ResultatEnregistrement res = await _manager.enregistrerMedecin(m);
      if (!mounted) return;

      await informerResultat(context, res);
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
    final Medecin? m = widget.medecin;
    final int? id = m?.id;
    if (m == null || id == null) {
      return;
    }
    final bool ok = await showConfirmDialog(
      context,
      titre: 'Supprimer ${m.nomComplet} ?',
      message: 'Son compte de connexion sera supprimé et ses patients seront '
          'réaffectés automatiquement au médecin le moins chargé du service.',
      confirmer: 'Supprimer',
      danger: true,
    );
    if (!ok) return;
    final int n = await _manager.supprimerMedecin(id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Médecin supprimé · $n patient(s) réaffecté(s)')),
    );
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_edition ? 'Modifier le médecin' : 'Nouveau médecin'),
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
                  hint: 'MAT-1005',
                  icon: Icons.badge_outlined,
                  textCapitalization: TextCapitalization.characters,
                  validator: (String? v) =>
                      Validators.requis(v, champ: 'Le matricule'),
                ),
                AppTextField(
                  controller: _specialiteCtrl,
                  label: 'Spécialité',
                  hint: 'Cardiologie, Pédiatrie...',
                  icon: Icons.medical_services_outlined,
                  textCapitalization: TextCapitalization.sentences,
                  validator: (String? v) =>
                      Validators.requis(v, champ: 'La spécialité'),
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
              titre: 'Affectation',
              icon: Icons.apartment,
              children: [
                AppDropdownField<int?>(
                  label: 'Service',
                  icon: Icons.apartment,
                  value: _serviceId,
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('Aucun service'),
                    ),
                    for (final Service s in _services)
                      DropdownMenuItem<int?>(value: s.id, child: Text(s.nom)),
                  ],
                  onChanged: (int? v) => setState(() => _serviceId = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Disponible'),
                  subtitle: const Text(
                    'Un médecin indisponible ne reçoit pas de nouveaux patients',
                  ),
                  value: _disponible,
                  onChanged: (bool v) => setState(() => _disponible = v),
                ),
              ],
            ),
            if (!_edition) ...[
              const SizedBox(height: 12),
              const _InfoCompte(),
            ],
            const SizedBox(height: 16),
            if (_erreur != null) ...[
              ErrorBanner(message: _erreur!),
              const SizedBox(height: 16),
            ],
            PrimaryButton(
              label: _edition ? 'Enregistrer' : 'Ajouter le médecin',
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

class _InfoCompte extends StatelessWidget {
  const _InfoCompte();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, color: AppColors.primary, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Un compte de connexion sera créé automatiquement avec un '
              'mot de passe temporaire.',
              style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
