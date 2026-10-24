/// Champs reconnus sur une pièce d'identité (null = non reconnu).
class ResultatScan {
  const ResultatScan({
    this.cin,
    this.nom,
    this.prenom,
    this.dateNaissance,
    this.sexe,
    this.nomArabe,
    this.prenomArabe,
    this.pere,
    this.lieuNaissance,
    this.adresse,
    this.viaGemini = false,
    this.avertissement,
  });

  final String? cin;

  /// En lettres latines (translittéré depuis l'arabe si lu par Gemini).
  final String? nom;
  final String? prenom;
  final DateTime? dateNaissance;

  /// 'M' ou 'F' (CIN : « بن » = fils de, « بنت » = fille de).
  final String? sexe;

  /// Tels qu'écrits en arabe sur la CIN (vérification).
  final String? nomArabe;
  final String? prenomArabe;

  /// Prénom du père.
  final String? pere;
  final String? lieuNaissance;

  /// Adresse (verso de la CIN).
  final String? adresse;

  /// Lecture complète par l'API Gemini (sinon ML Kit : numéro seulement).
  final bool viaGemini;

  /// Message à afficher (ex. Gemini indisponible, lecture partielle).
  final String? avertissement;

  bool get vide =>
      cin == null &&
      nom == null &&
      prenom == null &&
      dateNaissance == null &&
      adresse == null;

  ResultatScan avecAvertissement(String message) {
    return ResultatScan(
      cin: cin,
      nom: nom,
      prenom: prenom,
      dateNaissance: dateNaissance,
      sexe: sexe,
      nomArabe: nomArabe,
      prenomArabe: prenomArabe,
      pere: pere,
      lieuNaissance: lieuNaissance,
      adresse: adresse,
      viaGemini: viaGemini,
      avertissement: message,
    );
  }
}

/// Analyse du texte renvoyé par la reconnaissance de texte (Google ML Kit)
/// sur une carte d'identité tunisienne ou un passeport.
///
/// - CIN : 8 chiffres (imprimés en chiffres latins sur la carte).
/// - Passeport : zone de lecture automatique (MRZ, 2 lignes de 44
///   caractères) → nom, prénom, date de naissance, sexe.
/// - Date au format 14/05/1990, 14.05.1990, 14-05-1990 ou 14 mai 1990.
/// Les noms écrits en arabe sur la CIN ne sont pas lus (ML Kit ne lit pas
/// l'alphabet arabe) : la secrétaire les saisit.
class LectureCin {
  LectureCin._();

  static const Map<String, int> _mois = {
    'janvier': 1, 'fevrier': 2, 'février': 2, 'mars': 3, 'avril': 4,
    'mai': 5, 'juin': 6, 'juillet': 7, 'aout': 8, 'août': 8,
    'septembre': 9, 'octobre': 10, 'novembre': 11, 'decembre': 12,
    'décembre': 12,
  };

