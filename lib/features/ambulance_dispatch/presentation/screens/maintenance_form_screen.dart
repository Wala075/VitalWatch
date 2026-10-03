import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_dropdown_field.dart';
import '../../../../core/widgets/app_input_decoration.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../core/widgets/error_banner.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../domain/dispatch_manager.dart';
import '../../domain/dispatch_models.dart';
import '../../domain/models/ambulance.dart';
import '../../domain/models/maintenance.dart';
import '../providers/dispatch_controller.dart';
import '../widgets/dispatch_ui.dart';

/// Planifier / enregistrer une maintenance.
/// Date future → planifiée ; aujourd'hui → en cours (ambulance bloquée) ;
/// « Déjà effectuée » → terminée avec le prochain seuil kilométrique.
class MaintenanceFormScreen extends StatefulWidget {
  const MaintenanceFormScreen({super.key, required this.ambulance, this.maintenance});

  final Ambulance ambulance;
  final Maintenance? maintenance;

  @override
  State<MaintenanceFormScreen> createState() => _MaintenanceFormScreenState();
}

class _MaintenanceFormScreenState extends State<MaintenanceFormScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _coutCtrl = TextEditingController();
  final TextEditingController _prochainCtrl = TextEditingController();
  final DispatchManager _manager = DispatchController.instance.manager;

  TypeMaintenance _type = TypeMaintenance.revision;
  DateTime _date = DateTime.now();
  bool _effectuee = false;
  bool _enregistrement = false;
  String? _erreur;

  bool get _edition => widget.maintenance != null;

  @override
  void initState() {
    super.initState();
    final Maintenance? m = widget.maintenance;
    if (m != null) {
      _type = m.type;
      _date = m.date;
      _coutCtrl.text = m.cout.toStringAsFixed(0);
      _effectuee = m.statut == StatutMaintenance.terminee;
      final int? prochain = m.prochainEntretienKm;
      _prochainCtrl.text = prochain == null ? '' : '$prochain';
    } else {
      _coutCtrl.text = '0';
    }
    if (_prochainCtrl.text.isEmpty) {
      _proposerSeuil();
    }
  }

  void _proposerSeuil() {
    _prochainCtrl.text = '${widget.ambulance.kilometrage + _type.intervalleKm}';
  }

  @override
  void dispose() {
    _coutCtrl.dispose();
    _prochainCtrl.dispose();
    super.dispose();
  }

  Future<void> _choisirDate() async {
    final DateTime maintenant = DateTime.now();
    final DateTime debut = maintenant.subtract(const Duration(days: 365));
    final DateTime fin = maintenant.add(const Duration(days: 365));
    DateTime initiale = _date;
    if (initiale.isBefore(debut)) {
      initiale = debut;
    } else if (initiale.isAfter(fin)) {
      initiale = fin;
    }
    final DateTime? d = await showDatePicker(
      context: context,
      initialDate: initiale,
      firstDate: debut,
      lastDate: fin,
    );
    if (d != null) {
      setState(() => _date = d);
    }
  }

  String get _statutPrevu {
    if (_effectuee) {
      return 'Terminée : le seuil kilométrique est mis à jour';
    }
    final DateTime aujourdhui = DateTime.now();
    final DateTime jour = DateTime(_date.year, _date.month, _date.day);
    if (jour.isAfter(DateTime(aujourdhui.year, aujourdhui.month, aujourdhui.day))) {
      return "Planifiée : l'ambulance sera bloquée automatiquement le ${Formatters.date(_date)}";
    }
    return "En cours : l'ambulance est bloquée dès l'enregistrement";
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
      final String prochain = _prochainCtrl.text.trim();
      await _manager.enregistrerMaintenance(Maintenance(
        id: widget.maintenance?.id,
        ambulanceId: widget.ambulance.id ?? 0,
        type: _type,
        date: _date,
        cout: double.parse(_coutCtrl.text.trim().replaceAll(',', '.')),
        prochainEntretienKm: prochain.isEmpty ? null : int.parse(prochain),
        statut: _effectuee ? StatutMaintenance.terminee : StatutMaintenance.planifiee,
      ));
      await DispatchController.instance.rafraichir();
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
    final int? id = widget.maintenance?.id;
    if (id == null) {
      return;
    }
    final bool ok = await showConfirmDialog(
      context,
      titre: 'Supprimer la maintenance',
      message: 'Cette maintenance sera supprimée. Le blocage éventuel de '
          "l'ambulance est recalculé.",
      confirmer: 'Supprimer',
      danger: true,
    );
    if (!ok) {
      return;
    }
    await _manager.supprimerMaintenance(id);
    await DispatchController.instance.rafraichir();
    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  String? _validerCout(String? v) {
    final double? c = double.tryParse((v ?? '').trim().replaceAll(',', '.'));
    if (c == null) {
      return 'Coût invalide';
    }
    if (c < 0) {
      return 'Le coût ne peut pas être négatif';
    }
    return null;
  }

  String? _validerProchain(String? v) {
    final String t = (v ?? '').trim();
    if (t.isEmpty) {
      return _effectuee ? 'Obligatoire pour une maintenance effectuée' : null;
    }
    final int? km = int.tryParse(t);
    if (km == null) {
      return 'Nombre invalide';
    }
    if (km <= widget.ambulance.kilometrage) {
      return 'Doit dépasser ${widget.ambulance.kilometrage} km';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final String? erreur = _erreur;

    return Scaffold(
      appBar: AppBar(
        title: Text(_edition ? 'Modifier la maintenance' : 'Nouvelle maintenance'),
        actions: [
          if (_edition)
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
              titre: widget.ambulance.immatriculation,
              icone: Icons.build_circle_outlined,
              children: [
                Info(
                  icone: Icons.speed,
                  texte: 'Compteur : ${DispatchUi.kilometrage(widget.ambulance.kilometrage)}',
                ),
                AppDropdownField<TypeMaintenance>(
                  label: "Type d'entretien",
                  icon: Icons.handyman_outlined,
                  value: _type,
                  items: [
                    for (final TypeMaintenance t in TypeMaintenance.values)
                      DropdownMenuItem(
                        value: t,
                        child: Text('${t.libelle} (tous les ${DispatchUi.kilometrage(t.intervalleKm)})'),
                      ),
                  ],
                  onChanged: (TypeMaintenance? t) {
                    if (t != null) {
                      setState(() {
                        _type = t;
                        _proposerSeuil();
                      });
                    }
                  },
                ),
                InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: _choisirDate,
                  child: InputDecorator(
                    decoration: AppInputDecoration.build(
                      context,
                      label: 'Date',
                      icon: Icons.event_outlined,
                    ),
                    child: Text(Formatters.date(_date)),
                  ),
                ),
                AppTextField(
                  controller: _coutCtrl,
                  label: 'Coût (DT)',
                  icon: Icons.payments_outlined,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: _validerCout,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Déjà effectuée'),
                  subtitle: const Text('Enregistre un entretien terminé'),
                  value: _effectuee,
                  onChanged: (bool v) => setState(() => _effectuee = v),
                ),
                AppTextField(
                  controller: _prochainCtrl,
                  label: 'Prochain entretien à (km)',
                  icon: Icons.flag_outlined,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: _validerProchain,
                ),
                Info(icone: Icons.info_outline, texte: _statutPrevu),
              ],
            ),
            const SizedBox(height: 20),
            PrimaryButton(
              label: 'Enregistrer',
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

/// Clôture d'une maintenance : coût réel + prochain seuil.
Future<bool> showTerminerMaintenanceDialog(
  BuildContext context, {
  required Ambulance ambulance,
  required Maintenance maintenance,
}) async {
  final TextEditingController coutCtrl =
      TextEditingController(text: maintenance.cout.toStringAsFixed(0));
  final TextEditingController kmCtrl = TextEditingController(
    text: '${ambulance.kilometrage + maintenance.type.intervalleKm}',
  );
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  String? erreur;

  final bool? ok = await showDialog<bool>(
    context: context,
    builder: (BuildContext ctx) {
      return StatefulBuilder(
        builder: (BuildContext ctx, StateSetter setLocal) {
          final String? e = erreur;
          return AlertDialog(
            title: Text('Terminer : ${maintenance.type.libelle}'),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (e != null) ...[
                    ErrorBanner(message: e),
                    const SizedBox(height: 10),
                  ],
                  AppTextField(
                    controller: coutCtrl,
                    label: 'Coût réel (DT)',
                    icon: Icons.payments_outlined,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (String? v) {
                      final double? c = double.tryParse((v ?? '').replaceAll(',', '.'));
                      return c == null || c < 0 ? 'Coût invalide' : null;
                    },
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    controller: kmCtrl,
                    label: 'Prochain entretien à (km)',
                    icon: Icons.flag_outlined,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (String? v) {
                      final int? km = int.tryParse(v ?? '');
                      if (km == null || km <= ambulance.kilometrage) {
                        return 'Doit dépasser ${ambulance.kilometrage} km';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Annuler'),
              ),
              FilledButton(
                onPressed: () async {
                  if (!formKey.currentState!.validate()) {
                    return;
                  }
                  try {
                    await DispatchController.instance.manager.terminerMaintenance(
                      maintenance,
                      cout: double.parse(coutCtrl.text.replaceAll(',', '.')),
                      prochainEntretienKm: int.parse(kmCtrl.text),
                    );
                    if (ctx.mounted) {
                      Navigator.pop(ctx, true);
                    }
                  } on DispatchException catch (ex) {
                    setLocal(() => erreur = ex.message);
                  }
                },
                child: const Text('Terminer'),
              ),
            ],
          );
        },
      );
    },
  );
  coutCtrl.dispose();
  kmCtrl.dispose();
  if (ok == true) {
    await DispatchController.instance.rafraichir();
  }
  return ok == true;
}
