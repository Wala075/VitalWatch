import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../../core/config/gemini_config.dart';

/// Erreur affichable lors de la lecture de la CIN par Gemini.
class LectureCinException implements Exception {
  const LectureCinException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// API REST Google Gemini : lit une photo de CIN tunisienne (texte arabe)
/// et renvoie les champs translittérés en français, au format JSON.
///
/// Confidentialité : la photo est envoyée à Google. Avec une clé gratuite,
/// Google peut utiliser les données pour améliorer ses produits : n'utiliser
/// que des cartes de démonstration, ou une clé payante pour de vraies CIN.
class LectureCinGemini {
  static const String _base =
      'https://generativelanguage.googleapis.com/v1beta/models';

  /// Modèles essayés dans l'ordre si le précédent n'existe plus (404), reste
  /// surchargé (503) ou ne répond pas à temps. « Flash-Lite » est le plus
  /// rapide et le moins chargé ; « Flash » sert de secours.
  static List<String> get _modeles => <String>{
        GeminiConfig.modele,
        'gemini-3.5-flash-lite',
        GeminiConfig.modeleParDefaut,
        'gemini-3.8-flash',
      }.toList();

  /// Une seule reprise d'un modèle surchargé, après 2 secondes.
  static const List<Duration> _reprises = [Duration(seconds: 2)];

  /// Délai d'une requête, et durée maximale de toute la lecture.
  static const Duration _delaiRequete = Duration(seconds: 25);
  static const Duration _budget = Duration(seconds: 60);

  static const String consigne = '''
Tu lis la photo d'une carte d'identité nationale tunisienne (CIN), recto ou verso.
Le texte est en arabe. Renvoie UNIQUEMENT un objet JSON avec exactement ces clés :
{
  "type_document": "cin_recto" | "cin_verso" | "autre",
  "cin": numéro de 8 chiffres ou null,
  "nom_ar": nom de famille (اللقب) tel qu'écrit en arabe, ou null,
  "prenom_ar": prénom (الاسم) tel qu'écrit en arabe, ou null,
  "nom": nom de famille translittéré en lettres latines, ou null,
  "prenom": prénom translittéré, ou null,
  "pere": prénom du père (après « بن » ou « بنت ») translittéré, ou null,
  "sexe": "M" si « بن » précède le nom du père, "F" si « بنت », sinon null,
  "date_naissance": date de naissance au format AAAA-MM-JJ, ou null,
  "lieu_naissance": lieu de naissance translittéré, ou null,
  "adresse": adresse (verso) translittérée, ou null
}
Règles :
- Translittère selon l'usage tunisien, en orthographe française habituelle
  (ex. محمد → Mohamed, الطرابلسي → Trabelsi, عائشة → Aicha, سوسة → Sousse,
  تونس → Tunis). Majuscule au début de chaque mot.
- Mois tunisiens : جانفي=01, فيفري=02, مارس=03, أفريل=04, ماي=05, جوان=06,
  جويلية=07, أوت=08, سبتمبر=09, أكتوبر=10, نوفمبر=11, ديسمبر=12.
- Mets null pour tout ce qui n'est pas lisible. N'invente rien.
- Si l'image n'est pas une CIN tunisienne, type_document = "autre" et le reste null.
''';

