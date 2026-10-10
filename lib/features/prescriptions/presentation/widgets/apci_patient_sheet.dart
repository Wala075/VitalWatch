import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_dropdown_field.dart';
import '../../../../core/widgets/error_banner.dart';
import '../../data/apci_repository.dart';
import '../../domain/contrat_manager.dart';
import '../../domain/models/apci.dart';
import '../../domain/models/contrat_assurance.dart';
import '../../domain/prescriptions_exception.dart';

/// Le médecin déclare (ou retire) l'APCI de son patient. Elle est portée
/// par le contrat CNAM actif, créé par l'administrateur.
/// Renvoie true si l'APCI a changé.
Future<bool> afficherApciPatient(BuildContext context, {required int patientId}) async {
  final bool? res = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => _ApciPatient(patientId: patientId),
  );
  return res ?? false;
}

class _ApciPatient extends StatefulWidget {
  const _ApciPatient({required this.patientId});

  final int patientId;

  @override
  State<_ApciPatient> createState() => _ApciPatientState();
}

class _ApciPatientState extends State<_ApciPatient> {
  final ContratManager _manager = ContratManager();

  ContratAssurance? _contrat;
  Apci? _actuelle;
  List<Apci> _codes = [];
  String? _code;
  bool _chargement = true;
  bool _occupe = false;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    final ContratAssurance? contrat = await _manager.contratCnamActif(widget.patientId);
    final Apci? actuelle = await _manager.apciDuPatient(widget.patientId);
    final List<Apci> codes = await ApciRepository().lister();
    if (!mounted) {
      return;
    }
    setState(() {
      _contrat = contrat;
      _actuelle = actuelle;
      _codes = codes;
      _code = actuelle?.codeCim10;
      _chargement = false;
    });
  }

  Future<void> _enregistrer(String? code) async {
    if (code == null && _actuelle == null) {
      return;
    }
    setState(() {
      _occupe = true;
      _erreur = null;
    });
    try {
      await _manager.declarerApci(widget.patientId, code);
      if (mounted) {
        Navigator.pop(context, true);
      }
    } on PrescriptionsException catch (e) {
      if (mounted) {
        setState(() {
          _erreur = e.message;
          _occupe = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final Apci? actuelle = _actuelle;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
        child: _chargement
            ? const SizedBox(height: 160, child: Center(child: CircularProgressIndicator()))
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('APCI du patient', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(
                    actuelle == null
                        ? 'Aucune APCI déclarée'
                        : 'Actuelle : ${actuelle.codeCim10} · ${actuelle.libelle}',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  if (_contrat == null)
                    const ErrorBanner(
                      message: "Pas de contrat CNAM actif : l'administrateur doit d'abord l'ajouter "
                          'dans la fiche du patient.',
                    )
                  else ...[
                    AppDropdownField<String>(
                      label: 'Maladie (CIM-10)',
                      icon: Icons.medical_information_outlined,
                      value: _code,
                      items: [
                        for (final Apci a in _codes)
                          DropdownMenuItem<String>(
                            value: a.codeCim10,
                            child: Text('${a.codeCim10} · ${a.libelle}', overflow: TextOverflow.ellipsis),
                          ),
                      ],
                      onChanged: (String? v) => setState(() => _code = v),
                    ),
                    const SizedBox(height: 12),
                    if (_erreur != null) ...[
                      ErrorBanner(message: _erreur!),
                      const SizedBox(height: 12),
                    ],
                    FilledButton.icon(
                      onPressed: _occupe || _code == null || _code == actuelle?.codeCim10
                          ? null
                          : () => _enregistrer(_code),
                      icon: const Icon(Icons.check_rounded),
                      label: Text(actuelle == null ? "Déclarer l'APCI" : "Changer l'APCI"),
                    ),
                    if (actuelle != null)
                      TextButton(
                        onPressed: _occupe ? null : () => _enregistrer(null),
                        child: const Text("Retirer l'APCI", style: TextStyle(color: AppColors.danger)),
                      ),
                  ],
                ],
              ),
      ),
    );
  }
}
