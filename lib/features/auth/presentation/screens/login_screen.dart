import 'package:flutter/material.dart';

import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../shared_providers/session.dart';
import '../../data/local_auth_repository.dart';
import '../../domain/auth_repository.dart';
import '../../../../core/widgets/error_banner.dart';
import '../widgets/captcha_turnstile.dart';
import '../widgets/login_header.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _mdpCtrl = TextEditingController();
  final AuthRepository _authRepository = LocalAuthRepository();

  bool _mdpVisible = false;
  bool _chargement = false;
  String? _erreur;

  // Captcha à chaque connexion : un jeton ne sert qu'une fois, la clé du
  // widget change après chaque essai pour en obtenir un nouveau.
  String? _jetonCaptcha;
  int _captchaVersion = 0;

  bool get _attenteCaptcha => _jetonCaptcha == null;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _mdpCtrl.dispose();
    super.dispose();
  }

  Future<void> _seConnecter() async {
    FocusScope.of(context).unfocus();
    setState(() => _erreur = null);

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _chargement = true);
    try {
      final utilisateur = await _authRepository.login(
        email: _emailCtrl.text,
        motDePasse: _mdpCtrl.text,
        jetonCaptcha: _jetonCaptcha,
      );
      Session.utilisateur = utilisateur;
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, AppRoutes.home);
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _erreur = e.message;
        _jetonCaptcha = null;
        _captchaVersion++;
      });
    } finally {
      if (mounted) {
        setState(() => _chargement = false);
      }
    }
  }

  /// Captcha toujours exigé avant l'envoi d'un nouveau mot de passe.
  Future<void> _motDePasseOublie() async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final String email = _emailCtrl.text.trim();

    if (Validators.email(email) != null) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Saisissez votre email pour réinitialiser le mot de passe'),
        ),
      );
      return;
    }

    final bool? envoye = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _FeuilleReinitialisation(
        email: email,
        depot: _authRepository,
      ),
    );
    if (envoye == true) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Si un compte existe pour $email, un nouveau mot de passe '
            'vient d\'y être envoyé',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.primaryDark, AppColors.primary, AppColors.secondary],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  children: [
                    const LoginHeader(),
                    const SizedBox(height: 32),
                    Card(
                      elevation: 8,
                      color: Colors.white,
                      surfaceTintColor: Colors.transparent,
                      shadowColor: Colors.black26,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                        child: AutofillGroup(
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  'Connexion',
                                  style: textTheme.headlineSmall?.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Accédez à votre espace sécurisé',
                                  style: textTheme.bodyMedium?.copyWith(
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                AppTextField(
                                  controller: _emailCtrl,
                                  label: 'Email',
                                  hint: 'nom@vitalwatch.tn',
                                  icon: Icons.email_outlined,
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.next,
                                  autofillHints: const [AutofillHints.email],
                                  validator: Validators.email,
                                  enabled: !_chargement,
                                ),
                                const SizedBox(height: 16),
                                AppTextField(
                                  controller: _mdpCtrl,
                                  label: 'Mot de passe',
                                  icon: Icons.lock_outline,
                                  obscureText: !_mdpVisible,
                                  textInputAction: TextInputAction.done,
                                  autofillHints: const [AutofillHints.password],
                                  validator: Validators.motDePasse,
                                  enabled: !_chargement,
                                  onFieldSubmitted: (_) => _seConnecter(),
                                  suffix: IconButton(
                                    icon: Icon(
                                      _mdpVisible
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                    ),
                                    tooltip: _mdpVisible
                                        ? 'Masquer le mot de passe'
                                        : 'Afficher le mot de passe',
                                    onPressed: () => setState(
                                      () => _mdpVisible = !_mdpVisible,
                                    ),
                                  ),
                                ),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed:
                                        _chargement ? null : _motDePasseOublie,
                                    child: const Text('Mot de passe oublié ?'),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Center(
                                  child: CaptchaTurnstile(
                                    key: ValueKey<int>(_captchaVersion),
                                    onJeton: (String jeton) =>
                                        setState(() => _jetonCaptcha = jeton),
                                    onErreur: (String message) => setState(
                                      () => _erreur = 'Captcha : $message',
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                if (_erreur != null) ...[
                                  ErrorBanner(message: _erreur!),
                                  const SizedBox(height: 16),
                                ],
                                PrimaryButton(
                                  label: _attenteCaptcha
                                      ? "Cochez d'abord le captcha"
                                      : 'Se connecter',
                                  icon: Icons.login,
                                  loading: _chargement,
                                  onPressed:
                                      _attenteCaptcha ? null : _seConnecter,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      "Pas de compte ? Contactez l'administrateur de votre établissement.",
                      textAlign: TextAlign.center,
                      style: textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// « Mot de passe oublié » : captcha puis envoi d'un nouveau mot de passe.
class _FeuilleReinitialisation extends StatefulWidget {
  const _FeuilleReinitialisation({required this.email, required this.depot});

  final String email;
  final AuthRepository depot;

  @override
  State<_FeuilleReinitialisation> createState() =>
      _FeuilleReinitialisationState();
}

class _FeuilleReinitialisationState extends State<_FeuilleReinitialisation> {
  String? _jeton;
  int _version = 0;
  bool _envoi = false;
  String? _erreur;

  Future<void> _envoyer() async {
    setState(() {
      _envoi = true;
      _erreur = null;
    });
    try {
      await widget.depot.reinitialiserMotDePasse(
        widget.email,
        jetonCaptcha: _jeton ?? '',
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _erreur = e.message;
        _jeton = null;
        _version++;
      });
    } finally {
      if (mounted) setState(() => _envoi = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String? erreur = _erreur;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        0,
        24,
        24 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Mot de passe oublié',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'Un nouveau mot de passe sera envoyé à ${widget.email}.',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          Center(
            child: CaptchaTurnstile(
              key: ValueKey<int>(_version),
              onJeton: (String jeton) => setState(() => _jeton = jeton),
              onErreur: (String message) =>
                  setState(() => _erreur = 'Captcha : $message'),
            ),
          ),
          const SizedBox(height: 16),
          if (erreur != null) ...[
            ErrorBanner(message: erreur),
            const SizedBox(height: 16),
          ],
          PrimaryButton(
            label: _jeton == null ? "Cochez d'abord le captcha" : 'Envoyer',
            icon: Icons.send_rounded,
            loading: _envoi,
            onPressed: _jeton == null ? null : _envoyer,
          ),
        ],
      ),
    );
  }
}
