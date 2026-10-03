/// Validateurs de formulaires partagés (compatibles avec TextFormField.validator).
class Validators {
  Validators._();

  static final RegExp _cin = RegExp(r'^[0-9]{8}$');
  static final RegExp _tel = RegExp(r'^(\+216|00216)?[2-9][0-9]{7}$');
  static final RegExp _email = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$');

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
    if (!_cin.hasMatch(value.trim())) {
      return 'La CIN doit contenir exactement 8 chiffres';
    }
    return null;
  }

  /// Téléphone tunisien : 8 chiffres, préfixe +216 / 00216 optionnel.
  static String? telephone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Le téléphone est obligatoire';
    }
    if (!_tel.hasMatch(_compacter(value))) {
      return 'Numéro invalide (ex : +216 22 123 456)';
    }
    return null;
  }

  static String? telephoneOptionnel(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    return telephone(value);
  }

  /// Ramène tout numéro valide au format +216XXXXXXXX.
  static String normaliserTelephone(String value) {
    String t = _compacter(value);
    if (t.startsWith('+216')) {
      t = t.substring(4);
    } else if (t.startsWith('00216')) {
      t = t.substring(5);
    }
    return '+216$t';
  }

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) {
      return "L'email est obligatoire";
    }
    if (!_email.hasMatch(value.trim())) {
      return 'Email invalide';
    }
    return null;
  }

  static String? emailOptionnel(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    return email(value);
  }

  static String? motDePasse(String? value) {
    if (value == null || value.isEmpty) {
      return 'Le mot de passe est obligatoire';
    }
    if (value.length < 6) {
      return 'Le mot de passe doit contenir au moins 6 caractères';
    }
    return null;
  }

  /// Date de naissance cohérente : ni dans le futur, ni plus de 120 ans.
  static String? dateNaissance(DateTime? date) {
    if (date == null) {
      return 'La date de naissance est obligatoire';
    }
    final DateTime maintenant = DateTime.now();
    if (date.isAfter(maintenant)) {
      return 'La date de naissance ne peut pas être dans le futur';
    }
    if (maintenant.year - date.year > 120) {
      return 'Date de naissance incohérente (plus de 120 ans)';
    }
    return null;
  }

  static String? entier(String? value, {String champ = 'Ce champ', int min = 0}) {
    if (value == null || value.trim().isEmpty) {
      return '$champ est obligatoire';
    }
    final int? n = int.tryParse(value.trim());
    if (n == null) {
      return '$champ doit être un nombre';
    }
    if (n < min) {
      return '$champ doit être au moins $min';
    }
    return null;
  }

  static String? entierOptionnel(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    if (int.tryParse(value.trim()) == null) {
      return 'Nombre invalide';
    }
    return null;
  }

  static String _compacter(String value) {
    return value.replaceAll(' ', '').replaceAll('-', '').replaceAll('.', '');
  }
}
