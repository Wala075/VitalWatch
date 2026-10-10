import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/error_banner.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../domain/delivrance_manager.dart';
import '../../domain/formats_prescriptions.dart';
import '../../domain/models/ordonnance.dart';
import '../../domain/models/vues_ordonnance.dart';
import '../../domain/prescriptions_exception.dart';
import '../widgets/elements_ui.dart';
import '../widgets/substitution_sheet.dart';

/// Délivrance d'une ordonnance contrôlée : boîtes délivrées maintenant,
/// ligne par ligne (délivrance partielle possible).
class DelivranceScreen extends StatefulWidget {
  const DelivranceScreen({super.key, required this.ordonnance});

  final OrdonnanceADelivrer ordonnance;

  @override
  State<DelivranceScreen> createState() => _DelivranceScreenState();
}

class _DelivranceScreenState extends State<DelivranceScreen> {
  final DelivranceManager _manager = DelivranceManager();

  /// Ligne id → boîtes délivrées maintenant (par défaut : tout le reste).
  final Map<int, int> _boites = {};
  bool _enregistrement = false;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    for (final LigneDetail d in widget.ordonnance.lignes) {
      _boites[d.ligne.id!] = d.ligne.resteADelivrer;
    }
  }

  Future<void> _delivrer() async {
    setState(() {
      _enregistrement = true;
      _erreur = null;
    });
    try {
      final StatutOrdonnance statut =
          await _manager.delivrer(widget.ordonnance.resume.ordonnance.id!, _boites);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Délivrance enregistrée · ${statut.libelle.toLowerCase()}')),
      );
      Navigator.pop(context);
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

  @override
  Widget build(BuildContext context) {
    final OrdonnanceADelivrer od = widget.ordonnance;
    final Ordonnance o = od.resume.ordonnance;
    final String? refus = od.refus;

    return Scaffold(
      appBar: AppBar(title: Text(o.numero)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          od.resume.patientNom,
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                        ),
                      ),
                      StyleStatut.badge(o.statut),
                    ],
                  ),
                  Text(od.resume.medecinNom, style: const TextStyle(color: AppColors.textSecondary)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 16,
                    runSpacing: 6,
                    children: [
                      InfoLigne(icon: Icons.event_outlined, texte: 'Émise le ${Formatters.date(o.dateEmission)}'),
                      InfoLigne(
                        icon: Icons.event_available_outlined,
                        texte: "Valable jusqu'au ${Formatters.date(o.dateExpiration)}",
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(
                        od.signatureValide ? Icons.verified_user_rounded : Icons.gpp_bad_rounded,
                        color: od.signatureValide ? AppColors.success : AppColors.danger,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          od.signatureValide
                              ? 'Signature vérifiée : ordonnance authentique'
                              : 'Ordonnance modifiée : la signature ne correspond pas',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: od.signatureValide ? AppColors.success : AppColors.danger,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (refus != null) ...[
            ErrorBanner(message: refus),
            const SizedBox(height: 12),
          ],
          for (final LigneDetail d in od.lignes)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _LigneDelivrance(
                detail: d,
                boites: _boites[d.ligne.id] ?? 0,
                actif: refus == null && !_enregistrement,
                onChange: (int n) => setState(() => _boites[d.ligne.id!] = n),
              ),
            ),
          if (_erreur != null) ...[
            ErrorBanner(message: _erreur!),
            const SizedBox(height: 12),
          ],
          if (refus == null)
            PrimaryButton(
              label: 'Enregistrer la délivrance',
              icon: Icons.inventory_rounded,
              loading: _enregistrement,
              onPressed: _delivrer,
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _LigneDelivrance extends StatelessWidget {
  const _LigneDelivrance({
    required this.detail,
    required this.boites,
    required this.actif,
    required this.onChange,
  });

  final LigneDetail detail;
  final int boites;
  final bool actif;
  final ValueChanged<int> onChange;

  @override
  Widget build(BuildContext context) {
    final int reste = detail.ligne.resteADelivrer;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              detail.medicament.libelle,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(detail.posologie, style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    reste == 0
                        ? 'Déjà délivré (${detail.ligne.quantiteBoites} boîte(s))'
                        : 'Délivré ${detail.ligne.quantiteDelivree}/${detail.ligne.quantiteBoites} · '
                            '${FormatsPrescriptions.dt(detail.medicament.prixPublic)} la boîte',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                if (reste > 0) ...[
                  IconButton(
                    tooltip: 'Moins',
                    onPressed: actif && boites > 0 ? () => onChange(boites - 1) : null,
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                  Text('$boites', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  IconButton(
                    tooltip: 'Plus',
                    onPressed: actif && boites < reste ? () => onChange(boites + 1) : null,
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                ],
              ],
            ),
            if (detail.ligne.substitutionAutorisee && reste > 0)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => afficherSubstitution(
                    context,
                    medicament: detail.medicament,
                    boites: reste,
                  ),
                  icon: const Icon(Icons.recycling_rounded, size: 18),
                  label: const Text('Génériques moins chers'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
