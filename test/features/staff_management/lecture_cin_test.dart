import 'package:flutter_test/flutter_test.dart';

import 'package:projet/features/staff_management/domain/lecture_cin.dart';

void main() {
  final DateTime aujourdHui = DateTime(2026, 10, 22);

  test('CIN tunisienne : numéro à 8 chiffres', () {
    // Le texte arabe n'est pas lu par ML Kit : il reste des chiffres épars.
    const String texte = 'REPUBLIQUE TUNISIENNE\n09876543\n1990 14\n09876543';
    final ResultatScan r = LectureCin.analyser(texte, aujourdHui: aujourdHui);
    expect(r.cin, '09876543');
    expect(r.nom, isNull);
  });

  test('Lettre O lue à la place du zéro', () {
    final ResultatScan r = LectureCin.analyser('N° O9876543', aujourdHui: aujourdHui);
    expect(r.cin, '09876543');
  });

  test('Les suites de plus de 8 chiffres sont ignorées', () {
    final ResultatScan r = LectureCin.analyser('123456789012', aujourdHui: aujourdHui);
    expect(r.cin, isNull);
    expect(r.vide, isTrue);
  });

  test('Date de naissance : formats numérique et en lettres', () {
    expect(
      LectureCin.analyser('Né le 14/05/1990', aujourdHui: aujourdHui).dateNaissance,
      DateTime(1990, 5, 14),
    );
    expect(
      LectureCin.analyser('14 mai 1990', aujourdHui: aujourdHui).dateNaissance,
      DateTime(1990, 5, 14),
    );
    // Date impossible ou dans le futur : ignorée.
    expect(LectureCin.analyser('31/02/1990', aujourdHui: aujourdHui).dateNaissance, isNull);
    expect(LectureCin.analyser('01/01/2030', aujourdHui: aujourdHui).dateNaissance, isNull);
  });

  test('Passeport : zone MRZ', () {
    const String texte = 'PASSEPORT\n'
        'P<TUNBEN<SALAH<<AMINE<<<<<<<<<<<<<<<<<<<<<<<\n'
        'X12345678<TUN9005148M3001012<<<<<<<<<<<<<<04';
    final ResultatScan r = LectureCin.analyser(texte, aujourdHui: aujourdHui);
    expect(r.nom, 'Ben Salah');
    expect(r.prenom, 'Amine');
    expect(r.dateNaissance, DateTime(1990, 5, 14));
    expect(r.sexe, 'M');
    // Le numéro de passeport n'est pas pris pour une CIN.
    expect(r.cin, isNull);
  });

  group('Lecture complète par Gemini', () {
    test('CIN recto : champs translittérés et contrôlés', () {
      final ResultatScan r = LectureCin.depuisGemini({
        'type_document': 'cin_recto',
        'cin': '0987 6543',
        'nom_ar': 'الطرابلسي',
        'prenom_ar': 'سارة',
        'nom': 'TRABELSI',
        'prenom': 'sarra',
        'pere': 'mohamed',
        'sexe': 'F',
        'date_naissance': '1990-05-14',
        'lieu_naissance': 'sousse',
        'adresse': null,
      }, aujourdHui: aujourdHui);
      expect(r.viaGemini, isTrue);
      expect(r.cin, '09876543');
      expect(r.nom, 'Trabelsi');
      expect(r.prenom, 'Sarra');
      expect(r.nomArabe, 'الطرابلسي');
      expect(r.pere, 'Mohamed');
      expect(r.sexe, 'F');
      expect(r.dateNaissance, DateTime(1990, 5, 14));
      expect(r.lieuNaissance, 'Sousse');
      expect(r.vide, isFalse);
    });

    test('Valeurs incohérentes ignorées', () {
      final ResultatScan r = LectureCin.depuisGemini({
        'type_document': 'cin_recto',
        'cin': '1234',
        'sexe': 'X',
        'date_naissance': '2031-01-01',
        'nom': 'null',
      }, aujourdHui: aujourdHui);
      expect(r.cin, isNull);
      expect(r.sexe, isNull);
      expect(r.dateNaissance, isNull);
      expect(r.nom, isNull);
    });

    test('Autre document : rien de rempli', () {
      final ResultatScan r = LectureCin.depuisGemini(
        {'type_document': 'autre'},
        aujourdHui: aujourdHui,
      );
      expect(r.vide, isTrue);
      expect(r.avertissement, isNotNull);
    });

    test('Majuscules des noms composés', () {
      expect(LectureCin.majuscules('BEN SALAH'), 'Ben Salah');
      expect(LectureCin.majuscules('el-kefi'), 'El-Kefi');
    });
  });
}
