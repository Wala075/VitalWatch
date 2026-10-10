import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/ordonnance_repository.dart';
import '../../domain/authenticite_ordonnance.dart';
import '../../domain/models/vues_ordonnance.dart';
import '../../domain/ordonnance_manager.dart';
import '../pdf/ordonnance_pdf.dart';

/// QR code de l'ordonnance (à montrer au pharmacien) et PDF imprimable.
class OrdonnancePdfScreen extends StatefulWidget {
  const OrdonnancePdfScreen({super.key, required this.ordonnanceId});

  final int ordonnanceId;

  @override
  State<OrdonnancePdfScreen> createState() => _OrdonnancePdfScreenState();
}

class _OrdonnancePdfScreenState extends State<OrdonnancePdfScreen> {
  final OrdonnanceRepository _repo = OrdonnanceRepository();
  final OrdonnanceManager _manager = OrdonnanceManager();

  OrdonnanceResume? _resume;
  List<LigneDetail> _lignes = [];
  Map<String, Object?>? _entete;
  bool _pdf = false;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    final OrdonnanceResume? r = await _repo.resume(widget.ordonnanceId);
    final List<LigneDetail> lignes = await _manager.lignesDetaillees(widget.ordonnanceId);
    final Map<String, Object?>? entete = await _repo.entete(widget.ordonnanceId);
    if (!mounted) {
      return;
    }
    setState(() {
      _resume = r;
      _lignes = lignes;
      _entete = entete;
    });
  }

  @override
  Widget build(BuildContext context) {
    final OrdonnanceResume? r = _resume;
    if (r == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(r.ordonnance.numero),
        actions: [
          IconButton(
            tooltip: _pdf ? 'QR code' : 'PDF',
            onPressed: () => setState(() => _pdf = !_pdf),
            icon: Icon(_pdf ? Icons.qr_code_2_rounded : Icons.picture_as_pdf_rounded),
          ),
        ],
      ),
      body: _pdf
          ? PdfPreview(
              build: (PdfPageFormat format) => OrdonnancePdf.generer(
                resume: r,
                lignes: _lignes,
                entete: _entete,
              ),
              canChangePageFormat: false,
              canChangeOrientation: false,
              canDebug: false,
              pdfFileName: '${r.ordonnance.numero}.pdf',
            )
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  r.patientNom,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
                Text(
                  r.medecinNom,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 24),
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: QrImageView(
                      data: AuthenticiteOrdonnance.contenuQr(r.ordonnance),
                      size: 240,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  r.ordonnance.hashSignature == null
                      ? 'Brouillon : pas encore signé par le médecin'
                      : 'À présenter au pharmacien : le QR code contient le numéro et la '
                          'signature SHA-256 de l’ordonnance.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () => setState(() => _pdf = true),
                  icon: const Icon(Icons.picture_as_pdf_rounded),
                  label: const Text('Voir, imprimer ou partager le PDF'),
                ),
              ],
            ),
    );
  }
}
