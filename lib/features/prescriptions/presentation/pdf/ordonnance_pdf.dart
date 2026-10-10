import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../../core/utils/formatters.dart';
import '../../domain/authenticite_ordonnance.dart';
import '../../domain/models/ordonnance.dart';
import '../../domain/models/vues_ordonnance.dart';

/// PDF A4 de l'ordonnance, avec le QR code anti-fraude (numéro + hash).
class OrdonnancePdf {
  OrdonnancePdf._();

  static final PdfColor _teal = PdfColor.fromInt(0xFF0E7C7B);
  static final PdfColor _gris = PdfColor.fromInt(0xFF6B7774);

  static Future<Uint8List> generer({
    required OrdonnanceResume resume,
    required List<LigneDetail> lignes,
    Map<String, Object?>? entete,
  }) async {
    final Ordonnance o = resume.ordonnance;
    final Map<String, Object?> e = entete ?? const {};
    final pw.Document doc = pw.Document(title: o.numero, author: 'VitalWatch');

    String texte(String cle) => (e[cle] as String?) ?? '';

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (pw.Context context) => [
          // En-tête : médecin à gauche, QR code à droite.
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'VitalWatch',
                      style: pw.TextStyle(fontSize: 12, color: _teal, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      resume.medecinNom,
                      style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
                    ),
                    if (texte('m_specialite').isNotEmpty) pw.Text(texte('m_specialite')),
                    if (texte('m_matricule').isNotEmpty)
                      pw.Text('Matricule ${texte('m_matricule')}', style: pw.TextStyle(color: _gris)),
                    if (texte('m_telephone').isNotEmpty)
                      pw.Text(Formatters.telephone(texte('m_telephone')), style: pw.TextStyle(color: _gris)),
                  ],
                ),
              ),
              pw.Column(
                children: [
                  pw.BarcodeWidget(
                    barcode: pw.Barcode.qrCode(),
                    data: AuthenticiteOrdonnance.contenuQr(o),
                    width: 96,
                    height: 96,
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(o.numero, style: const pw.TextStyle(fontSize: 9)),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Divider(color: _teal, thickness: 2),
          pw.SizedBox(height: 12),

          // Patient et dates.
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Patient', style: pw.TextStyle(color: _gris, fontSize: 10)),
                    pw.Text(resume.patientNom, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                    if (texte('p_cin').isNotEmpty) pw.Text('CIN ${texte('p_cin')}'),
                    if (texte('p_date_naissance').isNotEmpty)
                      pw.Text('Né(e) le ${Formatters.date(DateTime.parse(texte('p_date_naissance')))}'),
                  ],
                ),
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('Fait le ${Formatters.date(o.dateEmission)}'),
                  pw.Text(
                    "Valable jusqu'au ${Formatters.date(o.dateExpiration)}",
                    style: pw.TextStyle(color: _gris),
                  ),
                  pw.Text(
                    o.nbRenouvellements == 0
                        ? 'Non renouvelable'
                        : 'A renouveler ${o.nbRenouvellements} fois',
                    style: pw.TextStyle(color: _gris),
                  ),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 24),

          // Médicaments.
          for (int i = 0; i < lignes.length; i++)
            pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 12),
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
              ),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.SizedBox(
                    width: 22,
                    child: pw.Text(
                      '${i + 1}.',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: _teal),
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          '${lignes[i].medicament.libelle} (${lignes[i].medicament.dci})',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(lignes[i].posologie),
                        if ((lignes[i].ligne.instructions ?? '').isNotEmpty)
                          pw.Text(
                            lignes[i].ligne.instructions!,
                            style: pw.TextStyle(fontStyle: pw.FontStyle.italic, color: _gris),
                          ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          '${lignes[i].ligne.quantiteBoites} boite(s)'
                          '${lignes[i].ligne.lienApci ? ' - APCI 100 %' : ''}'
                          '${lignes[i].ligne.substitutionAutorisee ? '' : ' - non substituable'}',
                          style: pw.TextStyle(color: _gris, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          pw.SizedBox(height: 24),

          // Signature électronique.
          pw.Text('Signature électronique (SHA-256)', style: pw.TextStyle(color: _gris, fontSize: 9)),
          pw.Text(o.hashSignature ?? 'non signée (brouillon)', style: const pw.TextStyle(fontSize: 8)),
          pw.SizedBox(height: 4),
          pw.Text(
            'Le pharmacien scanne le QR code : si le contenu ne correspond plus, '
            "l'ordonnance est refusée.",
            style: pw.TextStyle(color: _gris, fontSize: 9),
          ),
        ],
      ),
    );
    return doc.save();
  }
}
