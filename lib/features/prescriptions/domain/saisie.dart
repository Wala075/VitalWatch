/// Lecture et contrôle des champs de saisie du module.
/// Chaque contrôle renvoie null si la valeur est correcte, sinon le message.
class Saisie {
  Saisie._();

  /// « 12,500 », « 12.5 » ou « 1 200,5 » → nombre ; null si vide ou invalide.
  static double? decimal(String? texte) {
    final String t = (texte ?? '').trim().replaceAll(' ', '').replaceAll(',', '.');
    if (t.isEmpty) {
      return null;
    }
    return double.tryParse(t);
  }

  static String? requis(String? texte, {String champ = 'Ce champ'}) {
    if ((texte ?? '').trim().isEmpty) {
      return '$champ est obligatoire';
    }
    return null;
  }

  /// Montant en dinars (3 décimales), positif ou nul.
  static String? montant(String? texte, {String champ = 'Le montant', bool obligatoire = true}) {
    if ((texte ?? '').trim().isEmpty) {
      return obligatoire ? '$champ est obligatoire' : null;
    }
    final double? v = decimal(texte);
    if (v == null) {
      return '$champ doit être un nombre (ex. 12,500)';
    }
    if (v < 0) {
      return '$champ ne peut pas être négatif';
    }
    return null;
  }

  /// Nombre décimal strictement positif (dose…).
  static String? positif(String? texte, {String champ = 'Ce champ', bool obligatoire = true}) {
    if ((texte ?? '').trim().isEmpty) {
      return obligatoire ? '$champ est obligatoire' : null;
    }
    final double? v = decimal(texte);
    if (v == null || v <= 0) {
      return '$champ doit être supérieur à 0';
    }
    return null;
  }

  static String? entier(String? texte, {String champ = 'Ce champ', int min = 0, int? max}) {
    final String t = (texte ?? '').trim();
    if (t.isEmpty) {
      return '$champ est obligatoire';
    }
    final int? v = int.tryParse(t);
    if (v == null) {
      return '$champ doit être un nombre entier';
    }
    if (v < min) {
      return '$champ doit être au moins $min';
    }
    if (max != null && v > max) {
      return '$champ ne peut pas dépasser $max';
    }
    return null;
  }

  /// Pourcentage entre 0 et 100 ; vide autorisé (= pas de taux).
  static String? pourcentage(String? texte) {
    if ((texte ?? '').trim().isEmpty) {
      return null;
    }
    final double? v = decimal(texte);
    if (v == null || v < 0 || v > 100) {
      return 'Entre 0 et 100';
    }
    return null;
  }

  /// Code CIM-10 : une lettre, deux chiffres, puis une précision facultative (E11, E11.9).
  static final RegExp _cim10 = RegExp(r'^[A-Z][0-9]{2}(\.[0-9A-Z]{1,4})?$');

  static String? codeCim10(String? texte) {
    final String t = (texte ?? '').trim().toUpperCase();
    if (t.isEmpty) {
      return 'Le code CIM-10 est obligatoire';
    }
    if (!_cim10.hasMatch(t)) {
      return 'Code CIM-10 invalide (ex. E11 ou E11.9)';
    }
    return null;
  }
}