  /// [image] : photo JPEG ou PNG. Renvoie l'objet JSON lu par Gemini.
  Future<Map<String, dynamic>> lire(Uint8List image, String typeMime) async {
    if (!GeminiConfig.estConfigure) {
      throw const LectureCinException('Clé Gemini absente');
    }
    final String corps = jsonEncode({
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': consigne},
            {
              'inlineData': {'mimeType': typeMime, 'data': base64Encode(image)},
            },
          ],
        },
      ],
      'generationConfig': {
        'temperature': 0,
        'responseMimeType': 'application/json',
      },
    });

    final Stopwatch chrono = Stopwatch()..start();
    LectureCinException? derniere;
    for (final String modele in _modeles) {
      for (int essai = 0; essai <= _reprises.length; essai++) {
        if (chrono.elapsed > _budget) {
          throw derniere ??
              const LectureCinException('Gemini ne répond pas : réessayez plus tard');
        }
        final http.Response? r = await _appeler(modele, corps);

        if (r == null) {
          // Trop long : on passe au modèle suivant (souvent plus rapide).
          derniere = const LectureCinException(
            'Gemini ne répond pas (serveurs surchargés) : réessayez plus tard',
          );
          break;
        }
        if (r.statusCode == 200) {
          return extraireJson(utf8.decode(r.bodyBytes));
        }
        if (r.statusCode == 500 || r.statusCode == 503) {
          derniere = const LectureCinException(
            'Gemini est surchargé : réessayez dans un instant',
          );
          if (essai < _reprises.length) {
            await Future<void>.delayed(_reprises[essai]);
            continue;
          }
          break; // modèle suivant
        }
        if (r.statusCode == 404) {
          derniere = LectureCinException('Modèle Gemini « $modele » introuvable');
          break;
        }
        if (r.statusCode == 429) {
          throw const LectureCinException(
            'Quota Gemini atteint : réessayez dans une minute',
          );
        }
        final String detail = _detailErreur(r);
        if (r.statusCode == 401 ||
            r.statusCode == 403 ||
            detail.toUpperCase().contains('API KEY') ||
            detail.contains('API_KEY')) {
          throw const LectureCinException(
            'Clé Gemini refusée : vérifiez assets/config/gemini.json',
          );
        }
        // Autre refus propre à ce modèle : on essaie le suivant.
        derniere = LectureCinException(
          'Erreur Gemini (${r.statusCode})${detail.isEmpty ? '' : ' : $detail'}',
        );
        break;
      }
    }
    throw derniere ?? const LectureCinException('Aucun modèle Gemini disponible');
  }

  /// null si la requête dépasse le délai.
  Future<http.Response?> _appeler(String modele, String corps) async {
    try {
      return await http
          .post(
            Uri.parse('$_base/$modele:generateContent'),
            headers: {
              'Content-Type': 'application/json',
              'x-goog-api-key': GeminiConfig.cleApi,
            },
            body: corps,
          )
          .timeout(_delaiRequete);
    } on TimeoutException {
      return null;
    } catch (_) {
      throw const LectureCinException(
        'Pas de connexion Internet : lecture du numéro seulement',
      );
    }
  }

  /// Message d'erreur renvoyé par Google (champ error.message), raccourci.
  static String _detailErreur(http.Response r) {
    try {
      final Object? json = jsonDecode(utf8.decode(r.bodyBytes));
      final Object? erreur = json is Map<String, dynamic> ? json['error'] : null;
      final Object? message =
          erreur is Map<String, dynamic> ? erreur['message'] : null;
      if (message is String) {
        return message.length > 120 ? '${message.substring(0, 120)}…' : message;
      }
    } catch (_) {
      // Corps illisible : pas de détail.
    }
    return '';
  }

  /// Réponse de l'API → objet JSON écrit par le modèle
  /// (les parties « réflexion » sont ignorées, les balises ``` retirées).
  static Map<String, dynamic> extraireJson(String reponse) {
    try {
      final Object? json = jsonDecode(reponse);
      final Object? candidats =
          json is Map<String, dynamic> ? json['candidates'] : null;
      if (candidats is! List || candidats.isEmpty) {
        throw const LectureCinException(
          "Gemini n'a rien renvoyé (photo refusée ?)",
        );
      }
      final Object? premier = candidats.first;
      final Object? contenu =
          premier is Map<String, dynamic> ? premier['content'] : null;
      final Object? parties =
          contenu is Map<String, dynamic> ? contenu['parts'] : null;
      final StringBuffer texte = StringBuffer();
      if (parties is List) {
        for (final Object? p in parties) {
          if (p is Map<String, dynamic> && p['thought'] != true) {
            final Object? t = p['text'];
            if (t is String) texte.write(t);
          }
        }
      }
      final String brut = texte.toString();
      final int debut = brut.indexOf('{');
      final int fin = brut.lastIndexOf('}');
      if (debut < 0 || fin <= debut) {
        throw const LectureCinException('Réponse Gemini illisible');
      }
      final Object? champs = jsonDecode(brut.substring(debut, fin + 1));
      if (champs is! Map<String, dynamic>) {
        throw const LectureCinException('Réponse Gemini illisible');
      }
      return champs;
    } on FormatException {
      throw const LectureCinException('Réponse Gemini illisible');
    }
  }
}