  /// Réponse JSON de l'API Gemini (voir LectureCinGemini.consigne) :
  /// chaque champ est contrôlé (CIN à 8 chiffres, date plausible, sexe M/F).
  static ResultatScan depuisGemini(
    Map<String, dynamic> json, {
    DateTime? aujourdHui,
  }) {
    final DateTime maintenant = aujourdHui ?? DateTime.now();
    String? texte(String cle) {
      final Object? v = json[cle];
      if (v is! String) return null;
      final String t = v.trim();
      return t.isEmpty || t.toLowerCase() == 'null' ? null : t;
    }

    if (texte('type_document') == 'autre') {
      return const ResultatScan(
        viaGemini: true,
        avertissement: "Ce n'est pas une CIN tunisienne lisible",
      );
    }

    final String? brutCin = texte('cin')?.replaceAll(RegExp(r'\s'), '');
    final String? cin =
        brutCin != null && RegExp(r'^\d{8}$').hasMatch(brutCin) ? brutCin : null;

    DateTime? naissance;
    final String? date = texte('date_naissance');
    final RegExpMatch? m = date == null
        ? null
        : RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})$').firstMatch(date);
    if (m != null) {
      naissance = _date(
        int.parse(m.group(1)!),
        int.parse(m.group(2)!),
        int.parse(m.group(3)!),
        maintenant,
      );
    }
    final String? sexe = texte('sexe')?.toUpperCase();

    return ResultatScan(
      cin: cin,
      nom: majuscules(texte('nom')),
      prenom: majuscules(texte('prenom')),
      dateNaissance: naissance,
      sexe: sexe == 'M' || sexe == 'F' ? sexe : null,
      nomArabe: texte('nom_ar'),
      prenomArabe: texte('prenom_ar'),
      pere: majuscules(texte('pere')),
      lieuNaissance: majuscules(texte('lieu_naissance')),
      adresse: texte('adresse'),
      viaGemini: true,
    );
  }

  /// « BEN SALAH » → « Ben Salah », « el-kefi » → « El-Kefi »
  static String? majuscules(String? s) {
    if (s == null) return null;
    final String bas = s.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
    return bas.replaceAllMapped(
      RegExp(r"(^|[\s\-'])(\p{L})", unicode: true),
      (Match x) => '${x.group(1)}${x.group(2)!.toUpperCase()}',
    );
  }

  static ResultatScan analyser(String texte, {DateTime? aujourdHui}) {
    final DateTime maintenant = aujourdHui ?? DateTime.now();
    final ResultatScan? mrz = _lireMrz(texte, maintenant);
    final String? cin = _lireCin(texte);
    final DateTime? date = mrz?.dateNaissance ?? _lireDate(texte, maintenant);
    return ResultatScan(
      cin: cin,
      nom: mrz?.nom,
      prenom: mrz?.prenom,
      dateNaissance: date,
      sexe: mrz?.sexe,
    );
  }

  /// Le numéro à 8 chiffres le plus fréquent (il est parfois imprimé deux
  /// fois) ; les suites plus longues (dates collées, codes) sont ignorées.
  static String? _lireCin(String texte) {
    // Les lignes MRZ d'un passeport (avec des « < ») ne contiennent pas la CIN.
    final String sansMrz = texte
        .split('\n')
        .where((String l) => !l.contains('<'))
        .join('\n');
    final String t = sansMrz.replaceAll(RegExp(r'[Oo](?=\d)|(?<=\d)[Oo]'), '0');
    final Map<String, int> vus = {};
    for (final RegExpMatch m in RegExp(r'(?<!\d)\d{8}(?!\d)').allMatches(t)) {
      final String n = m.group(0)!;
      vus[n] = (vus[n] ?? 0) + 1;
    }
    if (vus.isEmpty) return null;
    String meilleur = vus.keys.first;
    for (final MapEntry<String, int> e in vus.entries) {
      if (e.value > vus[meilleur]!) meilleur = e.key;
    }
    return meilleur;
  }

  static DateTime? _lireDate(String texte, DateTime maintenant) {
    final RegExp numerique =
        RegExp(r'(?<!\d)(\d{1,2})\s*[/.\-]\s*(\d{1,2})\s*[/.\-]\s*(\d{4})(?!\d)');
    for (final RegExpMatch m in numerique.allMatches(texte)) {
      final DateTime? d = _date(
        int.parse(m.group(3)!),
        int.parse(m.group(2)!),
        int.parse(m.group(1)!),
        maintenant,
      );
      if (d != null) return d;
    }
    final RegExp enLettres = RegExp(
      r'(?<!\d)(\d{1,2})\s+([a-zA-Zéèûô]+)\s+(\d{4})(?!\d)',
      caseSensitive: false,
    );
    for (final RegExpMatch m in enLettres.allMatches(texte)) {
      final int? mois = _mois[m.group(2)!.toLowerCase()];
      if (mois == null) continue;
      final DateTime? d =
          _date(int.parse(m.group(3)!), mois, int.parse(m.group(1)!), maintenant);
      if (d != null) return d;
    }
    return null;
  }

  /// Date valide et plausible pour une naissance (moins de 120 ans).
  static DateTime? _date(int annee, int mois, int jour, DateTime maintenant) {
    if (mois < 1 || mois > 12 || jour < 1 || jour > 31) return null;
    final DateTime d = DateTime(annee, mois, jour);
    if (d.month != mois || d.day != jour) return null; // 31/02...
    if (d.isAfter(maintenant) || annee < maintenant.year - 120) return null;
    return d;
  }

  /// Passeport (format TD3) :
  /// P<TUNBEN<SALAH<<AMINE<<<<<<<<<<<<<<<<<<<<<<<
  /// X12345678<TUN9005148M3001012<<<<<<<<<<<<<<04
  static ResultatScan? _lireMrz(String texte, DateTime maintenant) {
    final List<String> lignes = [
      for (final String l in texte.split('\n'))
        l.replaceAll(' ', '').toUpperCase(),
    ];
    for (int i = 0; i + 1 < lignes.length; i++) {
      final String l1 = lignes[i];
      final String l2 = lignes[i + 1];
      if (!l1.startsWith('P<') || l1.length < 30 || l2.length < 28) continue;

      final String noms = l1.substring(5);
      final int sep = noms.indexOf('<<');
      if (sep <= 0) continue;
      String propre(String s) => s
          .split('<')
          .where((String m) => m.isNotEmpty)
          .map((String m) => m[0] + m.substring(1).toLowerCase())
          .join(' ');
      final String nom = propre(noms.substring(0, sep));
      final String prenom = propre(noms.substring(sep + 2));

      final String naissance = l2.substring(13, 19); // AAMMJJ
      final String sexe = l2.substring(20, 21);
      DateTime? date;
      final int? aa = int.tryParse(naissance.substring(0, 2));
      final int? mm = int.tryParse(naissance.substring(2, 4));
      final int? jj = int.tryParse(naissance.substring(4, 6));
      if (aa != null && mm != null && jj != null) {
        final int siecle = 2000 + aa > maintenant.year ? 1900 : 2000;
        date = _date(siecle + aa, mm, jj, maintenant);
      }
      return ResultatScan(
        nom: nom.isEmpty ? null : nom,
        prenom: prenom.isEmpty ? null : prenom,
        dateNaissance: date,
        sexe: sexe == 'M' || sexe == 'F' ? sexe : null,
      );
    }
    return null;
  }
}
