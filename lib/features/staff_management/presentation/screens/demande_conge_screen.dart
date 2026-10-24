import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_dropdown_field.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/error_banner.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../models/utilisateur.dart';
import '../../domain/conge_manager.dart';
import '../../domain/conges.dart';
import '../../domain/staff_models.dart';
import '../widgets/form_section.dart';
import '../widgets/info_compte.dart';

/// Nouvelle demande de congé (médecin ou infirmier, pour lui-même).
/// Renvoie true si la demande a été envoyée.
class DemandeCongeScreen extends StatefulWidget {
  const DemandeCongeScreen({
    super.key,
    required this.role,
    required this.demandeurId,
    required this.solde,
  });

  final Role role;
  final int demandeurId;

  /// Jours de congé annuel restants cette année.
  final int solde;

  @override
  State<DemandeCongeScreen> createState() => _DemandeCongeScreenState();
}

class _DemandeCongeScreenState extends State<DemandeCongeScreen> {
  final TextEditingController _motifCtrl = TextEditingController();

  TypeConge _type = TypeConge.annuel;
  DateTimeRange? _periode;
  bool _envoi = false;
  String? _erreur;

  @override
  void dispose() {
    _motifCtrl.dispose();
    super.dispose();
  }

  Future<void> _choisirPeriode() async {
    final DateTime aujourdHui = DateTime.now();
    final DateTime premier = DateTime(aujourdHui.year, aujourdHui.month, aujourdHui.day);
    final DateTimeRange? p = await showDateRangePicker(
      context: context,
      firstDate: premier,
      lastDate: premier.add(const Duration(days: 365)),
      initialDateRange: _periode,
      helpText: 'Période du congé',
      saveText: 'OK',
    );
    if (p == null || !mounted) return;
    setState(() {
      _periode = p;
      _erreur = null;
    });
  }

  Future<void> _envoyer() async {
    FocusScope.of(context).unfocus();
    final DateTimeRange? p = _periode;
    if (p == null) {
      setState(() => _erreur = 'Choisissez les dates du congé');
      return;
    }
    setState(() {
      _envoi = true;
      _erreur = null;
    });
    try {
      await CongeManager().demander(Conge(
        role: widget.role,
        demandeurId: widget.demandeurId,
        debut: p.start,
        fin: p.end,
        type: _type,
        motif: _motifCtrl.text,
      ));
      if (!mounted) return;
      Navigator.pop(context, true);
    } on StaffException catch (e) {
      if (!mounted) return;
      setState(() => _erreur = e.message);
    } finally {
      if (mounted) setState(() => _envoi = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final DateTimeRange? p = _periode;
    final int jours = p == null ? 0 : RegleConges.nbJours(p.start, p.end);
    final bool depasse = _type == TypeConge.annuel && jours > widget.solde;
    final String? erreur = _erreur;

    return Scaffold(
      appBar: AppBar(title: const Text('Demande de congé')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FormSection(
            titre: 'Congé',
            icon: Icons.event_note_outlined,
            children: [
              AppDropdownField<TypeConge>(
                label: 'Type',
                icon: Icons.category_outlined,
                value: _type,
                items: [
                  for (final TypeConge t in TypeConge.values)
                    DropdownMenuItem<TypeConge>(value: t, child: Text(t.libelle)),
                ],
                onChanged: (TypeConge? t) {
                  if (t != null) setState(() => _type = t);
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.date_range_rounded, color: AppColors.primary),
                title: Text(
                  p == null
                      ? 'Choisir les dates'
                      : 'Du ${Formatters.date(p.start)} au ${Formatters.date(p.end)}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: p == null ? null : Text('$jours jour(s)'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: _choisirPeriode,
              ),
              AppTextField(
                controller: _motifCtrl,
                label: _type == TypeConge.exceptionnel ? 'Motif (obligatoire)' : 'Motif',
                icon: Icons.notes_outlined,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_type == TypeConge.annuel)
            EncadreInfo(
              icon: depasse ? Icons.warning_amber_rounded : Icons.beach_access_outlined,
              couleur: depasse ? AppColors.danger : AppColors.primary,
              texte: depasse
                  ? 'Solde insuffisant : ${widget.solde} jour(s) restant(s) cette année.'
                  : 'Solde de congé annuel : ${widget.solde} jour(s) restant(s) cette année.',
            ),
          const SizedBox(height: 8),
          const EncadreInfo(
            icon: Icons.groups_outlined,
            texte: 'La demande est refusée automatiquement si votre service se '
                'retrouve sans collègue présent pendant votre absence.',
          ),
          const SizedBox(height: 16),
          if (erreur != null) ...[
            ErrorBanner(message: erreur),
            const SizedBox(height: 16),
          ],
          PrimaryButton(
            label: 'Envoyer la demande',
            icon: Icons.send_rounded,
            loading: _envoi,
            onPressed: _envoyer,
          ),
        ],
      ),
    );
  }
}
