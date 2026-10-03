import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// Hachage des mots de passe : SHA-256 salé + 1000 itérations.
/// Format stocké : "sel$hash".
class PasswordHasher {
  PasswordHasher._();

  static final Random _random = Random.secure();

  // Sans caractères ambigus (0/O, 1/l/I)
  static const String _alphabet =
      'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789';

  static const int _iterations = 1000;

  static String genererMotDePasseTemporaire({int longueur = 10}) {
    final StringBuffer sb = StringBuffer();
    for (int i = 0; i < longueur; i++) {
      sb.write(_alphabet[_random.nextInt(_alphabet.length)]);
    }
    return sb.toString();
  }

  static String hacher(String motDePasse) {
    final List<int> octets = List<int>.generate(16, (_) => _random.nextInt(256));
    final String sel = base64Url.encode(octets);
    return '$sel\$${_calculer(sel, motDePasse)}';
  }

  static bool verifier(String motDePasse, String stocke) {
    final int i = stocke.indexOf('\$');
    if (i <= 0) {
      return false;
    }
    final String sel = stocke.substring(0, i);
    final String attendu = stocke.substring(i + 1);
    return _calculer(sel, motDePasse) == attendu;
  }

  static String _calculer(String sel, String motDePasse) {
    final List<int> base = utf8.encode('$sel:$motDePasse');
    Digest d = sha256.convert(base);
    for (int i = 1; i < _iterations; i++) {
      d = sha256.convert(<int>[...d.bytes, ...base]);
    }
    return d.toString();
  }
}
