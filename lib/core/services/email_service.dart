import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_constants.dart';
import '../config/email_config.dart';

/// Résultat d'un envoi de mail.
class EnvoiEmail {
  const EnvoiEmail.ok()
      : envoye = true,
        erreur = null;

  const EnvoiEmail.echec(String message)
      : envoye = false,
        erreur = message;

  final bool envoye;
  final String? erreur;
}

/// Envoi des identifiants de connexion par mail via l'API REST EmailJS.
class EmailService {
  static const String _url = 'https://api.emailjs.com/api/v1.0/email/send';

  static const String messageCreation =
      'Votre compte VitalWatch vient d\'être créé.';
  static const String messageReinitialisation =
      'Votre mot de passe VitalWatch a été réinitialisé.';

  Future<EnvoiEmail> envoyerIdentifiants({
    required String email,
    required String nom,
    required String role,
    required String motDePasse,
    String message = messageCreation,
  }) async {
    if (!EmailConfig.estConfigure) {
      return const EnvoiEmail.echec(
        'Envoi par mail non configuré (clés EmailJS absentes)',
      );
    }

    try {
      final http.Response r = await http
          .post(
            Uri.parse(_url),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'service_id': EmailConfig.serviceId,
              'template_id': EmailConfig.templateId,
              'user_id': EmailConfig.publicKey,
              if (EmailConfig.privateKey.isNotEmpty)
                'accessToken': EmailConfig.privateKey,
              'template_params': {
                'to_email': email,
                'to_name': nom,
                'role': role,
                'login_email': email,
                'password': motDePasse,
                'message': message,
                'app_name': AppConstants.appName,
              },
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (r.statusCode == 200) {
        return const EnvoiEmail.ok();
      }
      return EnvoiEmail.echec('EmailJS a refusé l\'envoi (${r.statusCode}) : ${r.body}');
    } on TimeoutException {
      return const EnvoiEmail.echec('Délai dépassé : vérifiez la connexion internet');
    } catch (e) {
      return EnvoiEmail.echec('Pas de connexion internet ($e)');
    }
  }
}
