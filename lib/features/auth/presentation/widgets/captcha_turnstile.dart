import 'package:cloudflare_turnstile/cloudflare_turnstile.dart';
import 'package:flutter/material.dart';

import '../../../../core/config/turnstile_config.dart';

/// Captcha Cloudflare Turnstile au format classique (300 × 65) :
/// case « Vérifiez que vous êtes humain » + logo Cloudflare.
/// [onJeton] reçoit le jeton à envoyer à l'API « siteverify » ; un jeton ne
/// sert qu'une fois : changer la clé du widget pour en obtenir un nouveau.
class CaptchaTurnstile extends StatelessWidget {
  const CaptchaTurnstile({
    super.key,
    required this.onJeton,
    this.onErreur,
  });

  final ValueChanged<String> onJeton;
  final ValueChanged<String>? onErreur;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Réduit légèrement sur les écrans trop étroits (< 300 de large).
        FittedBox(
          fit: BoxFit.scaleDown,
          child: SizedBox(
            width: 300,
            height: 65,
            child: CloudflareTurnstile(
              siteKey: TurnstileConfig.cleSite,
              baseUrl: TurnstileConfig.baseUrl,
              options: TurnstileOptions(
                size: TurnstileSize.normal,
                theme: TurnstileTheme.light,
                language: 'fr',
              ),
              onTokenReceived: (jeton) => onJeton(jeton),
              onError: (erreur) => onErreur?.call(erreur.message),
            ),
          ),
        ),
        if (TurnstileConfig.modeTest)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Captcha en mode test',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ),
      ],
    );
  }
}
