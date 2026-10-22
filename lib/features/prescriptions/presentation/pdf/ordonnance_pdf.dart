import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../../core/utils/formatters.dart';
import '../../domain/authenticite_ordonnance.dart';
import '../../domain/models/ordonnance.dart';
import '../../domain/models/vues_ordonnance.dart';

/// PDF A4 de l'ordonnance — mise en page identique au modèle officiel :
///
///  ┌──────────────────────────────────────────┐
///  │   Nom cabinet centré                     │
///  │   Adresse · Tél · Email · N° Finess      │
///  │                                          │
///  │            Ordonnance                    │
///  │                                          │
///  │ Médecin (gauche) ── Patient + QR (droite)│
///  │                                          │
///  │ 1. Médicament en gras                    │
///  │    posologie en italique                 │
///  │ 2. ...                                   │
///  │                                          │
///  │                       Nom médecin        │
///  │                       [zone signature]   │
///  │                                          │
///  │ [QR bas gauche]  Texte légal             │
///  │ N° e-prescription                        │
///  └──────────────────────────────────────────┘
class OrdonnancePdf {
  OrdonnancePdf._();

  static const PdfColor _noir    = PdfColors.black;
  static final PdfColor _gris    = PdfColor.fromInt(0xFF555555);
  static final PdfColor _grisClair = PdfColor.fromInt(0xFFAAAAAA);

