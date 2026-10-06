import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../models/utilisateur.dart';
import '../../../../../shared_providers/session.dart';
import '../../../../ambulance_dispatch/presentation/widgets/sante_montre.dart';
import '../../../data/demo_data.dart';
import '../../../data/demo_store.dart';
import '../../widgets/ecg_painter.dart';
import '../../widgets/page_title.dart';

class HealthTab extends StatefulWidget {
  const HealthTab({super.key});

  @override
  State<HealthTab> createState() => _HealthTabState();
}

class _HealthTabState extends State<HealthTab> with TickerProviderStateMixin {
  final DemoStore _store = DemoStore.instance;
  final math.Random _random = math.Random();

  late final AnimationController _ecg;
  late final AnimationController _respiration;
  Timer? _timerBpm;

  int _bpm = 72;
  bool _seance = false;

  /// Patient : vraies données de sa montre (module 3) au lieu de la démo.
  bool get _patient => Session.utilisateur?.role == Role.patient;
  int _jourChoisi = DateTime.now().weekday - 1;

  @override
  void initState() {
    super.initState();
    _ecg = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat();
    _respiration = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8), // 4 s inspiration + 4 s expiration
    );
    if (!_patient) {
      _timerBpm = Timer.periodic(const Duration(seconds: 2), (_) {
        if (mounted) {
          setState(() => _bpm = 68 + _random.nextInt(10));
        }
      });
    }
  }

  @override
  void dispose() {
    _timerBpm?.cancel();
    _ecg.dispose();
    _respiration.dispose();
    super.dispose();
  }

  void _basculerSeance() {
    if (_seance) {
      _respiration.stop();
      _respiration.reset();
    } else {
      _respiration.repeat();
    }
    setState(() => _seance = !_seance);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
        children: [
          const PageTitle(
            surtitre: 'Votre',
            titre: 'Santé',
            padding: EdgeInsets.fromLTRB(0, 12, 0, 14),
          ),
          if (_patient) ...[
            const CarteCoeurMontre(),
            const SizedBox(height: 14),
            const CarteDonneesMontre(),
          ] else
            _carteCoeur(),
          const SizedBox(height: 14),
          ListenableBuilder(
            listenable: _store,
            builder: (BuildContext context, Widget? child) => _carteEau(),
          ),
          const SizedBox(height: 14),
          _carteRespiration(),
          const SizedBox(height: 14),
          if (_patient) const CartePasDuJour() else _carteSemaine(),
        ],
      ),
    );
  }

  // ------------------------------------------------- fréquence cardiaque
  Widget _carteCoeur() {
    return Container(
      height: 200,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Fréquence cardiaque',
                style: TextStyle(color: Colors.white60, fontSize: 13),
              ),
              const Spacer(),
              AnimatedBuilder(
                animation: _ecg,
                builder: (BuildContext context, Widget? child) => Opacity(
                  opacity: 0.4 + 0.6 * (0.5 + 0.5 * math.sin(_ecg.value * 2 * math.pi)),
                  child: child,
                ),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.danger,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'EN DIRECT',
                style: TextStyle(
                  color: AppColors.danger,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                transitionBuilder: (Widget child, Animation<double> anim) =>
                    FadeTransition(opacity: anim, child: child),
                child: Text(
                  '$_bpm',
                  key: ValueKey<int>(_bpm),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 46,
                    height: 1,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              const Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Text(
                  'bpm',
                  style: TextStyle(color: Colors.white60, fontSize: 14),
                ),
              ),
              const Spacer(),
              AnimatedBuilder(
                animation: _ecg,
                builder: (BuildContext context, Widget? child) {
                  final double v = _ecg.value;
                  final double echelle =
                      v < 0.15 ? 1 + 0.18 * math.sin(v / 0.15 * math.pi) : 1;
                  return Transform.scale(scale: echelle, child: child);
                },
                child: const Icon(
                  Icons.favorite_rounded,
                  color: AppColors.danger,
                  size: 34,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: AnimatedBuilder(
              animation: _ecg,
              builder: (BuildContext context, Widget? child) => CustomPaint(
                size: Size.infinite,
                painter: EcgPainter(
                  couleur: AppColors.ecg,
                  phase: _ecg.value,
                  epaisseur: 2.2,
                  lueur: true,
                  battements: 3,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------- eau
  Widget _carteEau() {
    final int verres = _store.verresEau;
    const int objectif = DemoStore.objectifVerres;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            height: 100,
            child: AnimatedBuilder(
              animation: _ecg,
              builder: (BuildContext context, Widget? child) {
                return TweenAnimationBuilder<double>(
                  tween: Tween<double>(end: verres / objectif),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOutCubic,
                  builder: (BuildContext context, double niveau, Widget? c) {
                    return CustomPaint(
                      painter: _VerrePainter(niveau: niveau, vague: _ecg.value),
                    );
                  },
                );
              },
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Eau',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$verres',
                      style: const TextStyle(fontSize: 34, height: 1.1, fontWeight: FontWeight.w800),
                    ),
                    const Padding(
                      padding: EdgeInsets.only(bottom: 5, left: 4),
                      child: Text(
                        '/ $objectif verres',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
                Text(
                  '${verres * 250} ml sur ${objectif * 250} ml',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _PetitBouton(
                      icon: Icons.remove_rounded,
                      onTap: _store.retirerVerre,
                    ),
                    const SizedBox(width: 8),
                    _PetitBouton(
                      icon: Icons.add_rounded,
                      plein: true,
                      onTap: _store.ajouterVerre,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------- respiration
  Widget _carteRespiration() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.indigo, AppColors.indigoDark],
        ),
      ),
      child: Column(
        children: [
          const Row(
            children: [
              Text(
                'Respiration',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              Spacer(),
              Text(
                'Rythme 4 - 4',
                style: TextStyle(color: Colors.white60, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 190,
            child: AnimatedBuilder(
              animation: _respiration,
              builder: (BuildContext context, Widget? child) {
                final double t = _respiration.value;
                double echelle = 0.8;
                String texte = 'Prêt';
                if (_seance) {
                  if (t < 0.5) {
                    echelle = 0.7 + 0.3 * Curves.easeInOut.transform(t * 2);
                    texte = 'Inspirez';
                  } else {
                    echelle = 1.0 - 0.3 * Curves.easeInOut.transform((t - 0.5) * 2);
                    texte = 'Expirez';
                  }
                }
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 180 * echelle,
                      height: 180 * echelle,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.10),
                      ),
                    ),
                    Container(
                      width: 148 * echelle,
                      height: 148 * echelle,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.16),
                      ),
                    ),
                    Container(
                      width: 118 * echelle,
                      height: 118 * echelle,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withValues(alpha: 0.35),
                            blurRadius: 30,
                          ),
                        ],
                      ),
                      child: Text(
                        texte,
                        style: const TextStyle(
                          color: AppColors.indigoDark,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              onPressed: _basculerSeance,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.18),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(_seance ? 'Arrêter' : 'Commencer la séance'),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------- semaine
  Widget _carteSemaine() {
    const List<double> pas = DemoData.pasSemaine;
    double max = 0;
    for (final double p in pas) {
      if (p > max) {
        max = p;
      }
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          const Row(
            children: [
              Text(
                'Cette semaine',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
              Spacer(),
              Text(
                'Pas (milliers)',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 150,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (int i = 0; i < pas.length; i++)
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() => _jourChoisi = i),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          AnimatedOpacity(
                            duration: const Duration(milliseconds: 200),
                            opacity: i == _jourChoisi ? 1 : 0,
                            child: Text(
                              pas[i].toStringAsFixed(1),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOutCubic,
                            height: 100 * pas[i] / max,
                            margin: const EdgeInsets.symmetric(horizontal: 7),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: i == _jourChoisi
                                  ? null
                                  : AppColors.primary.withValues(alpha: 0.14),
                              gradient: i == _jourChoisi
                                  ? const LinearGradient(
                                      begin: Alignment.bottomCenter,
                                      end: Alignment.topCenter,
                                      colors: [AppColors.primaryDark, AppColors.secondary],
                                    )
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            DemoData.joursSemaine[i],
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight:
                                  i == _jourChoisi ? FontWeight.w800 : FontWeight.w500,
                              color: i == _jourChoisi
                                  ? AppColors.textPrimary
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PetitBouton extends StatelessWidget {
  const _PetitBouton({required this.icon, required this.onTap, this.plein = false});

  final IconData icon;
  final VoidCallback onTap;
  final bool plein;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: plein ? AppColors.primary : AppColors.surfaceGrey,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: SizedBox(
          width: 40,
          height: 36,
          child: Icon(icon, color: plein ? Colors.white : AppColors.textPrimary),
        ),
      ),
    );
  }
}

/// Verre d'eau qui se remplit avec une petite vague.
class _VerrePainter extends CustomPainter {
  _VerrePainter({required this.niveau, required this.vague});

  final double niveau;
  final double vague;

  @override
  void paint(Canvas canvas, Size size) {
    final Path verre = Path()
      ..moveTo(size.width * 0.06, 0)
      ..lineTo(size.width * 0.94, 0)
      ..lineTo(size.width * 0.80, size.height)
      ..lineTo(size.width * 0.20, size.height)
      ..close();

    canvas.save();
    canvas.clipPath(verre);
    canvas.drawPath(verre, Paint()..color = AppColors.mint);

    final double hauteur = size.height * niveau.clamp(0.0, 1.0);
    final double haut = size.height - hauteur;
    final Path eau = Path()..moveTo(0, size.height);
    for (double x = 0; x <= size.width; x += 2) {
      final double y =
          haut + math.sin(x / size.width * 2 * math.pi + vague * 2 * math.pi) * 3;
      eau.lineTo(x, y);
    }
    eau
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(
      eau,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.secondary, AppColors.primaryDark],
        ).createShader(Offset.zero & size),
    );
    canvas.restore();

    canvas.drawPath(
      verre,
      Paint()
        ..color = AppColors.primary.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _VerrePainter oldDelegate) =>
      oldDelegate.niveau != niveau || oldDelegate.vague != vague;
}
