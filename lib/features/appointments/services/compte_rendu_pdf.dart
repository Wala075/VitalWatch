import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../domain/rdv_models.dart';
import '../domain/rdv_regles.dart';

/// Compte-rendu de consultation au format PDF (partage / impression).
class CompteRenduPdf {
  CompteRenduPdf._();

  static const PdfColor _teal = PdfColor.fromInt(0xFF0E7C7B);
  static const PdfColor _gris = PdfColor.fromInt(0xFF6B7774);

  static Future<Uint8List> generer(RdvDetail d, Consultation c) async {
    final RendezVous r = d.rdv;
    final pw.Document doc = pw.Document(
      title: 'Compte-rendu RDV ${r.id}',
      author: d.medecinNom,
    );
    final String? resume = c.resumeIa;

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        header: (pw.Context ctx) => pw.Container(
          padding: const pw.EdgeInsets.only(bottom: 8),
          decoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: _teal, width: 2)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'VitalWatch',
                style: pw.TextStyle(
                  color: _teal,
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                'Compte-rendu de consultation',
                style: const pw.TextStyle(color: _gris),
              ),
            ],
          ),
        ),
        footer: (pw.Context ctx) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Page ${ctx.pageNumber}/${ctx.pagesCount}',
            style: const pw.TextStyle(color: _gris, fontSize: 9),
          ),
        ),
        build: (pw.Context ctx) => [
          pw.SizedBox(height: 12),
          _ligne('Patient', d.patientNom),
          _ligne('Médecin', '${d.medecinNom}${d.specialite == null ? '' : ' (${d.specialite})'}'),
          if (d.serviceNom != null) _ligne('Service', d.serviceNom ?? ''),
          _ligne('Date', RdvFormat.numerique(r.dateHeure)),
          _ligne('Type', r.type.libelle),
          if (c.dureeReelle != null) _ligne('Durée réelle', '${c.dureeReelle} min'),
          _ligne('Motif', r.motif),
          pw.SizedBox(height: 16),
          _titre('Diagnostic'),
          pw.Text(c.diagnostic),
          pw.SizedBox(height: 12),
          _titre('Compte-rendu'),
          pw.Text(c.compteRendu, textAlign: pw.TextAlign.justify),
          if (resume != null && resume.isNotEmpty) ...[
            pw.SizedBox(height: 12),
            _titre('Résumé pour le patient'),
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: const PdfColor.fromInt(0xFFE2F1EC),
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Text(resume),
            ),
          ],
          pw.SizedBox(height: 30),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text('Signature : ${d.medecinNom}'),
          ),
        ],
      ),
    );
    return doc.save();
  }

  static pw.Widget _titre(String t) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 4),
        child: pw.Text(
          t,
          style: pw.TextStyle(
            color: _teal,
            fontSize: 13,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      );

  static pw.Widget _ligne(String libelle, String valeur) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(
              width: 90,
              child: pw.Text(
                libelle,
                style: pw.TextStyle(color: _gris, fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.Expanded(child: pw.Text(valeur)),
          ],
        ),
      );

  /// Ouvre la feuille de partage (WhatsApp, mail, enregistrer...).
  static Future<void> partager(RdvDetail d, Consultation c) async {
    final Uint8List octets = await generer(d, c);
    await Printing.sharePdf(
      bytes: octets,
      filename: 'compte_rendu_rdv_${d.rdv.id}.pdf',
    );
  }

  /// Aperçu avant impression.
  static Future<void> imprimer(RdvDetail d, Consultation c) {
    return Printing.layoutPdf(
      name: 'compte_rendu_rdv_${d.rdv.id}',
      onLayout: (PdfPageFormat format) => generer(d, c),
    );
  }
}
