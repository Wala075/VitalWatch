/// Échecs de connexion enregistrés pour un email (table `tentatives_connexion`).
class TentativesConnexion {
  const TentativesConnexion({this.echecs = 0, this.bloqueJusqua});

  final int echecs;

  /// Fin du blocage temporaire (null : pas bloqué).
  final DateTime? bloqueJusqua;
}

/// Métier « Protection contre la force brute » (fonctions pures, testées) :
/// - captcha Cloudflare Turnstile exigé à chaque connexion ;
/// - au 5e mot de passe faux : connexion bloquée 5 minutes, puis le blocage
///   double à chaque nouvel échec (10, 20, 40 min…), 1 heure au maximum ;
/// - une connexion réussie remet le compteur à zéro.
/// Un email inconnu compte comme un échec (on ne révèle pas s'il existe).
class ProtectionConnexion {
  ProtectionConnexion._();

  static const int seuilBlocage = 5;
  static const Duration blocageInitial = Duration(minutes: 5);
  static const Duration blocageMax = Duration(hours: 1);

  /// Temps restant avant de pouvoir réessayer (null : pas bloqué).
  static Duration? attente(TentativesConnexion t, DateTime maintenant) {
    final DateTime? fin = t.bloqueJusqua;
    if (fin == null || !fin.isAfter(maintenant)) {
      return null;
    }
    return fin.difference(maintenant);
  }

  /// Durée du blocage après [echecs] échecs consécutifs.
  static Duration dureeBlocage(int echecs) {
    if (echecs < seuilBlocage) {
      return Duration.zero;
    }
    Duration d = blocageInitial;
    for (int i = seuilBlocage; i < echecs && d < blocageMax; i++) {
      d = d * 2;
    }
    return d > blocageMax ? blocageMax : d;
  }

  static TentativesConnexion apresEchec(
    TentativesConnexion t,
    DateTime maintenant,
  ) {
    final int n = t.echecs + 1;
    final Duration d = dureeBlocage(n);
    return TentativesConnexion(
      echecs: n,
      bloqueJusqua: d == Duration.zero ? null : maintenant.add(d),
    );
  }

  /// Essais restants avant le premier blocage.
  static int essaisAvantBlocage(TentativesConnexion t) =>
      t.echecs >= seuilBlocage ? 0 : seuilBlocage - t.echecs;

  /// « 45 s » ou « 5 min »
  static String formater(Duration d) {
    final int s = d.inSeconds;
    if (s < 60) {
      return '$s s';
    }
    return '${(s / 60).ceil()} min';
  }
}

/// Réponse de l'API Cloudflare Turnstile « siteverify ».
class VerificationCaptcha {
  const VerificationCaptcha(this.valide, this.codes);

  factory VerificationCaptcha.depuisJson(Map<String, dynamic> json) {
    final Object? codes = json['error-codes'];
    return VerificationCaptcha(
      json['success'] == true,
      [
        if (codes is List)
          for (final Object? c in codes)
            if (c is String) c,
      ],
    );
  }

  final bool valide;

  /// Codes d'erreur Cloudflare (ex. « timeout-or-duplicate »).
  final List<String> codes;

  String get message {
    if (valide) {
      return '';
    }
    if (codes.contains('timeout-or-duplicate')) {
      return 'Vérification anti-robot expirée : refaites le captcha';
    }
    if (codes.contains('erreur-reseau')) {
      return 'Vérification anti-robot impossible : vérifiez votre connexion Internet';
    }
    if (codes.contains('invalid-input-secret') ||
        codes.contains('missing-input-secret')) {
      return "Captcha mal configuré : contactez l'administrateur";
    }
    return 'Vérification anti-robot échouée : recommencez';
  }
}
