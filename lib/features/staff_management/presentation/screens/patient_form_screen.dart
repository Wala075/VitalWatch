import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_dropdown_field.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../core/widgets/error_banner.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../models/patient.dart';
import '../../../../models/service.dart';
import '../../data/medecin_repository.dart';
import '../../data/service_repository.dart';
import '../../domain/staff_manager.dart';
import '../../domain/staff_models.dart';
import '../widgets/compte_cree_dialog.dart';
import '../widgets/form_section.dart';

class PatientFormScreen extends StatefulWidget {
  const PatientFormScreen({super.key, this.patient, this.peutSupprimer = false});

  final Patient? patient;
  final bool peutSupprimer;

  @override
  State<PatientFormScreen> createState() => _PatientFormScreenState();
}

class _PatientFormScreenState extends State<PatientFormScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _cinCtrl = TextEditingController();
  final TextEditingController _nomCtrl = TextEditingController();
  final TextEditingController _prenomCtrl = TextEditingController();
  final TextEditingController _dateCtrl = TextEditingController();
  final TextEditingController _telCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _adresseCtrl = TextEditingController();
  final TextEditingController _urgNomCtrl = TextEditingController();
  final TextEditingController _urgTelCtrl = TextEditingController();

  final StaffManager _manager = StaffManager();
  final ServiceRepository _serviceRepo = ServiceRepository();
  final MedecinRepository _medecinRepo = MedecinRepository();

  List<Service> _services = [];
  List<MedecinDetail> _medecinsService = [];
  DateTime? _dateNaissance;
  String _sexe = 'M';
  String? _groupe;
  int? _serviceId;
  int? _medecinId;
  bool _enregistrement = false;
  String? _erreur;

  bool get _edition => widget.patient != null;

  @override
  void initState() {
    super.initState();
    final Patient? p = widget.patient;
    if (p != null) {
      _cinCtrl.text = p.cin;
      _nomCtrl.text = p.nom;
      _prenomCtrl.text = p.prenom;
      _dateNaissance = p.dateNaissance;
      _dateCtrl.text = Formatters.date(p.dateNaissance);
      _sexe = p.sexe;
      _telCtrl.text = p.telephone;
      _emailCtrl.text = p.email ?? '';
      _adresseCtrl.text = p.adresse;
      _groupe = p.groupeSanguin;
      _urgNomCtrl.text = p.contactUrgenceNom ?? '';
      _urgTelCtrl.text = p.contactUrgenceTel ?? '';
      _serviceId = p.serviceId;
      _medecinId = p.medecinId;
    }
    _chargerServices();
    if (_serviceId != null) {
      _chargerMedecins(_serviceId);
    }
  }

  Future<void> _chargerServices() async {
    final List<Service> res = await _serviceRepo.lister();
    if (!mounted) return;
    setState(() => _services = res);
  }

  Future<void> _chargerMedecins(int? serviceId) async {
    if (serviceId == null) {
      return;
    }
    final List<MedecinDetail> res =
        await _medecinRepo.rechercher(MedecinFiltre(serviceId: serviceId));
    if (!mounted || serviceId != _serviceId) return;
    setState(() => _medecinsService = res);
  }

  void _changerService(int? serviceId) {
    setState(() {
      _serviceId = serviceId;
      _medecinId = null; // médecin « Automatique » par défaut
      _medecinsService = [];
    });
    _chargerMedecins(serviceId);
  }

  @override
  void dispose() {
    for (final TextEditingController c in [
      _cinCtrl,
      _nomCtrl,
      _prenomCtrl,
      _dateCtrl,
      _telCtrl,
      _emailCtrl,
      _adresseCtrl,
      _urgNomCtrl,
      _urgTelCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _choisirDate() async {
    final DateTime maintenant = DateTime.now();
    final DateTime? d = await showDatePicker(
      context: context,
      initialDate: _dateNaissance ?? DateTime(maintenant.year - 30),
      firstDate: DateTime(maintenant.year - 120),
      lastDate: maintenant,
      helpText: 'Date de naissance',
    );
    if (d == null || !mounted) return;
    setState(() {
      _dateNaissance = d;
      _dateCtrl.text = Formatters.date(d);
    });
  }

  void _scannerCin() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Scan de la CIN (Google ML Kit) : disponible à l\'étape 2'),
      ),
    );
  }

  String? _texteOuNull(TextEditingController c) {
    final String t = c.text.trim();
    return t.isEmpty ? null : t;
  }

  Future<void> _enregistrer({bool ignorerDoublon = false}) async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final DateTime? naissance = _dateNaissance;
    if (naissance == null) {
      return;
    }
    setState(() {
      _enregistrement = true;
      _erreur = null;
    });

    final String? email = _texteOuNull(_emailCtrl)?.toLowerCase();
    final String? urgTel = _texteOuNull(_urgTelCtrl);
    final Patient p = Patient(
      id: widget.patient?.id,
      cin: _cinCtrl.text.trim(),
      nom: _nomCtrl.text.trim(),
      prenom: _prenomCtrl.text.trim(),
      dateNaissance: naissance,
      sexe: _sexe,
      telephone: Validators.normaliserTelephone(_telCtrl.text),
      adresse: _adresseCtrl.text.trim(),
      groupeSanguin: _groupe,
      email: email,
      contactUrgenceNom: _texteOuNull(_urgNomCtrl),
      contactUrgenceTel:
          urgTel == null ? null : Validators.normaliserTelephone(urgTel),
      serviceId: _serviceId,
      medecinId: _medecinId,
    );

    try {
      final ResultatEnregistrement res =
          await _manager.enregistrerPatient(p, ignorerDoublon: ignorerDoublon);
      if (!mounted) return;

      await informerResultat(context, res);
      if (!mounted) return;
      Navigator.pop(context, true);
    } on DoublonPatientException catch (e) {
      if (!mounted) return;
      setState(() => _enregistrement = false);
      final Patient d = e.existant;
      final bool continuer = await showConfirmDialog(
        context,
        titre: 'Doublon possible',
        message: 'Le patient ${d.nomComplet} (CIN ${d.cin}), né le '
            '${Formatters.date(d.dateNaissance)}, porte le même nom et la même '
            'date de naissance.\n\nEnregistrer quand même ?',
        confirmer: 'Enregistrer',
      );
      if (continuer && mounted) {
        await _enregistrer(ignorerDoublon: true);
      }
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
    final Patient? p = widget.patient;
    final int? id = p?.id;
    if (p == null || id == null) {
      return;
    }
    final bool ok = await showConfirmDialog(
      context,
      titre: 'Supprimer ${p.nomComplet} ?',
      message: 'Le dossier du patient et son compte de connexion seront '
          'supprimés définitivement.',
      confirmer: 'Supprimer',
      danger: true,
    );
    if (!ok) return;
    await _manager.supprimerPatient(id);
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_edition ? 'Modifier le patient' : 'Nouveau patient'),
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
            if (!_edition) ...[
              OutlinedButton.icon(
                onPressed: _scannerCin,
                icon: const Icon(Icons.document_scanner_outlined),
                label: const Text('Scanner la CIN pour pré-remplir'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            FormSection(
              titre: 'Identité',
              icon: Icons.badge_outlined,
              children: [
                AppTextField(
                  controller: _cinCtrl,
                  label: 'CIN',
                  hint: '8 chiffres',
                  icon: Icons.credit_card,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(8),
                  ],
                  validator: Validators.cin,
                ),
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
                  controller: _dateCtrl,
                  label: 'Date de naissance',
                  hint: 'jj/mm/aaaa',
                  icon: Icons.cake_outlined,
                  readOnly: true,
                  onTap: _choisirDate,
                  suffix: const Icon(Icons.calendar_month),
                  validator: (_) => Validators.dateNaissance(_dateNaissance),
                ),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment<String>(
                      value: 'M',
                      label: Text('Homme'),
                      icon: Icon(Icons.male),
                    ),
                    ButtonSegment<String>(
                      value: 'F',
                      label: Text('Femme'),
                      icon: Icon(Icons.female),
                    ),
                  ],
                  selected: {_sexe},
                  onSelectionChanged: (Set<String> s) =>
                      setState(() => _sexe = s.first),
                ),
                AppDropdownField<String?>(
                  label: 'Groupe sanguin',
                  icon: Icons.bloodtype_outlined,
                  value: _groupe,
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Non renseigné'),
                    ),
                    for (final String g in Patient.groupesSanguins)
                      DropdownMenuItem<String?>(value: g, child: Text(g)),
                  ],
                  onChanged: (String? v) => setState(() => _groupe = v),
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
                  label: 'Email (optionnel, crée un compte)',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: Validators.emailOptionnel,
                ),
                AppTextField(
                  controller: _adresseCtrl,
                  label: 'Adresse',
                  icon: Icons.home_outlined,
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: 2,
                ),
              ],
            ),
            const SizedBox(height: 12),
            FormSection(
              titre: "Contact d'urgence",
              icon: Icons.emergency_outlined,
              children: [
                AppTextField(
                  controller: _urgNomCtrl,
                  label: 'Nom du contact',
                  icon: Icons.person_outline,
                  textCapitalization: TextCapitalization.words,
                ),
                AppTextField(
                  controller: _urgTelCtrl,
                  label: 'Téléphone du contact',
                  icon: Icons.phone_in_talk_outlined,
                  keyboardType: TextInputType.phone,
                  validator: Validators.telephoneOptionnel,
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
                    for (final Service s in _services)
                      DropdownMenuItem<int?>(value: s.id, child: Text(s.nom)),
                  ],
                  validator: (int? v) =>
                      v == null ? 'Choisissez un service' : null,
                  onChanged: _changerService,
                ),
                AppDropdownField<int?>(
                  label: 'Médecin traitant',
                  icon: Icons.medical_services_outlined,
                  value: _medecinId,
                  enabled: _serviceId != null,
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('Automatique (le moins chargé)'),
                    ),
                    for (final MedecinDetail d in _medecinsService)
                      DropdownMenuItem<int?>(
                        value: d.medecin.id,
                        child: Text(
                          '${d.medecin.nomComplet} · ${d.nbPatients} patient(s)'
                          '${d.medecin.disponible ? '' : ' · indisponible'}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (int? v) => setState(() => _medecinId = v),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_erreur != null) ...[
              ErrorBanner(message: _erreur!),
              const SizedBox(height: 16),
            ],
            PrimaryButton(
              label: _edition ? 'Enregistrer' : 'Ajouter le patient',
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
