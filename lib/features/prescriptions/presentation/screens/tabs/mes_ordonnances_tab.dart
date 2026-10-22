import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/empty_state.dart';
import '../../../data/ordonnance_repository.dart';
import '../../../domain/models/ordonnance.dart';
import '../../../domain/models/vues_ordonnance.dart';
import '../../../domain/ordonnance_manager.dart';
import '../../widgets/elements_ui.dart';
import '../ordonnance_detail_screen.dart';
import '../ordonnance_pdf_screen.dart';
import '../../../presentation/pdf/ordonnance_pdf.dart';
import 'ordonnances_tab.dart';

/// Patient : ses ordonnances avec bouton PDF direct sur chaque carte.
class MesOrdonnancesTab extends StatefulWidget {
  const MesOrdonnancesTab({super.key, required this.patientId});

  final int patientId;

  @override
  State<MesOrdonnancesTab> createState() => _MesOrdonnancesTabState();
}

class _MesOrdonnancesTabState extends State<MesOrdonnancesTab> {
  final OrdonnanceRepository _repo = OrdonnanceRepository();
  final OrdonnanceManager _manager = OrdonnanceManager();

  List<OrdonnanceResume> _liste = [];
  bool _chargement = true;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    final List<OrdonnanceResume> res =
        await _repo.listerResumes(patientId: widget.patientId);
    final List<OrdonnanceResume> visibles = [];
    for (final OrdonnanceResume r in res) {
      if (r.ordonnance.statut != StatutOrdonnance.brouillon) {
        visibles.add(r);
      }
    }
    if (!mounted) return;
    setState(() {
      _liste = visibles;
      _chargement = false;
    });
  }

  Future<void> _ouvrir(int id) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => OrdonnanceDetailScreen(
            ordonnanceId: id, lectureSeule: true, modePatient: true),
      ),
    );
    _charger();
  }

  /// Ouvre directement l'aperçu PDF sans passer par la fiche.
  Future<void> _ouvrirPdf(OrdonnanceResume resume) async {
    // Affiche un indicateur le temps de charger les données PDF
    if (!mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final List<LigneDetail> lignes =
          await _manager.lignesDetaillees(resume.ordonnance.id!);
      final Map<String, Object?>? entete =
          await _repo.entete(resume.ordonnance.id!);

      if (!mounted) return;
      Navigator.pop(context); // ferme l'indicateur

      await Navigator.push<void>(
        context,
        MaterialPageRoute<void>(
          builder: (_) => _PdfDirectScreen(
            resume: resume,
            lignes: lignes,
            entete: entete,
          ),
        ),
      );
    } catch (_) {
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          const EnTetePage(
              surtitre: 'Mon traitement', titre: 'Mes ordonnances'),
          Expanded(
            child: _chargement
                ? const Center(child: CircularProgressIndicator())
                : _liste.isEmpty
                    ? const EmptyState(
                        icon: Icons.description_outlined,
                        message: 'Aucune ordonnance')
                    : RefreshIndicator(
                        onRefresh: _charger,
                        child: ListView.separated(
                          padding:
                              const EdgeInsets.fromLTRB(20, 4, 20, 120),
                          itemCount: _liste.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (BuildContext context, int i) {
                            final OrdonnanceResume r = _liste[i];
                            return _CarteOrdonnancePatient(
                              resume: r,
                              onTap: () => _ouvrir(r.ordonnance.id!),
                              onPdf: () => _ouvrirPdf(r),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Carte ordonnance avec bouton PDF intégré
// ─────────────────────────────────────────────────────────────────────────────

class _CarteOrdonnancePatient extends StatelessWidget {
  const _CarteOrdonnancePatient({
    required this.resume,
    required this.onTap,
    required this.onPdf,
  });

  final OrdonnanceResume resume;
  final VoidCallback onTap;
  final VoidCallback onPdf;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Carte ordonnance existante (réutilise le widget CarteOrdonnance)
          InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          resume.ordonnance.numero,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      StyleStatut.badge(resume.ordonnance.statut),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    resume.medecinNom,
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Émise le ${_fmt(resume.ordonnance.dateEmission)} · '
                    '${resume.nbLignes} médicament${resume.nbLignes > 1 ? 's' : ''}',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ),
          // Séparateur + bouton PDF
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                // Voir la fiche
                TextButton.icon(
                  onPressed: onTap,
                  icon: const Icon(Icons.visibility_outlined, size: 16),
                  label: const Text('Voir la fiche'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                ),
                const Spacer(),
                // Télécharger PDF
                FilledButton.icon(
                  onPressed: onPdf,
                  icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
                  label: const Text('Télécharger PDF'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

// ─────────────────────────────────────────────────────────────────────────────
// Aperçu PDF direct (sans passer par la fiche)
// ─────────────────────────────────────────────────────────────────────────────

class _PdfDirectScreen extends StatelessWidget {
  const _PdfDirectScreen({
    required this.resume,
    required this.lignes,
    required this.entete,
  });

  final OrdonnanceResume resume;
  final List<LigneDetail> lignes;
  final Map<String, Object?>? entete;

  @override
  Widget build(BuildContext context) {
    final String nomFichier =
        '${resume.ordonnance.numero}_${resume.patientNom.replaceAll(' ', '_')}.pdf';

    return Scaffold(
      appBar: AppBar(
        title: Text(resume.ordonnance.numero),
        actions: [
          IconButton(
            tooltip: 'QR code',
            icon: const Icon(Icons.qr_code_2_rounded),
            onPressed: () => Navigator.pushReplacement<void, void>(
              context,
              MaterialPageRoute<void>(
                builder: (_) => OrdonnancePdfScreen(
                    ordonnanceId: resume.ordonnance.id!),
              ),
            ),
          ),
        ],
      ),
      body: PdfPreview(
        build: (PdfPageFormat format) => OrdonnancePdf.generer(
          resume: resume,
          lignes: lignes,
          entete: entete,
        ),
        canChangePageFormat: false,
        canChangeOrientation: false,
        canDebug: false,
        pdfFileName: nomFichier,
        initialPageFormat: PdfPageFormat.a4,
      ),
    );
  }
}
