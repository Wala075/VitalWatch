import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../models/utilisateur.dart';
import '../../../../shared_providers/session.dart';
import '../../domain/rdv_manager.dart';
import '../../domain/rdv_models.dart';
import '../../domain/rdv_regles.dart';
import '../screens/appel_video_screen.dart';
import '../screens/consultation_screen.dart';
import '../screens/rdv_detail_screen.dart';
import 'rdv_widgets.dart';

/// Notifications in-app du module Rendez-vous, vérifiées toutes les 5 s
/// (placé autour de l'écran d'accueil, s'affiche au-dessus de toute page) :
/// - MÉDECIN : « appel urgent » d'un patient -> écran d'appel entrant,
///   « Répondre » ouvre l'appel vidéo dans l'app ;
/// - PATIENT : un médecin / le personnel lui a pris un RDV -> fenêtre
///   « Nouveau rendez-vous » avec « Voir ».
class AppelUrgentWatcher extends StatefulWidget {
  const AppelUrgentWatcher({super.key, required this.child});

  final Widget child;

  @override
  State<AppelUrgentWatcher> createState() => _AppelUrgentWatcherState();
}

class _AppelUrgentWatcherState extends State<AppelUrgentWatcher> {
  static const Duration _intervalle = Duration(seconds: 5);

  final RdvManager _manager = RdvManager();
  Timer? _timer;
  bool _occupe = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(_intervalle, (_) => _verifier());
    WidgetsBinding.instance.addPostFrameCallback((_) => _verifier());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _verifier() async {
    final Utilisateur? u = Session.utilisateur;
    if (_occupe || !mounted || u == null) {
      return;
    }
    if (u.role != Role.medecin && u.role != Role.patient) {
      return;
    }
    _occupe = true;
    try {
      if (u.role == Role.medecin) {
        final List<RdvDetail> appels = await _manager.appelsUrgentsEnAttente(u);
        for (final RdvDetail d in appels) {
          if (!mounted) {
            break;
          }
          await _afficher(d, u);
        }
      } else {
        final List<RdvDetail> nouveaux = await _manager.nouveauxRdvPourPatient(u);
        for (final RdvDetail d in nouveaux) {
          if (!mounted) {
            break;
          }
          await _afficherNouveauRdv(d, u);
        }
      }
    } catch (_) {
      // On réessaiera au prochain passage.
    } finally {
      _occupe = false;
    }
  }

  Future<void> _afficher(RdvDetail d, Utilisateur u) async {
    HapticFeedback.heavyImpact();
    SystemSound.play(SystemSoundType.alert);
    final bool? repondre = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Appel urgent',
      barrierColor: Colors.black54,
      pageBuilder: (BuildContext ctx, Animation<double> a1, Animation<double> a2) =>
          _AppelEntrant(detail: d),
    );
    if (!mounted || repondre != true) {
      return;
    }
    final int id = d.rdv.id ?? 0;

    if (d.rdv.type != TypeRdv.visio) {
      // Urgence présentielle : on ouvre simplement la fiche du RDV.
      await Navigator.push<void>(
        context,
        MaterialPageRoute<void>(
          builder: (_) => RdvDetailScreen(rdvId: id, utilisateur: u),
        ),
      );
      return;
    }

