import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../../../../core/theme/app_colors.dart';
import '../../services/visio_service.dart';

/// Appel vidéo DANS l'application (Jitsi Meet affiché dans une WebView).
///
/// Utilisation : `await AppelVideoScreen.ouvrir(context, lien: ..., nom: ..., titre: ...)`
/// L'appel se termine quand l'utilisateur appuie sur « Raccrocher ».
class AppelVideoScreen extends StatefulWidget {
  const AppelVideoScreen({
    super.key,
    required this.lien,
    required this.nom,
    required this.titre,
  });

  /// Lien de la salle (champ lien_visio du RDV).
  final String lien;

  /// Nom affiché aux autres participants.
  final String nom;

  /// Ex : « Téléconsultation avec Dr Amine Ben Salah ».
  final String titre;

  /// Demande caméra + micro puis ouvre l'appel. Sur web / Windows (pas de
  /// WebView avec caméra), ouvre la salle dans le navigateur.
  static Future<void> ouvrir(
    BuildContext context, {
    required String lien,
    required String nom,
    required String titre,
  }) async {
    await VisioService.chargerConfig();
    final bool mobile = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);
    if (!mobile) {
      await launchUrl(
        Uri.parse(VisioService.urlAppel(lien, nom: nom)),
        mode: LaunchMode.externalApplication,
      );
      return;
    }

    final Map<Permission, PermissionStatus> statuts =
        await [Permission.camera, Permission.microphone].request();
    final bool ok = statuts.values.every((PermissionStatus s) => s.isGranted);
    if (!context.mounted) {
      return;
    }
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Autorisez la caméra et le micro pour la téléconsultation'),
          action: SnackBarAction(label: 'Réglages', onPressed: openAppSettings),
        ),
      );
      return;
    }
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => AppelVideoScreen(lien: lien, nom: nom, titre: titre),
      ),
    );
  }

  @override
  State<AppelVideoScreen> createState() => _AppelVideoScreenState();
}

class _AppelVideoScreenState extends State<AppelVideoScreen> {
  late final WebViewController _controller;
  int _progression = 0;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController(
      // La page Jitsi demande caméra + micro : on accepte (déjà autorisés).
      onPermissionRequest: (WebViewPermissionRequest request) => request.grant(),
    )
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int p) {
            if (mounted) {
              setState(() => _progression = p);
            }
          },
          onWebResourceError: (WebResourceError e) {
            if (mounted && (e.isForMainFrame ?? false)) {
              setState(() => _erreur = e.description);
            }
          },
        ),
      );

    final Object plateforme = _controller.platform;
    if (plateforme is AndroidWebViewController) {
      // Sinon le son de l'autre participant ne démarre pas tout seul.
      plateforme.setMediaPlaybackRequiresUserGesture(false);
    }
    _controller.loadRequest(
      Uri.parse(VisioService.urlAppel(widget.lien, nom: widget.nom)),
    );
  }

  Future<void> _raccrocher() async {
    // Quitte proprement la conférence avant de fermer l'écran.
    try {
      await _controller.runJavaScript(
        'try { APP.conference.hangup(); } catch (e) {}',
      );
    } catch (_) {}
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String? erreur = _erreur;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) {
          _raccrocher();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: AppColors.ink,
          foregroundColor: Colors.white,
          automaticallyImplyLeading: false,
          title: Row(
            children: [
              const Icon(Icons.videocam_rounded, color: AppColors.ecg),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.titre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ],
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
                onPressed: _raccrocher,
                icon: const Icon(Icons.call_end_rounded),
                label: const Text('Raccrocher'),
              ),
            ),
          ],
          bottom: _progression < 100
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(3),
                  child: LinearProgressIndicator(
                    value: _progression / 100,
                    minHeight: 3,
                    color: AppColors.ecg,
                    backgroundColor: Colors.white12,
                  ),
                )
              : null,
        ),
        body: erreur != null
            ? _Erreur(
                message: erreur,
                onReessayer: () {
                  setState(() => _erreur = null);
                  _controller.reload();
                },
              )
            : WebViewWidget(controller: _controller),
      ),
    );
  }
}

class _Erreur extends StatelessWidget {
  const _Erreur({required this.message, required this.onReessayer});

  final String message;
  final VoidCallback onReessayer;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded, color: Colors.white54, size: 56),
            const SizedBox(height: 12),
            Text(
              'Connexion à la visio impossible\n$message',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: onReessayer, child: const Text('Réessayer')),
          ],
        ),
      ),
    );
  }
}
