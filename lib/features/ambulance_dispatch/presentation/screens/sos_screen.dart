import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../shared_providers/session.dart';
import '../../domain/dispatch_manager.dart';
import '../../domain/dispatch_models.dart';
import '../../domain/models/intervention.dart';
import '../providers/dispatch_controller.dart';
import '../widgets/dispatch_ui.dart';
import '../widgets/ecoute_vocale.dart';
import 'intervention_detail_screen.dart';
import 'surveillance_cardiaque_screen.dart';
import 'tabs/interventions_tab.dart';

/// Vue patient : bouton SOS ou appel vocal « help » (position GPS →
/// intervention critique + dispatch automatique) et suivi de l'ambulance envoyée.
class SosScreen extends StatefulWidget {
  const SosScreen({super.key});

  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen> with SingleTickerProviderStateMixin {
  final DispatchController _ctrl = DispatchController.instance;
  late final AnimationController _pulsation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();
  bool _envoi = false;

  int? get _patientId => Session.utilisateur?.refId;

  @override
  void dispose() {
    _pulsation.dispose();
    super.dispose();
  }

  InterventionDetail? get _maDemande {
    final int? pid = _patientId;
    for (final InterventionDetail d in _ctrl.ouvertes) {
      if (pid != null && d.intervention.patientId == pid) {
        return d;
      }
    }
    return null;
  }

  Future<void> _sos() async {
    final bool ok = await showConfirmDialog(
      context,
      titre: 'Appeler une ambulance ?',
      message: 'Votre position GPS sera envoyée et l\'ambulance la plus proche '
          'sera dépêchée immédiatement.',
      confirmer: 'Envoyer le SOS',
      danger: true,
    );
    if (!ok || !mounted) {
      return;
    }
    await _envoyer();
  }

  /// [vocal] : appel à l'aide à la voix → aucune question, position de
  /// démonstration si le GPS ne répond pas.
  Future<void> _envoyer({bool vocal = false}) async {
    if (_envoi) {
      return;
    }
    setState(() => _envoi = true);
    try {
      LatLng position;
      try {
        position = await _ctrl.gps.positionActuelle();
      } on DispatchException catch (e) {
        if (!mounted) {
          return;
        }
        final bool demo = vocal || await _proposerDemo(e.message);
        if (!demo) {
          return;
        }
        position = DispatchManager.centreZone;
      }
      if (!DispatchManager.dansZone(position)) {
        if (!mounted) {
          return;
        }
        final bool demo = vocal ||
            await _proposerDemo(
              'Votre position (${position.latitude.toStringAsFixed(3)}, '
              '${position.longitude.toStringAsFixed(3)}) est hors de la zone couverte.',
            );
        if (!demo) {
          return;
        }
        position = DispatchManager.centreZone;
      }
      final ResultatDispatch r =
          await _ctrl.declencherSos(position, patientId: _patientId);
      if (mounted) {
        DispatchUi.snack(
          context,
          r.assignee ? 'Ambulance envoyée : ${r.ambulance?.immatriculation}' : (r.justification ?? 'SOS enregistré'),
        );
      }
    } on DispatchException catch (e) {
      if (mounted) {
        DispatchUi.snack(context, e.message, erreur: true);
      }
    } finally {
      if (mounted) {
        setState(() => _envoi = false);
      }
    }
  }

  /// Émulateur / hors zone : utiliser une position de démonstration à Sousse.
  Future<bool> _proposerDemo(String raison) {
    return showConfirmDialog(
      context,
      titre: 'Position indisponible',
      message: '$raison\n\nUtiliser une position de démonstration (Sousse centre) ?',
      confirmer: 'Utiliser Sousse',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Urgence ambulance')),
      body: ListenableBuilder(
        listenable: _ctrl,
        builder: (BuildContext context, Widget? _) {
          final InterventionDetail? demande = _maDemande;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (demande == null) ...[
                const SizedBox(height: 20),
                const Text(
                  "En cas d'urgence vitale, appuyez sur SOS",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Votre position est envoyée au centre de régulation',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 40),
                Center(child: _boutonSos()),
                const SizedBox(height: 28),
                CarteEcouteVocale(
                  onAlerte: () => _envoyer(vocal: true),
                  peutAlerter: () => !_envoi,
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () => Navigator.push<void>(
                    context,
                    MaterialPageRoute(builder: (_) => const SurveillanceCardiaqueScreen()),
                  ),
                  icon: const Icon(Icons.watch_outlined),
                  label: const Text('Surveiller mon rythme cardiaque (montre)'),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Appel direct SAMU : 190',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.danger),
                ),
              ] else ...[
                const Text(
                  'Votre demande de secours',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                CarteIntervention(
                  detail: demande,
                  suivi: _ctrl.suiviDe(demande.intervention.id ?? -1),
                  onTap: () => _suivre(demande.intervention),
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: () => _suivre(demande.intervention),
                  icon: const Icon(Icons.map_outlined),
                  label: const Text("Suivre l'ambulance sur la carte"),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  void _suivre(Intervention i) {
    final int? id = i.id;
    if (id == null) {
      return;
    }
    Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => InterventionDetailScreen(interventionId: id)),
    );
  }

  Widget _boutonSos() {
    return AnimatedBuilder(
      animation: _pulsation,
      builder: (BuildContext context, Widget? child) {
        final double t = _pulsation.value;
        return Container(
          width: 230,
          height: 230,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.danger.withValues(alpha: 0.18 * (1 - t)),
          ),
          child: Container(
            width: 170 + 40 * t,
            height: 170 + 40 * t,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.danger.withValues(alpha: 0.12 * (1 - t)),
            ),
            child: child,
          ),
        );
      },
      child: SizedBox(
        width: 160,
        height: 160,
        child: ElevatedButton(
          onPressed: _envoi ? null : _sos,
          style: ElevatedButton.styleFrom(
            shape: const CircleBorder(),
            backgroundColor: AppColors.danger,
            foregroundColor: Colors.white,
            elevation: 8,
          ),
          child: _envoi
              ? const CircularProgressIndicator(color: Colors.white)
              : const Text(
                  'SOS',
                  style: TextStyle(fontSize: 44, fontWeight: FontWeight.w900, letterSpacing: 2),
                ),
        ),
      ),
    );
  }
}