    try {
      await _manager.demarrer(id, u);
      final String lien = await _manager.lienVisio(d);
      if (!mounted) {
        return;
      }
      await AppelVideoScreen.ouvrir(
        context,
        lien: lien,
        nom: d.medecinNom,
        titre: 'Urgence · ${d.patientNom}',
      );
      if (!mounted) {
        return;
      }
      // Après l'appel : rédaction du compte-rendu.
      await Navigator.push<bool>(
        context,
        MaterialPageRoute<bool>(
          builder: (_) => ConsultationScreen(rdvId: id, utilisateur: u),
        ),
      );
    } catch (e) {
      if (mounted) {
        afficherErreur(context, e);
      }
    }
  }

  /// Patient : « Dr X vous a fixé un rendez-vous ».
  Future<void> _afficherNouveauRdv(RdvDetail d, Utilisateur u) async {
    HapticFeedback.mediumImpact();
    SystemSound.play(SystemSoundType.alert);
    final RendezVous r = d.rdv;
    final bool visio = r.type == TypeRdv.visio;
    final bool? voir = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        icon: const Icon(Icons.notifications_active_rounded,
            color: AppColors.primary, size: 40),
        title: const Text('Nouveau rendez-vous'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${d.medecinNom} vous a fixé un rendez-vous.',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            _Ligne(Icons.event_rounded, RdvFormat.complet(r.dateHeure)),
            _Ligne(
              visio ? Icons.videocam_rounded : Icons.local_hospital_rounded,
              visio ? 'Téléconsultation (visio)' : 'Présentiel${d.serviceNom == null ? '' : ' · ${d.serviceNom}'}',
            ),
            _Ligne(Icons.edit_note_rounded, r.motif),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('OK'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Voir le RDV'),
          ),
        ],
      ),
    );
    if (voir == true && mounted) {
      await Navigator.push<void>(
        context,
        MaterialPageRoute<void>(
          builder: (_) => RdvDetailScreen(rdvId: r.id ?? 0, utilisateur: u),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _Ligne extends StatelessWidget {
  const _Ligne(this.icon, this.texte);

  final IconData icon;
  final String texte;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(texte)),
        ],
      ),
    );
  }
}

/// Écran « appel entrant » (style appel téléphonique).
class _AppelEntrant extends StatefulWidget {
  const _AppelEntrant({required this.detail});

  final RdvDetail detail;

  @override
  State<_AppelEntrant> createState() => _AppelEntrantState();
}

class _AppelEntrantState extends State<_AppelEntrant>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);
  Timer? _vibreur;

  @override
  void initState() {
    super.initState();
    // Vibre toutes les 2 s tant que le médecin n'a pas répondu.
    _vibreur = Timer.periodic(const Duration(seconds: 2), (_) {
      HapticFeedback.heavyImpact();
    });
  }

  @override
  void dispose() {
    _vibreur?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final RdvDetail d = widget.detail;
    final bool visio = d.rdv.type == TypeRdv.visio;
    final String initiales = d.patientNom
        .split(' ')
        .where((String s) => s.isNotEmpty)
        .take(2)
        .map((String s) => s[0].toUpperCase())
        .join();

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF3A0D10), AppColors.ink],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 40, 24, 40),
            child: Column(
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.emergency_rounded, color: AppColors.danger),
                    SizedBox(width: 8),
                    Text(
                      'DEMANDE URGENTE',
                      style: TextStyle(
                        color: AppColors.danger,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  visio ? 'Appel vidéo entrant' : 'Patient urgent à recevoir aujourd\'hui',
                  style: const TextStyle(color: Colors.white70),
                ),
                const Spacer(),
                ScaleTransition(
                  scale: Tween<double>(begin: 0.92, end: 1.08).animate(_pulse),
                  child: Container(
                    width: 130,
                    height: 130,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.danger.withValues(alpha: 0.18),
                      border: Border.all(color: AppColors.danger, width: 3),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      initiales.isEmpty ? '?' : initiales,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 42,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  d.patientNom,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  d.rdv.motif,
                  textAlign: TextAlign.center,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 15),
                ),
                if (d.alerteRecente) ...[
                  const SizedBox(height: 10),
                  const Text(
                    'Alerte de suivi vital dans les dernières 48 h',
                    style: TextStyle(color: AppColors.warning),
                  ),
                ],
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _BoutonAppel(
                      couleur: AppColors.danger,
                      icon: Icons.call_end_rounded,
                      libelle: 'Plus tard',
                      onTap: () => Navigator.pop(context, false),
                    ),
                    _BoutonAppel(
                      couleur: AppColors.success,
                      icon: visio ? Icons.videocam_rounded : Icons.visibility_rounded,
                      libelle: visio ? 'Répondre' : 'Voir',
                      onTap: () => Navigator.pop(context, true),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  '« Plus tard » : la demande reste en tête de votre file du jour.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BoutonAppel extends StatelessWidget {
  const _BoutonAppel({
    required this.couleur,
    required this.icon,
    required this.libelle,
    required this.onTap,
  });

  final Color couleur;
  final IconData icon;
  final String libelle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: couleur,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: 74,
              height: 74,
              child: Icon(icon, color: Colors.white, size: 34),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(libelle, style: const TextStyle(color: Colors.white)),
      ],
    );
  }
}
