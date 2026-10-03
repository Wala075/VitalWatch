import 'package:flutter/material.dart';

import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared_providers/session.dart';
import '../widgets/ecg_painter.dart';

/// Écran de démarrage : tracé ECG, logo cœur avec ondes, titre, barre.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    );
    _c.addStatusListener((AnimationStatus statut) {
      if (statut == AnimationStatus.completed && mounted) {
        Navigator.pushReplacementNamed(
          context,
          Session.estConnecte ? AppRoutes.home : AppRoutes.login,
        );
      }
    });
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  double _intervalle(double debut, double fin) {
    final double v = (_c.value - debut) / (fin - debut);
    if (v < 0) return 0;
    if (v > 1) return 1;
    return v;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      body: AnimatedBuilder(
        animation: _c,
        builder: (BuildContext context, Widget? child) {
          final double ecg = Curves.easeInOut.transform(_intervalle(0.0, 0.42));
          final double ecgOpacite = 1 - 0.85 * _intervalle(0.40, 0.58);
          final double logo = Curves.elasticOut.transform(_intervalle(0.36, 0.64));
          final double logoOpacite = _intervalle(0.36, 0.46);
          final double texte = Curves.easeOut.transform(_intervalle(0.52, 0.78));
          final double barre = Curves.easeInOut.transform(_intervalle(0.05, 0.97));
          final double anneau1 = (_intervalle(0.45, 1.0) * 2.5) % 1;
          final double anneau2 = (anneau1 + 0.5) % 1;

          return Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -0.15),
                radius: 1.2,
                colors: [Color(0xFF15928D), AppColors.primaryDark, Color(0xFF052A29)],
                stops: [0.0, 0.55, 1.0],
              ),
            ),
            child: SafeArea(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Align(
                      alignment: const Alignment(0, -0.12),
                      child: Opacity(
                        opacity: ecgOpacite,
                        child: SizedBox(
                          height: 120,
                          width: double.infinity,
                          child: CustomPaint(
                            painter: EcgPainter(
                              couleur: Colors.white,
                              progression: ecg,
                              epaisseur: 2.6,
                              lueur: true,
                              battements: 2,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Align(
                    alignment: const Alignment(0, -0.12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 220,
                          height: 220,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              for (final double r in [anneau1, anneau2])
                                Opacity(
                                  opacity: (1 - r) * logoOpacite,
                                  child: Container(
                                    width: 96 + r * 120,
                                    height: 96 + r * 120,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white.withValues(alpha: 0.6),
                                        width: 1.5,
                                      ),
                                    ),
                                  ),
                                ),
                              Opacity(
                                opacity: logoOpacite,
                                child: Transform.scale(
                                  scale: logo,
                                  child: Container(
                                    width: 92,
                                    height: 92,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(28),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.25),
                                          blurRadius: 30,
                                          offset: const Offset(0, 12),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.favorite_rounded,
                                      color: AppColors.danger,
                                      size: 46,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Opacity(
                          opacity: texte,
                          child: Transform.translate(
                            offset: Offset(0, 18 * (1 - texte)),
                            child: const Column(
                              children: [
                                Text(
                                  'VitalWatch',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 36,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                SizedBox(height: 6),
                                Text(
                                  'Surveillance à distance des paramètres vitaux',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    left: 64,
                    right: 64,
                    bottom: 40,
                    child: Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: barre,
                            minHeight: 4,
                            backgroundColor: Colors.white24,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Préparation de votre espace santé…',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
