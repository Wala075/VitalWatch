import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../domain/models/apci.dart';
import '../../domain/models/contrat_assurance.dart';

/// Données nécessaires pour remplir le formulaire CNAM.
class DonneesFormulaireApci {
  const DonneesFormulaireApci({
    required this.nomPatient,
    required this.prenomPatient,
    required this.dateNaissance,
    required this.cin,
    required this.telephone,
    required this.adresse,
    required this.sexe,
    this.numeroAdherent = '',
    this.filiere,
    this.apci,
    this.medicamentsCouvrerts = const [],
    required this.nomMedecin,
    required this.specialiteMedecin,
    required this.matriculeMedecin,
    required this.telephoneMedecin,
    this.dateFormulaire,
  });

  final String nomPatient;
  final String prenomPatient;
  final String dateNaissance;
  final String cin;
  final String telephone;
  final String adresse;
  final String sexe;
  final String numeroAdherent;
  final FiliereCnam? filiere;
  final Apci? apci;
  final List<String> medicamentsCouvrerts;
  final String nomMedecin;
  final String specialiteMedecin;
  final String matriculeMedecin;
  final String telephoneMedecin;
  final DateTime? dateFormulaire;
}

/// Générateur PDF reproduisant fidèlement le formulaire officiel CNAM tunisien.
class ApciFormulairePdf {
  ApciFormulairePdf._();

  static final PdfColor _vert      = PdfColor.fromInt(0xFF006837);
  static final PdfColor _vertClair = PdfColor.fromInt(0xFFD6EDD8);
  static final PdfColor _gris      = PdfColor.fromInt(0xFF555555);
  static const PdfColor _blanc     = PdfColors.white;
  static const PdfColor _noir      = PdfColors.black;
  static const double   _rowH      = 16;

