import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../data/demo_data.dart';
import '../../data/demo_store.dart';
import '../widgets/app_background.dart';
import '../widgets/confetti_burst.dart';
import '../widgets/doctor_avatar.dart';

/// Confirmation de rendez-vous : confettis, coche animée, récapitulatif.
class BookingSuccessScreen extends StatefulWidget {
  const BookingSuccessScreen({super.key, required this.rdv});

  final DemoRdv rdv;

  @override
  State<BookingSuccessScreen> createState() => _BookingSuccessScreenState();
}

class _BookingSuccessScreenState extends State<BookingSuccessScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ondes;

  @override
  void initState() {
    super.initState();
    _ondes = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _ondes.dispose();
    super.dispose();
  }

  void _terminer(int onglet) {
    DemoStore.instance.allerA(onglet);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final DemoDoctor m = widget.rdv.medecin;

    return Scaffold(
      body: AppBackground(
        child: Stack(
          children: [
            const Positioned.fill(child: ConfettiBurst()),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const Spacer(flex: 2),
                    SizedBox(
                      width: 190,
                      height: 190,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          AnimatedBuilder(
                            animation: _ondes,
                            builder: (BuildContext context, Widget? child) {
                              final double t = _ondes.value;
                              return Stack(
                                alignment: Alignment.center,
                                children: [
                                  for (final double d in [t, (t + 0.5) % 1])
                                    Container(
                                      width: 100 + 86 * d,
                                      height: 100 + 86 * d,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: AppColors.primary
                                              .withValues(alpha: (1 - d) * 0.5),
                                          width: 2,
                                        ),
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
                          TweenAnimationBuilder<double>(
                            tween: Tween<double>(begin: 0, end: 1),
                            duration: const Duration(milliseconds: 900),
                            curve: Curves.elasticOut,
                            builder: (BuildContext context, double v, Widget? child) {
                              return Transform.scale(scale: v, child: child);
                            },
                            child: Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  colors: [AppColors.primary, AppColors.secondary],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withValues(alpha: 0.35),
                                    blurRadius: 24,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.check_rounded,
                                color: Colors.white,
                                size: 56,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Rendez-vous confirmé',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Nous vous rappellerons avant la consultation.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          DoctorAvatar(medecin: m, taille: 54, rayon: 16),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  m.nomComplet,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                  ),
                                ),
                                Text(
                                  m.specialite,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.event_rounded,
                                      size: 14,
                                      color: AppColors.primary,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      DateFr.complet(widget.rdv.date),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(flex: 3),
                    PrimaryButton(
                      label: 'Voir mon planning',
                      icon: Icons.calendar_month_rounded,
                      onPressed: () => _terminer(2),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: TextButton(
                        onPressed: () => _terminer(0),
                        child: const Text("Retour à l'accueil"),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
