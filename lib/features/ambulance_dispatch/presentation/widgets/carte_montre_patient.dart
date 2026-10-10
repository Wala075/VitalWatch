import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/api/montre_ble_service.dart';
import '../../domain/surveillance_cardiaque.dart';
import '../providers/montre_controller.dart';
import '../screens/surveillance_cardiaque_screen.dart';
import 'dispatch_ui.dart';
import 'tableau_montre.dart';

/// Accueil du patient : vraies données de sa montre Mibro C2 (rythme exact,
/// pas, calories, batterie), synchronisées toutes les 30 s par
/// [MontreController]. Touchez la carte pour le détail.
class CarteMontrePatient extends StatelessWidget {
  const CarteMontrePatient({super.key});

  static const int objectifPas = 10000;

  @override
  Widget build(BuildContext context) {
    final MontreController c = MontreController.instance;
    return ListenableBuilder(
      listenable: c,
      builder: (BuildContext context, Widget? _) {
        final MontreBleService m = c.montre;
        final EtatMontre? etat = c.etat;
        final bool connectee = etat == EtatMontre.connectee;
        final MesureCardiaque? der = c.derniere;
        final EtatRythme? e = c.etatRythme;
        final bool anormal = e != null && e != EtatRythme.normal;
        final int pas = m.pasAujourdhui;
        final int? batterie = m.batterie;
        final DateTime? lu = c.derniereLecture;

        void ouvrir() => Navigator.push<void>(
              context,
              MaterialPageRoute(builder: (_) => const SurveillanceCardiaqueScreen()),
            );

        return Column(
          children: [
            SizedBox(
              height: 150,
              child: Row(
                children: [
                  Expanded(
                    child: _Tuile(
                      icone: Icons.favorite_rounded,
                      couleur: AppColors.danger,
                      titre: 'Cœur',
                      onTap: ouvrir,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                der == null ? '--' : '${der.bpm}',
                                style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                  color: anormal ? AppColors.danger : AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Padding(
                                padding: EdgeInsets.only(bottom: 4),
                                child: Text(
                                  'bpm',
                                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            der == null
                                ? 'Pas de mesure'
                                : '${e?.libelle ?? ''} · ${DispatchUi.ilYa(der.date)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: anormal ? AppColors.danger : AppColors.textSecondary,
                            ),
                          ),
                          const Spacer(),
                          SizedBox(
                            height: 30,
                            width: double.infinity,
                            child: CustomPaint(painter: _MiniCourbe(c.mesures)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _Tuile(
                      icone: Icons.directions_walk_rounded,
                      couleur: AppColors.primary,
                      titre: 'Pas',
                      onTap: ouvrir,
                      child: Column(
                        children: [
                          Expanded(
                            child: AspectRatio(
                              aspectRatio: 1,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  SizedBox.expand(
                                    child: CircularProgressIndicator(
                                      value: math.min(pas / objectifPas, 1.0),
                                      strokeWidth: 7,
                                      strokeCap: StrokeCap.round,
                                      backgroundColor: AppColors.surfaceGrey,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: FittedBox(
                                      child: Text(
                                        TableauMontre.milliers(pas),
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${TableauMontre.milliers(m.caloriesAujourdhui)} kcal',
                            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _Tuile(
                      icone: TableauMontre.iconeBatterie(batterie, m.enCharge),
                      couleur: TableauMontre.couleurBatterie(batterie, m.enCharge),
                      titre: 'Montre',
                      onTap: ouvrir,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            batterie == null ? '--' : '$batterie %',
                            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
                          ),
                          Text(
                            batterie == null
                                ? 'Batterie'
                                : (m.enCharge ? 'En charge' : 'Batterie'),
                            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                          ),
                          const Spacer(),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: batterie == null ? 0 : batterie / 100,
                              minHeight: 6,
                              backgroundColor: AppColors.surfaceGrey,
                              color: TableauMontre.couleurBatterie(batterie, m.enCharge),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: ouvrir,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
                  child: Row(
                    children: [
                      etat == null
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              connectee ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                              size: 18,
                              color: connectee ? AppColors.success : AppColors.danger,
                            ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          etat == null
                              ? 'Recherche de la montre…'
                              : (connectee
                                  ? '${m.nomMontre} · synchro '
                                      '${lu == null ? '…' : DispatchUi.heure(lu)} · toutes les 30 s'
                                  : etat.libelle),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ),
                      if (etat != null && !connectee && etat != EtatMontre.indisponible)
                        TextButton(onPressed: c.connecter, child: const Text('Connecter'))
                      else
                        const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Tuile extends StatelessWidget {
  const _Tuile({
    required this.icone,
    required this.couleur,
    required this.titre,
    required this.onTap,
    required this.child,
  });

  final IconData icone;
  final Color couleur;
  final String titre;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icone, size: 16, color: couleur),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      titre,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(child: child),
            ],
          ),
        ),
      ),
    );
  }
}

/// Petite courbe des vraies mesures des 3 dernières heures.
class _MiniCourbe extends CustomPainter {
  _MiniCourbe(this.mesures);

  final List<MesureCardiaque> mesures;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint trait = Paint()
      ..color = AppColors.danger
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;
    if (mesures.length < 2) {
      canvas.drawLine(
        Offset(0, size.height / 2),
        Offset(size.width, size.height / 2),
        trait..color = AppColors.surfaceGrey,
      );
      return;
    }
    int bas = mesures.first.bpm;
    int haut = mesures.first.bpm;
    for (final MesureCardiaque m in mesures) {
      bas = math.min(bas, m.bpm);
      haut = math.max(haut, m.bpm);
    }
    bas -= 5;
    haut += 5;
    final Path chemin = Path();
    for (int i = 0; i < mesures.length; i++) {
      final double x = i / (mesures.length - 1) * size.width;
      final double y = size.height - (mesures[i].bpm - bas) / (haut - bas) * size.height;
      if (i == 0) {
        chemin.moveTo(x, y);
      } else {
        chemin.lineTo(x, y);
      }
    }
    canvas.drawPath(chemin, trait);
  }

  @override
  bool shouldRepaint(_MiniCourbe ancien) => true;
}
