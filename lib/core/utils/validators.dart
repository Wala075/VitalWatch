/// Validateurs de formulaires partagés (compatibles avec TextFormField.validator).
class Validators {
  Validators._();

  static String? requis(String? value, {String champ = 'Ce champ'}) {
    if (value == null || value.trim().isEmpty) {
      return '$champ est obligatoire';
    }
    return null;
  }

  /// CIN tunisienne : exactement 8 chiffres.
  static String? cin(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'La CIN est obligatoire';
    }
    if (!RegExp(r'^[0-9]{8}$').hasMatch(value.trim())) {
      return 'La CIN doit contenir 8 chiffres';
    }
    return null;
  }

  /// Téléphone tunisien : 8 chiffres, préfixe +216 / 00216 optionnel.
  static String? telephone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Le téléphone est obligatoire';
    }
    final String tel = value.replaceAll(' ', '');
    if (!RegExp(r'^(\+216|00216)?[2-9][0-9]{7}$').hasMatch(tel)) {
      return 'Numéro invalide (ex : +216 22 123 456)';
    }
    return null;
  }

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) {
      return "L'email est obligatoire";
    }
    if (!RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$').hasMatch(value.trim())) {
      return 'Email invalide';
    }
    return null;
  }
}