  static Future<Uint8List> generer({
    required OrdonnanceResume resume,
    required List<LigneDetail> lignes,
    Map<String, Object?>? entete,
  }) async {
    final Ordonnance o = resume.ordonnance;
    final Map<String, Object?> e = entete ?? const {};

    String val(String cle) => (e[cle] as String?) ?? '';

    // Âge du patient à partir de la date de naissance
    String age = '';
    final String dnStr = val('p_date_naissance');
    if (dnStr.isNotEmpty) {
      try {
        final DateTime dn = DateTime.parse(dnStr);
        final int a = DateTime.now().year - dn.year;
        age = '$a an(s)';
      } catch (_) {}
    }

    final pw.Document doc = pw.Document(
      title: o.numero,
      author: resume.medecinNom,
    );

    final String qrData = AuthenticiteOrdonnance.contenuQr(o);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 50, vertical: 40),
        build: (pw.Context ctx) => [
          // ── En-tête cabinet centré ──────────────────────────────────
          _enTeteCabinet(resume, val),
          pw.SizedBox(height: 22),

          // ── Titre "Ordonnance" ──────────────────────────────────────
          pw.Center(
            child: pw.Text(
              'Ordonnance',
              style: pw.TextStyle(
                fontSize: 28,
                fontWeight: pw.FontWeight.bold,
                color: _noir,
              ),
            ),
          ),
          pw.SizedBox(height: 22),

          // ── Ligne médecin | patient ─────────────────────────────────
          _ligneActeurs(resume, o, val, age, qrData),
          pw.SizedBox(height: 24),

          // ── Médicaments ─────────────────────────────────────────────
          ...List.generate(lignes.length, (i) => _medicament(lignes[i])),
          pw.SizedBox(height: 40),

          // ── Signature ───────────────────────────────────────────────
          _signature(resume),
          pw.SizedBox(height: 60),

          // ── Bas de page : QR + texte légal ─────────────────────────
          _piedPage(o, qrData),
        ],
      ),
    );

    return doc.save();
  }

  // ═══════════════════════════════════════════════════════════════════════
  // EN-TÊTE CABINET (centré)
  // ═══════════════════════════════════════════════════════════════════════
  static pw.Widget _enTeteCabinet(
    OrdonnanceResume resume,
    String Function(String) val,
  ) {
    final String specialite = val('m_specialite');
    final String telephone  = val('m_telephone');
    final String email      = val('m_email');
    final String matricule  = val('m_matricule');

    // Ligne de contact
    final List<String> contact = [];
    if (telephone.isNotEmpty) contact.add('Téléphone: ${Formatters.telephone(telephone)}');
    if (email.isNotEmpty)     contact.add('Email: $email');
    if (matricule.isNotEmpty) contact.add('Matricule: $matricule');

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        // Nom du cabinet / médecin
        pw.Text(
          resume.medecinNom,
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(
            fontSize: 13,
            fontWeight: pw.FontWeight.bold,
            color: _noir,
          ),
        ),
        if (specialite.isNotEmpty) ...[
          pw.SizedBox(height: 2),
          pw.Text(
            specialite,
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(fontSize: 9, color: _gris),
          ),
        ],
        if (contact.isNotEmpty) ...[
          pw.SizedBox(height: 2),
          pw.Text(
            contact.join(' · '),
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(fontSize: 9, color: _gris),
          ),
        ],
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // LIGNE MÉDECIN | PATIENT
  // ═══════════════════════════════════════════════════════════════════════
  static pw.Widget _ligneActeurs(
    OrdonnanceResume resume,
    Ordonnance o,
    String Function(String) val,
    String age,
    String qrData,
  ) {
    final String cin       = val('p_cin');
    final String dnStr     = val('p_date_naissance');
    final String groupe    = val('p_groupe');
    final String telephone = val('p_telephone');

    String dateNaiss = '';
    if (dnStr.isNotEmpty) {
      try {
        dateNaiss = Formatters.date(DateTime.parse(dnStr));
      } catch (_) {}
    }

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // ── Médecin gauche ─────────────────────────────────────────────
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                resume.medecinNom,
                style: pw.TextStyle(
                    fontSize: 10, fontWeight: pw.FontWeight.bold),
              ),
              if (val('m_specialite').isNotEmpty)
                pw.Text(val('m_specialite'),
                    style: pw.TextStyle(fontSize: 9, color: _gris)),
              if (val('m_telephone').isNotEmpty)
                pw.Text(Formatters.telephone(val('m_telephone')),
                    style: pw.TextStyle(fontSize: 9, color: _gris)),
            ],
          ),
        ),

        // ── Code-barres (N° ordonnance) centre ─────────────────────────
        pw.Column(
          children: [
            pw.BarcodeWidget(
              barcode: pw.Barcode.code128(),
              data: o.numero,
              width: 100,
              height: 32,
              drawText: true,
              textStyle: pw.TextStyle(fontSize: 7, color: _gris),
            ),
          ],
        ),

        pw.SizedBox(width: 16),

        // ── Patient droite ─────────────────────────────────────────────
        pw.Expanded(
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      resume.patientNom,
                      style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold),
                    ),
                    if (cin.isNotEmpty)
                      pw.Text('CIN: $cin',
                          style: pw.TextStyle(
                              fontSize: 9, color: _gris)),
                    if (dateNaiss.isNotEmpty)
                      pw.Text('Date de naissance: $dateNaiss',
                          style: pw.TextStyle(
                              fontSize: 9, color: _gris)),
                    if (age.isNotEmpty || groupe.isNotEmpty)
                      pw.Text(
                        [
                          if (age.isNotEmpty) 'Age: $age',
                          if (groupe.isNotEmpty) 'Groupe: $groupe',
                        ].join('   '),
                        style: pw.TextStyle(
                            fontSize: 9, color: _gris),
                      ),
                    if (telephone.isNotEmpty)
                      pw.Text('Tél: ${Formatters.telephone(telephone)}',
                          style: pw.TextStyle(
                              fontSize: 9, color: _gris)),
                  ],
                ),
              ),
              pw.SizedBox(width: 6),
              // QR code anti-fraude
              pw.BarcodeWidget(
                barcode: pw.Barcode.qrCode(),
                data: qrData,
                width: 52,
                height: 52,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // UN MÉDICAMENT
  // ═══════════════════════════════════════════════════════════════════════
  static pw.Widget _medicament(LigneDetail ligne) {
    final String nom = '${ligne.medicament.libelle} '
        '${ligne.medicament.dosage} '
        '${ligne.medicament.forme}';

    final List<String> extras = [];
    if (ligne.ligne.lienApci) extras.add('APCI 100 %');
    if (!ligne.ligne.substitutionAutorisee) extras.add('Non substituable');
    extras.add('${ligne.ligne.quantiteBoites} boîte(s)');

    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 14),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Nom médicament en gras
          pw.Text(
            nom,
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: _noir,
            ),
          ),
          pw.SizedBox(height: 2),
          // Posologie en italique
          pw.Text(
            ligne.posologie,
            style: pw.TextStyle(
              fontSize: 10,
              fontStyle: pw.FontStyle.italic,
              color: _noir,
            ),
          ),
          // Instructions si présentes
          if ((ligne.ligne.instructions ?? '').isNotEmpty)
            pw.Text(
              ligne.ligne.instructions!,
              style: pw.TextStyle(
                fontSize: 9,
                fontStyle: pw.FontStyle.italic,
                color: _gris,
              ),
            ),
          // Quantité + badges
          pw.SizedBox(height: 2),
          pw.Text(
            extras.join(' · '),
            style: pw.TextStyle(fontSize: 9, color: _grisClair),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // SIGNATURE
  // ═══════════════════════════════════════════════════════════════════════
  static pw.Widget _signature(OrdonnanceResume resume) {
    return pw.Row(
      children: [
        pw.Spacer(),
        pw.SizedBox(
          width: 180,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text(
                resume.medecinNom,
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                    fontSize: 10, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 8),
              // Zone de signature (cadre vide)
              pw.Container(
                height: 55,
                width: 180,
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(
                    color: PdfColor.fromInt(0xFFCCCCCC),
                    width: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // PIED DE PAGE : QR + texte légal + N° e-prescription
  // ═══════════════════════════════════════════════════════════════════════
  static pw.Widget _piedPage(Ordonnance o, String qrData) {
    const String legal =
        'Le patient, le ou les titulaire(s) de l\'autorité parentale a (ont) été informé(s) '
        'et s\'oppose(nt) à la consultation de ce qui a été délivré ou exécuté sur '
        'cette ordonnance par les professionnels qui le prennent en charge.\n\n'
        'Les données de la prescription sont transmises électroniquement à l\'assurance '
        'maladie qui traite vos données dans le cadre de ses missions. Pour en savoir plus '
        'sur la gestion de vos données personnelles et pour exercer vos droits, '
        'contactez votre caisse d\'assurance maladie.';

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // QR bas gauche
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.BarcodeWidget(
              barcode: pw.Barcode.qrCode(),
              data: qrData,
              width: 64,
              height: 64,
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              'e-prescription',
              style: pw.TextStyle(fontSize: 7, color: _gris),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              o.numero,
              style: pw.TextStyle(
                  fontSize: 7,
                  fontWeight: pw.FontWeight.bold,
                  color: _noir),
            ),
          ],
        ),
        pw.SizedBox(width: 12),
        // Texte légal
        pw.Expanded(
          child: pw.Text(
            legal,
            style: pw.TextStyle(fontSize: 7, color: _gris),
          ),
        ),
      ],
    );
  }
}
