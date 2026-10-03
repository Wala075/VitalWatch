import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/services/email_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/staff_models.dart';

/// Après un enregistrement :
/// - mail envoyé  → simple message « Identifiants envoyés à ... » ;
/// - mail échoué  → fenêtre avec les identifiants + bouton « Réessayer l'envoi ».
Future<void> informerResultat(
  BuildContext context,
  ResultatEnregistrement res,
) async {
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  final List<String> lignes = [];

  final String? message = res.message;
  if (message != null) {
    lignes.add(message);
  }

  final CompteCree? compte = res.compte;
  if (compte != null) {
    final EnvoiEmail? envoi = res.envoi;
    if (envoi != null && envoi.envoye) {
      lignes.add('Identifiants envoyés par mail à ${compte.email}');
    } else {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _CompteCreeDialog(
          compte: compte,
          erreurInitiale: envoi?.erreur,
        ),
      );
    }
  }

  if (lignes.isNotEmpty) {
    messenger.showSnackBar(SnackBar(content: Text(lignes.join('\n'))));
  }
}

class _CompteCreeDialog extends StatefulWidget {
  const _CompteCreeDialog({required this.compte, this.erreurInitiale});

  final CompteCree compte;
  final String? erreurInitiale;

  @override
  State<_CompteCreeDialog> createState() => _CompteCreeDialogState();
}

class _CompteCreeDialogState extends State<_CompteCreeDialog> {
  final EmailService _emailService = EmailService();

  String? _erreur;
  bool _envoiEnCours = false;

  @override
  void initState() {
    super.initState();
    _erreur = widget.erreurInitiale;
  }

  Future<void> _renvoyer() async {
    setState(() => _envoiEnCours = true);
    final CompteCree c = widget.compte;
    final EnvoiEmail r = await _emailService.envoyerIdentifiants(
      email: c.email,
      nom: c.nom,
      role: c.role,
      motDePasse: c.motDePasseTemporaire,
    );
    if (!mounted) return;

    if (r.envoye) {
      final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(
        SnackBar(content: Text('Identifiants envoyés par mail à ${c.email}')),
      );
      return;
    }
    setState(() {
      _envoiEnCours = false;
      _erreur = r.erreur;
    });
  }

  void _copier() {
    final CompteCree c = widget.compte;
    Clipboard.setData(ClipboardData(
      text: 'Email : ${c.email}\nMot de passe : ${c.motDePasseTemporaire}',
    ));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Identifiants copiés')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final CompteCree c = widget.compte;
    final String? erreur = _erreur;

    return AlertDialog(
      icon: const Icon(Icons.verified_user, color: AppColors.success, size: 40),
      title: const Text('Compte créé'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (erreur != null) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.mail_outline, color: AppColors.warning, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Le mail n'a pas pu être envoyé.\n$erreur",
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],
            const Text('Transmettez ces identifiants à la personne concernée :'),
            const SizedBox(height: 12),
            _Ligne(libelle: 'Email', valeur: c.email),
            const SizedBox(height: 8),
            _Ligne(libelle: 'Mot de passe temporaire', valeur: c.motDePasseTemporaire),
            const SizedBox(height: 12),
            const Text(
              "Le mot de passe n'est stocké que sous forme hachée : "
              'il ne pourra plus être affiché après fermeture.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
      actions: [
        TextButton.icon(
          icon: const Icon(Icons.copy, size: 18),
          label: const Text('Copier'),
          onPressed: _copier,
        ),
        TextButton.icon(
          icon: _envoiEnCours
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.send, size: 18),
          label: const Text("Réessayer l'envoi"),
          onPressed: _envoiEnCours ? null : _renvoyer,
        ),
        FilledButton(
          onPressed: _envoiEnCours ? null : () => Navigator.pop(context),
          child: const Text('Fermer'),
        ),
      ],
    );
  }
}

class _Ligne extends StatelessWidget {
  const _Ligne({required this.libelle, required this.valeur});

  final String libelle;
  final String valeur;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            libelle,
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 2),
          SelectableText(
            valeur,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