  static Future<Uint8List> generer(DonneesFormulaireApci d) async {
    final pw.Document doc = pw.Document(
      title: 'Formulaire CNAM — ${d.prenomPatient} ${d.nomPatient}',
      author: 'VitalWatch',
    );

    // Chargement du logo CNAM depuis les assets Flutter.
    pw.MemoryImage? logoCnam;
    try {
      final ByteData data =
          await rootBundle.load('assets/images/cnam_logo.png');
      logoCnam = pw.MemoryImage(data.buffer.asUint8List());
    } catch (_) {
      // Logo absent : on utilisera le rendu textuel de secours.
    }

    final List<String> dn = d.dateNaissance.split('/');
    final String jour  = dn.length == 3 ? dn[0] : '';
    final String mois  = dn.length == 3 ? dn[1] : '';
    final String annee = dn.length == 3 ? dn[2] : '';

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(18),
        build: (pw.Context ctx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              _enTete(logoCnam),
              pw.SizedBox(height: 6),
              _blocAssure(d, jour, mois, annee),
              pw.SizedBox(height: 5),
              _blocSoins(),
              pw.SizedBox(height: 5),
              _blocInferieur(d),
              pw.SizedBox(height: 5),
              _piedPage(),
            ],
          );
        },
      ),
    );

    return doc.save();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // EN-TÊTE
  // ─────────────────────────────────────────────────────────────────────────
  static pw.Widget _enTete(pw.MemoryImage? logo) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        // ── Logo + textes institutionnels (centre) ───────────────────────
        pw.Expanded(
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              // Logo NAM
              if (logo != null)
                pw.Image(logo, width: 70, height: 70)
              else
                _logoTexte(),
              pw.SizedBox(width: 10),
              // Textes à droite du logo
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  pw.Text(
                    'الصندوق الوطني للتأمين على المرض',
                    style: pw.TextStyle(
                        fontSize: 10,
                        color: _vert,
                        fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    'Caisse Nationale d\'Assurance Maladie',
                    style: pw.TextStyle(
                        fontSize: 9,
                        color: _vert,
                        fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    'RÉPUBLIQUE TUNISIENNE',
                    style: pw.TextStyle(
                        fontSize: 8,
                        color: _vert,
                        fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Text(
                    'MINISTÈRE DES AFFAIRES SOCIALES',
                    style: pw.TextStyle(
                        fontSize: 8,
                        color: _vert,
                        fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
        ),
        // ── N° Dossier (droite) ──────────────────────────────────────────
        pw.Container(
          width: 100,
          padding: const pw.EdgeInsets.all(5),
          decoration: pw.BoxDecoration(
              border: pw.Border.all(color: _vert, width: 1)),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('N° Dossier :',
                  style: pw.TextStyle(
                      fontSize: 8,
                      color: _vert,
                      fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 18),
            ],
          ),
        ),
      ],
    );
  }

  /// Logo textuel de secours si l'image n'est pas trouvée.
  static pw.Widget _logoTexte() {
    return pw.Container(
      width: 55, height: 55,
      decoration: pw.BoxDecoration(
        shape: pw.BoxShape.circle,
        border: pw.Border.all(color: _vert, width: 2),
      ),
      alignment: pw.Alignment.center,
      child: pw.Column(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: [
          pw.Container(
            width: 11, height: 11,
            decoration:
                pw.BoxDecoration(shape: pw.BoxShape.circle, color: _vert),
          ),
          pw.SizedBox(height: 1),
          pw.Text('CNAM',
              style: pw.TextStyle(
                  fontSize: 11,
                  color: _vert,
                  fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BLOC ASSURÉ SOCIAL
  // ─────────────────────────────────────────────────────────────────────────
  static pw.Widget _blocAssure(
      DonneesFormulaireApci d, String jour, String mois, String annee) {
    final bool homme = d.sexe == 'M';

    return pw.Container(
      decoration: pw.BoxDecoration(
          border: pw.Border.all(color: _vert, width: 1.5)),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          _bande('A REMPLIR PAR L\'ASSURÉ - À FASSURE SOCIAL'),

          // Ligne 1 : Dénomination | N° immat / N° identification
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                flex: 5,
                child: _pad(
                  bordureDroite: true,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _label('DÉNOMINATION\nDE L\'ASSURÉ SOCIAL'),
                      pw.SizedBox(height: 6),
                    ],
                  ),
                ),
              ),
              pw.Expanded(
                flex: 4,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  children: [
                    _pad(
                      bordureBas: true,
                      child: pw.Row(
                        children: [
                          _label('N° D\'IMMATRICULATION'),
                          pw.SizedBox(width: 4),
                          ..._cases(8),
                        ],
                      ),
                    ),
                    _pad(
                      child: pw.Row(
                        children: [
                          pw.Expanded(
                              child: _label(
                                  'N° D\'IDENTIFICATION\nNATIONALE')),
                          pw.SizedBox(width: 4),
                          ..._cases(8),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // CNSS / CNRPS
          _pad(
            bordureHaut: true, bordureBas: true,
            child: pw.Row(
              children: [
                _labelB('CNSS'),
                pw.SizedBox(width: 4), _boite(),
                pw.SizedBox(width: 14),
                _labelB('CNRPS'),
                pw.SizedBox(width: 4), _boite(),
              ],
            ),
          ),

          // Sous-titre
          pw.Container(
            color: _vertClair,
            padding: const pw.EdgeInsets.symmetric(
                horizontal: 6, vertical: 2),
            child: _labelB('L\'assuré(e) :'),
          ),

          // Nom / Prénom
          pw.Row(
            children: [
              pw.Expanded(
                child: _pad(
                  bordureDroite: true,
                  child: _champ('Nom :', d.nomPatient),
                ),
              ),
              pw.Expanded(
                child: _pad(child: _champ('Prénom :', d.prenomPatient)),
              ),
            ],
          ),

          // Adresse / Code postal / Tél
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                flex: 4,
                child: _pad(
                  bordureDroite: true,
                  child: _champ('Adresse :', d.adresse),
                ),
              ),
              pw.Container(
                width: 68,
                child: _pad(
                  bordureDroite: true,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _label('Code postal'),
                      pw.SizedBox(height: 2),
                      pw.Row(children: _cases(4)),
                    ],
                  ),
                ),
              ),
              pw.Expanded(
                flex: 2,
                child: _pad(child: _champ('N° Tél :', d.telephone)),
              ),
            ],
          ),

          // Profession / N° immatriculation
          pw.Row(
            children: [
              pw.Expanded(
                child: _pad(
                  bordureDroite: true,
                  child: _champ('Profession :', ''),
                ),
              ),
              pw.Expanded(
                child: _pad(
                  child:
                      _champ('N° immatriculation :', d.numeroAdherent),
                ),
              ),
            ],
          ),

          // Date naissance / Sexe
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Container(
                width: 195,
                child: _pad(
                  bordureDroite: true,
                  child: pw.Row(
                    children: [
                      _labelB('Né(e) le :'),
                      pw.SizedBox(width: 6),
                      _dateBox('Jour', jour),
                      pw.SizedBox(width: 3),
                      _dateBox('Mois', mois),
                      pw.SizedBox(width: 3),
                      _dateBox('Année', annee),
                    ],
                  ),
                ),
              ),
              pw.Expanded(
                child: _pad(
                  child: pw.Row(
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        color: _vert,
                        child: pw.Text('Sexe',
                            style: pw.TextStyle(
                                fontSize: 8, color: _blanc,
                                fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.SizedBox(width: 10),
                      _check('Homme', homme),
                      pw.SizedBox(width: 12),
                      _check('Femme', !homme),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Caisse d'affiliation / Gouvernorat
          _pad(
            bordureHaut: true,
            child: pw.Row(
              children: [
                _labelB('Caisse d\'affiliation :'),
                pw.SizedBox(width: 4), _boite(),
                pw.SizedBox(width: 3),
                _label('CNSS'),
                pw.SizedBox(width: 8), _boite(),
                pw.SizedBox(width: 3),
                _label('CNRPS'),
                pw.Spacer(),
                _label('Gouvernorat :'),
                pw.SizedBox(width: 55),
              ],
            ),
          ),

          // N° CIN / Télécopie
          pw.Row(
            children: [
              pw.Expanded(
                child: _pad(
                  bordureDroite: true, bordureHaut: true,
                  child: _champ(
                      'N° de la carte d\'identité nationale :', d.cin),
                ),
              ),
              pw.Expanded(
                child: _pad(
                  bordureHaut: true,
                  child: _champ('Télécopie :', ''),
                ),
              ),
            ],
          ),

          // Contractant
          _pad(
            bordureHaut: true,
            child: pw.Row(
              children: [
                _labelB('Contractant :'),
                pw.SizedBox(width: 6), _boite(),
                pw.SizedBox(width: 3),
                _label('INAM'),
                pw.SizedBox(width: 8), _boite(),
                pw.SizedBox(width: 3),
                _label('UNAM'),
                pw.SizedBox(width: 8), _boite(),
                pw.SizedBox(width: 3),
                _label('CNRPS'),
                pw.SizedBox(width: 10),
                _label('Autre :'),
                pw.Expanded(child: _trait()),
              ],
            ),
          ),

          // PRÉNOM / NOM
          pw.Row(
            children: [
              pw.Expanded(
                child: _pad(
                  bordureDroite: true, bordureHaut: true,
                  child: _champ('PRENOM :', d.prenomPatient),
                ),
              ),
              pw.Expanded(
                child: _pad(
                  bordureHaut: true,
                  child: _champ('NOM :', d.nomPatient),
                ),
              ),
            ],
          ),

          // Date transmission / Signature
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                width: 195,
                child: _pad(
                  bordureDroite: true, bordureHaut: true,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _labelB('DATE D\'AL TRANSMISSION :'),
                      pw.SizedBox(height: 4),
                      pw.Row(
                        children: [
                          _dateBox('Jour', ''),
                          pw.SizedBox(width: 3),
                          _dateBox('Mois', ''),
                          pw.SizedBox(width: 3),
                          _dateBox('Année', ''),
                        ],
                      ),
                      pw.SizedBox(height: 4),
                    ],
                  ),
                ),
              ),
              pw.Expanded(
                child: _pad(
                  bordureHaut: true,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      _labelB('SIGNATURE ET CACHET DE L\'ASSURÉ'),
                      pw.SizedBox(height: 22),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Note bas de section
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(
                horizontal: 8, vertical: 4),
            color: _vertClair,
            child: pw.Text(
              'Veuillez déposer ce formulaire, accompagné de la pièce d\'identité '
              'et de la carte d\'affiliation,\n'
              'auprès de l\'organisme conventionné ou de votre pharmacien.',
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(fontSize: 7, color: _gris),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SOINS DENTAIRES + PROTHÈSES
  // ─────────────────────────────────────────────────────────────────────────
  static pw.Widget _blocSoins() {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          flex: 55,
          child: pw.Container(
            decoration: pw.BoxDecoration(
                border: pw.Border.all(color: _vert, width: 1.5)),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                _bande('CONSULTATIONS ET ACTES DES SOINS DENTAIRES'),
                _enTeteTab([
                  _Tc('DATE', 12),
                  _Tc('ACTE', 12),
                  _Tc('CODE\nCCAM', 12),
                  _Tc('COTATION\nCONVENTIONNELLE', 22),
                  _Tc('CACHET ET SIGNATURE', 42),
                ]),
                for (int i = 0; i < 6; i++)
                  _ligneTab([12, 12, 12, 22, 42], pair: i.isEven),
                _schemaDentaire(),
              ],
            ),
          ),
        ),
        pw.SizedBox(width: 5),
        pw.Expanded(
          flex: 45,
          child: pw.Container(
            decoration: pw.BoxDecoration(
                border: pw.Border.all(color: _vert, width: 1.5)),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                _bande('PROTHÈSES DENTAIRES'),
                _enTeteTab([
                  _Tc('DATE', 15),
                  _Tc('ACTE', 15),
                  _Tc('COTATION\nCONVENTIONNELLE', 30),
                  _Tc('CACHET ET SIGNATURE', 40),
                ]),
                for (int i = 0; i < 10; i++)
                  _ligneTab([15, 15, 30, 40], pair: i.isEven),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // AUTRES SOINS + PHARMACIE
  // ─────────────────────────────────────────────────────────────────────────
  static pw.Widget _blocInferieur(DonneesFormulaireApci d) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: pw.Container(
            decoration: pw.BoxDecoration(
                border: pw.Border.all(color: _vert, width: 1.5)),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                _bande('AUTRES SOINS'),
                _enTeteTab([
                  _Tc('DATE', 15),
                  _Tc('ACTE', 20),
                  _Tc('COTATION\nCONVENTIONNELLE', 25),
                  _Tc('CACHET ET SIGNATURE', 40),
                ]),
                for (int i = 0; i < 5; i++)
                  _ligneTab([15, 20, 25, 40], pair: i.isEven),
              ],
            ),
          ),
        ),
        pw.SizedBox(width: 5),
        pw.Expanded(
          child: pw.Container(
            decoration: pw.BoxDecoration(
                border: pw.Border.all(color: _vert, width: 1.5)),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                _bande('PHARMACIE'),
                _enTeteTab([
                  _Tc('DATE', 15),
                  _Tc('MÉDICAMENTS', 40),
                  _Tc('QUANTITÉ', 15),
                  _Tc('CACHET ET SIGNATURE', 30),
                ]),
                for (int i = 0; i < 6; i++)
                  _lignePharmacie(
                    med: i < d.medicamentsCouvrerts.length
                        ? d.medicamentsCouvrerts[i]
                        : '',
                    pair: i.isEven,
                  ),
                if (d.apci != null)
                  pw.Container(
                    color: _vertClair,
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 5, vertical: 3),
                    child: pw.Text(
                      'APCI ${d.apci!.codeCim10} — ${d.apci!.libelle}  (100 %)',
                      style: pw.TextStyle(
                          fontSize: 7, color: _vert,
                          fontWeight: pw.FontWeight.bold),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PIED DE PAGE
  // ─────────────────────────────────────────────────────────────────────────
  static pw.Widget _piedPage() {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      decoration: pw.BoxDecoration(
          border: pw.Border.all(color: _vert, width: 1),
          color: _vertClair),
      child: pw.Column(
        children: [
          pw.Text(
            'Toute falsification, toute modification ou tout usage frauduleux '
            'de ce document expose son auteur',
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(fontSize: 7, color: _gris),
          ),
          pw.Text(
            'aux sanctions prévues par la législation en vigueur.',
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(fontSize: 7, color: _gris),
          ),
          pw.SizedBox(height: 2),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text('The Tunisian Republic',
                style: pw.TextStyle(
                    fontSize: 7, color: _vert,
                    fontWeight: pw.FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // WIDGETS ATOMIQUES
  // ─────────────────────────────────────────────────────────────────────────

  static pw.Widget _bande(String titre) => pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        color: _vert,
        child: pw.Text(titre,
            style: pw.TextStyle(
                fontSize: 8.5, color: _blanc,
                fontWeight: pw.FontWeight.bold)),
      );

  static pw.Widget _pad({
    required pw.Widget child,
    bool bordureDroite = false,
    bool bordureHaut   = false,
    bool bordureBas    = false,
  }) =>
      pw.Container(
        padding: const pw.EdgeInsets.all(4),
        decoration: pw.BoxDecoration(
          border: pw.Border(
            top: bordureHaut
                ? pw.BorderSide(color: _vert, width: 0.7)
                : pw.BorderSide.none,
            bottom: bordureBas
                ? pw.BorderSide(color: _vert, width: 0.7)
                : pw.BorderSide.none,
            right: bordureDroite
                ? pw.BorderSide(color: _vert, width: 0.7)
                : pw.BorderSide.none,
          ),
        ),
        child: child,
      );

  static pw.Widget _label(String t) => pw.Text(t,
      style: pw.TextStyle(fontSize: 7.5, color: _vert));

  static pw.Widget _labelB(String t) => pw.Text(t,
      style: pw.TextStyle(
          fontSize: 7.5, color: _vert,
          fontWeight: pw.FontWeight.bold));

  static pw.Widget _champ(String label, String val) => pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Text(label,
              style: pw.TextStyle(fontSize: 7.5, color: _vert)),
          pw.SizedBox(width: 3),
          pw.Expanded(
            child: pw.Container(
              padding: const pw.EdgeInsets.only(bottom: 1),
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  bottom:
                      pw.BorderSide(color: PdfColors.grey500, width: 0.5),
                ),
              ),
              child: pw.Text(val,
                  style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      color: _noir)),
            ),
          ),
        ],
      );

  static List<pw.Widget> _cases(int n) => List.generate(
        n,
        (_) => pw.Container(
          width: 13, height: 13,
          margin: const pw.EdgeInsets.only(right: 1.5),
          decoration: pw.BoxDecoration(
              border: pw.Border.all(color: _vert, width: 0.8)),
        ),
      );

  static pw.Widget _boite() => pw.Container(
        width: 13, height: 13,
        decoration: pw.BoxDecoration(
            border: pw.Border.all(color: _vert, width: 0.8)),
      );

  static pw.Widget _check(String label, bool coche) => pw.Row(
        children: [
          pw.Container(
            width: 12, height: 12,
            alignment: pw.Alignment.center,
            decoration: pw.BoxDecoration(
              border:
                  pw.Border.all(color: coche ? _vert : _gris, width: 0.8),
              color: coche ? _vert : _blanc,
            ),
            child: coche
                ? pw.Text('✓',
                    style: pw.TextStyle(
                        fontSize: 9, color: _blanc,
                        fontWeight: pw.FontWeight.bold))
                : null,
          ),
          pw.SizedBox(width: 3),
          pw.Text(label,
              style: pw.TextStyle(fontSize: 8, color: _noir)),
        ],
      );

  static pw.Widget _dateBox(String label, String val) => pw.Column(
        children: [
          pw.Text(label,
              style: pw.TextStyle(fontSize: 6.5, color: _gris)),
          pw.SizedBox(height: 1),
          pw.Container(
            width: label == 'Année' ? 30 : 18,
            height: 14,
            alignment: pw.Alignment.center,
            decoration: pw.BoxDecoration(
                border: pw.Border.all(color: _vert, width: 0.8)),
            child: pw.Text(val,
                style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                    color: _noir)),
          ),
        ],
      );

  static pw.Widget _trait() => pw.Container(
        height: 1,
        margin: const pw.EdgeInsets.only(bottom: 3),
        color: PdfColors.grey400,
      );

  // ─── Tableaux ─────────────────────────────────────────────────────────────

  static pw.Widget _enTeteTab(List<_Tc> cols) => pw.Container(
        color: _vertClair,
        child: pw.Row(
          children: cols.map((c) {
            final bool last = c == cols.last;
            return pw.Expanded(
              flex: c.f,
              child: pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                    horizontal: 2, vertical: 3),
                decoration: pw.BoxDecoration(
                  border: pw.Border(
                    right: last
                        ? pw.BorderSide.none
                        : pw.BorderSide(color: _vert, width: 0.5),
                  ),
                ),
                child: pw.Text(c.l,
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(
                        fontSize: 6.5, color: _vert,
                        fontWeight: pw.FontWeight.bold)),
              ),
            );
          }).toList(),
        ),
      );

  static pw.Widget _ligneTab(List<int> flexs, {required bool pair}) {
    final PdfColor bg =
        pair ? _blanc : PdfColor.fromInt(0xFFF7FBF7);
    return pw.Container(
      height: _rowH, color: bg,
      child: pw.Row(
        children: List.generate(flexs.length, (i) {
          final bool last = i == flexs.length - 1;
          return pw.Expanded(
            flex: flexs[i],
            child: pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border(
                  right: last
                      ? pw.BorderSide.none
                      : pw.BorderSide(color: _vert, width: 0.4),
                  bottom: const pw.BorderSide(
                      color: PdfColors.grey300, width: 0.4),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  static pw.Widget _lignePharmacie(
      {required String med, required bool pair}) {
    final bool rempli = med.isNotEmpty;
    final PdfColor bg = rempli
        ? _vertClair
        : (pair ? _blanc : PdfColor.fromInt(0xFFF7FBF7));
    return pw.Container(
      height: _rowH, color: bg,
      child: pw.Row(
        children: [
          pw.Expanded(
            flex: 15,
            child: pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border(
                  right: pw.BorderSide(color: _vert, width: 0.4),
                  bottom: const pw.BorderSide(
                      color: PdfColors.grey300, width: 0.4),
                ),
              ),
            ),
          ),
          pw.Expanded(
            flex: 40,
            child: pw.Container(
              padding:
                  const pw.EdgeInsets.symmetric(horizontal: 3),
              alignment: pw.Alignment.centerLeft,
              decoration: pw.BoxDecoration(
                border: pw.Border(
                  right: pw.BorderSide(color: _vert, width: 0.4),
                  bottom: const pw.BorderSide(
                      color: PdfColors.grey300, width: 0.4),
                ),
              ),
              child: rempli
                  ? pw.Text(med,
                      style: pw.TextStyle(
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                          color: _noir))
                  : null,
            ),
          ),
          pw.Expanded(
            flex: 15,
            child: pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border(
                  right: pw.BorderSide(color: _vert, width: 0.4),
                  bottom: const pw.BorderSide(
                      color: PdfColors.grey300, width: 0.4),
                ),
              ),
            ),
          ),
          pw.Expanded(
            flex: 30,
            child: pw.Container(
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(
                      color: PdfColors.grey300, width: 0.4),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Schéma dentaire ──────────────────────────────────────────────────────

  static pw.Widget _schemaDentaire() {
    return pw.Container(
      alignment: pw.Alignment.center,
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Column(
        children: [
          pw.Text(
            '18 17 16 15 14 13 12 11  |  21 22 23 24 25 26 27 28',
            style: pw.TextStyle(fontSize: 5.5, color: _gris),
          ),
          pw.SizedBox(height: 2),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: List.generate(
              16,
              (i) => pw.Container(
                width: 10, height: 10,
                margin: const pw.EdgeInsets.symmetric(horizontal: 1),
                alignment: pw.Alignment.center,
                decoration: pw.BoxDecoration(
                  shape: pw.BoxShape.circle,
                  border: pw.Border.all(color: _vert, width: 0.7),
                ),
                child: pw.Text('+',
                    style: pw.TextStyle(fontSize: 7, color: _vert)),
              ),
            ),
          ),
          pw.SizedBox(height: 3),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: List.generate(
              16,
              (i) => pw.Container(
                width: 10, height: 10,
                margin: const pw.EdgeInsets.symmetric(horizontal: 1),
                alignment: pw.Alignment.center,
                decoration: pw.BoxDecoration(
                  shape: pw.BoxShape.circle,
                  border: pw.Border.all(color: _vert, width: 0.7),
                ),
                child: pw.Text('+',
                    style: pw.TextStyle(fontSize: 7, color: _vert)),
              ),
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            '48 47 46 45 44 43 42 41  |  31 32 33 34 35 36 37 38',
            style: pw.TextStyle(fontSize: 5.5, color: _gris),
          ),
          pw.Text('maxillaire / mandibule',
              style: pw.TextStyle(fontSize: 6, color: _gris)),
        ],
      ),
    );
  }
}

/// Colonne de tableau.
class _Tc {
  const _Tc(this.l, this.f);
  final String l;
  final int f;
}
