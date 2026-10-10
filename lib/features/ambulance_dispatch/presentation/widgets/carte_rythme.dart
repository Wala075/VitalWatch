import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/surveillance_cardiaque.dart';
import 'dispatch_ui.dart';

/// Carte sombre : dernière valeur + courbe des 3 dernières heures.
class CarteRythme extends StatelessWidget {
  const CarteRythme({
    super.key,
    required this.derniere,
    required this.etat,
    required this.mesures,
    required this.seuils,
    this.anomalies = 0,
  });

  final MesureCardiaque? derniere;
  final EtatRythme? etat;
  final List<MesureCardiaque> mesures;
  final SeuilsCardiaques seuils;
  final int anomalies;

  @override
  Widget build(BuildContext context) {
    final MesureCardiaque? m = derniere;
    final EtatRythme? e = etat;
    final bool normal = e == null || e == EtatRythme.normal;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Icon(Icons.favorite, color: normal ? AppColors.ecg : AppColors.danger, size: 30),
              const SizedBox(width: 10),
              Text(
                m == null ? '--' : '${m.bpm}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 48,
                  height: 1,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(left: 6, bottom: 4),
                child: Text('bpm', style: TextStyle(color: Colors.white70, fontSize: 16)),
              ),
              const Spacer(),
              if (e != null)
                Pastille(
                  libelle: e.libelle,
                  couleur: normal ? AppColors.ecg : AppColors.danger,
                  icone: normal ? Icons.check_circle_outline : Icons.warning_amber_rounded,
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            m == null
                ? 'Aucune mesure sur les 3 dernières heures'
                : '${DispatchUi.ilYa(m.date)} · ${m.simulee ? 'simulation' : (m.source.isEmpty ? 'montre' : m.source)}'
                    '${anomalies > 0 ? ' · $anomalies mesure(s) anormale(s) de suite' : ''}',
            style: const TextStyle(color: Colors.white60, fontSize: 12.5),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 130,
            width: double.infinity,
            child: CustomPaint(
              painter: CourbePainter(mesures: mesures, seuils: seuils),
            ),
          ),
          const SizedBox(height: 6),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('-3 h', style: TextStyle(color: Colors.white38, fontSize: 11)),
              Text('maintenant', style: TextStyle(color: Colors.white38, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}

/// Courbe du rythme (une série) + lignes de seuil pointillées.
class CourbePainter extends CustomPainter {
  CourbePainter({required this.mesures, required this.seuils});

  final List<MesureCardiaque> mesures;
  final SeuilsCardiaques seuils;

  @override
  void paint(Canvas canvas, Size size) {
    final DateTime fin = DateTime.now();
    final DateTime debut = fin.subtract(const Duration(hours: 3));
    int bas = seuils.min - 10;
    int haut = seuils.max + 20;
    for (final MesureCardiaque m in mesures) {
      bas = math.min(bas, m.bpm - 5);
      haut = math.max(haut, m.bpm + 5);
    }

    double x(DateTime d) {
      final double t = d.difference(debut).inSeconds / fin.difference(debut).inSeconds;
      return t.clamp(0.0, 1.0) * size.width;
    }

    double y(int bpm) => size.height - (bpm - bas) / (haut - bas) * size.height;

    // Seuils (pointillés) + étiquettes
    final Paint seuil = Paint()
      ..color = AppColors.danger.withValues(alpha: 0.7)
      ..strokeWidth = 1;
    for (final int v in [seuils.min, seuils.max]) {
      final double yy = y(v);
      for (double xx = 0; xx < size.width; xx += 8) {
        canvas.drawLine(Offset(xx, yy), Offset(math.min(xx + 4, size.width), yy), seuil);
      }
      final TextPainter tp = TextPainter(
        text: TextSpan(
          text: '$v',
          style: const TextStyle(color: Colors.white54, fontSize: 10),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(0, yy - tp.height - 1));
    }

    final List<MesureCardiaque> visibles = [];
    for (final MesureCardiaque m in mesures) {
      if (!m.date.isBefore(debut)) {
        visibles.add(m);
      }
    }
    if (visibles.isEmpty) {
      return;
    }

    final Path chemin = Path();
    for (int i = 0; i < visibles.length; i++) {
      final Offset p = Offset(x(visibles[i].date), y(visibles[i].bpm));
      if (i == 0) {
        chemin.moveTo(p.dx, p.dy);
      } else {
        chemin.lineTo(p.dx, p.dy);
      }
    }
    canvas.drawPath(
      chemin,
      Paint()
        ..color = AppColors.ecg
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round,
    );

    final MesureCardiaque der = visibles.last;
    final Offset point = Offset(x(der.date), y(der.bpm));
    final bool anormal = seuils.evaluer(der.bpm) != EtatRythme.normal;
    canvas.drawCircle(point, 6, Paint()..color = AppColors.ink);
    canvas.drawCircle(point, 4.5, Paint()..color = anormal ? AppColors.danger : AppColors.ecg);
  }

  @override
  bool shouldRepaint(CourbePainter ancien) => true;
}
