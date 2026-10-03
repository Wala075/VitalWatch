import 'package:flutter/material.dart';

import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_dropdown_field.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../core/widgets/error_banner.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../domain/dispatch_manager.dart';
import '../../domain/dispatch_models.dart';
import '../../domain/models/ambulancier.dart';
import '../providers/dispatch_controller.dart';
import '../widgets/dispatch_ui.dart';

class AmbulancierFormScreen extends StatefulWidget {
  const AmbulancierFormScreen({super.key, this.ambulancier, this.peutSupprimer = false});

  final Ambulancier? ambulancier;
  final bool peutSupprimer;

  @override
  State<AmbulancierFormScreen> createState() => _AmbulancierFormScreenState();
}

class _AmbulancierFormScreenState extends State<AmbulancierFormScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nomCtrl = TextEditingController();
  final TextEditingController _telCtrl = TextEditingController();
  final DispatchController _ctrl = DispatchController.instance;

  RoleAmbulancier _role = RoleAmbulancier.secouriste;
  int? _ambulanceId;
  bool _disponible = true;
  bool _enregistrement = false;
  String? _erreur;

  bool get _edition => widget.ambulancier != null;

  DispatchManager get _manager => _ctrl.manager;

  @override
  void initState() {
    super.initState();
    final Ambulancier? a = widget.ambulancier;
    if (a != null) {
      _nomCtrl.text = a.nom;
      _telCtrl.text = a.telephone;
      _role = a.role;
      _ambulanceId = a.ambulanceId;
      _disponible = a.disponible;
    }
  }

  @override
  void dispose() {
    _nomCtrl.dispose();
    _telCtrl.dispose();
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
      await _manager.enregistrerAmbulancier(Ambulancier(
        id: widget.ambulancier?.id,
        nom: _nomCtrl.text,
        role: _role,
        telephone: _telCtrl.text,
        disponible: _disponible,
        ambulanceId: _ambulanceId,
      ));
      await _ctrl.rafraichir();
      if (!mounted) {
        return;
      }
      Navigator.pop(context, true);
    } on DispatchException catch (e) {
      _echec(e.message);
    } catch (e) {
      _echec('Enregistrement impossible : $e');
    }
  }

  void _echec(String message) {
    if (!mounted) {
      return;
    }
    setState(() {
      _erreur = message;
      _enregistrement = false;
    });
  }

  Future<void> _supprimer() async {
    final Ambulancier? a = widget.ambulancier;
    final int? id = a?.id;
    if (a == null || id == null) {
      return;
    }
    final bool ok = await showConfirmDialog(
      context,
      titre: 'Supprimer ${a.nom}',
      message: 'Cet ambulancier sera retiré de son équipage.',
      confirmer: 'Supprimer',
      danger: true,
    );
    if (!ok) {
      return;
    }
    try {
      await _manager.supprimerAmbulancier(id);
      await _ctrl.rafraichir();
      if (mounted) {
        Navigator.pop(context, true);
      }
    } on DispatchException catch (e) {
      _echec(e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String? erreur = _erreur;
    final List<DropdownMenuItem<int?>> ambulances = [
      const DropdownMenuItem<int?>(value: null, child: Text('Non affecté')),
    ];
    for (final AmbulanceDetail d in _ctrl.flotte) {
      ambulances.add(DropdownMenuItem<int?>(
        value: d.ambulance.id,
        child: Text(
          '${d.ambulance.immatriculation} · ${d.ambulance.type.libelle} '
          '(${d.nbEquipiers}/${DispatchManager.maxEquipiers})',
        ),
      ));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_edition ? "Modifier l'ambulancier" : 'Nouvel ambulancier'),
        actions: [
          if (_edition && widget.peutSupprimer)
            IconButton(
              tooltip: 'Supprimer',
              icon: const Icon(Icons.delete_outline),
              onPressed: _supprimer,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (erreur != null) ...[
              ErrorBanner(message: erreur),
              const SizedBox(height: 12),
            ],
            Section(
              titre: 'Identité',
              icone: Icons.badge_outlined,
              children: [
                AppTextField(
                  controller: _nomCtrl,
                  label: 'Nom complet',
                  icon: Icons.person_outline,
                  textCapitalization: TextCapitalization.words,
                  validator: (String? v) => Validators.requis(v, champ: 'Le nom'),
                ),
                AppDropdownField<RoleAmbulancier>(
                  label: 'Rôle',
                  icon: Icons.medical_services_outlined,
                  value: _role,
                  items: [
                    for (final RoleAmbulancier r in RoleAmbulancier.values)
                      DropdownMenuItem(value: r, child: Text(r.libelle)),
                  ],
                  onChanged: (RoleAmbulancier? r) {
                    if (r != null) {
                      setState(() => _role = r);
                    }
                  },
                ),
                AppTextField(
                  controller: _telCtrl,
                  label: 'Téléphone',
                  hint: '+216 22 123 456',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  validator: Validators.telephone,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Section(
              titre: 'Affectation',
              icone: Icons.airport_shuttle_outlined,
              children: [
                AppDropdownField<int?>(
                  label: 'Ambulance',
                  icon: Icons.airport_shuttle,
                  value: _ambulanceId,
                  items: ambulances,
                  onChanged: (int? id) => setState(() => _ambulanceId = id),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Disponible'),
                  subtitle: const Text('Une ambulance sans équipier disponible ne part pas'),
                  value: _disponible,
                  onChanged: (bool v) => setState(() => _disponible = v),
                ),
              ],
            ),
            const SizedBox(height: 20),
            PrimaryButton(
              label: _edition ? 'Enregistrer' : "Ajouter l'ambulancier",
              icon: Icons.save_outlined,
              loading: _enregistrement,
              onPressed: _enregistrer,
            ),
          ],
        ),
      ),
    );
  }
}
