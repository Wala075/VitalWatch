/// Appel à l'aide reconnu dans la parole (« help », « au secours »...).
class AppelAide {
  const AppelAide({required this.motCle, required this.texte, required this.date});

  /// Mot-clé reconnu (forme normalisée, ex. « au secours »).
  final String motCle;

  /// Phrase entendue telle que transcrite par la reconnaissance vocale.
  final String texte;
  final DateTime date;
}

/// Détection des appels à l'aide dans une transcription vocale.
/// Insensible à la casse, aux accents et à la ponctuation ; un mot-clé doit
/// être un mot entier (« helping » ou « secourisme » ne déclenchent rien).
class DetecteurAppelAide {
  DetecteurAppelAide._();

  /// Mots-clés normalisés, expressions longues d'abord.
  static const List<String> motsCles = [
    'au secours',
    'au secour',
    'a l aide',
    'aidez moi',
    'aide moi',
    'besoin d aide',
    'appelez une ambulance',
    'help me',
    'help',
    'secours',
    's o s',
    'sos',
  ];

  static const Map<String, String> _accents = {
    'à': 'a', 'â': 'a', 'ä': 'a', 'á': 'a',
    'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
    'î': 'i', 'ï': 'i', 'í': 'i',
    'ô': 'o', 'ö': 'o', 'ó': 'o',
    'ù': 'u', 'û': 'u', 'ü': 'u', 'ú': 'u',
    'ç': 'c', 'ÿ': 'y',
  };

  /// Minuscules sans accents, ponctuation et apostrophes remplacées par des
  /// espaces, espaces multiples réduits.
  static String normaliser(String texte) {
    final StringBuffer b = StringBuffer();
    bool espace = true;
    for (final String c in texte.toLowerCase().split('')) {
      final String l = _accents[c] ?? c;
      final int code = l.codeUnitAt(0);
      final bool lettre = (code >= 0x61 && code <= 0x7a) || (code >= 0x30 && code <= 0x39);
      if (lettre) {
        b.write(l);
        espace = false;
      } else if (!espace) {
        b.write(' ');
        espace = true;
      }
    }
    return b.toString().trim();
  }

  /// Mot-clé reconnu dans [texte], ou null.
  static String? detecter(String texte) {
    final String t = ' ${normaliser(texte)} ';
    for (final String m in motsCles) {
      if (t.contains(' $m ')) {
        return m;
      }
    }
    return null;
  }
}
