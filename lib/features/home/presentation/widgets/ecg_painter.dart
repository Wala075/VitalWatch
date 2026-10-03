import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Tracé ECG (électrocardiogramme).
/// [progression] : partie dessinée de 0 à 1 (animation d'apparition).
/// [phase] : décalage horizontal de 0 à 1 (défilement continu).
class EcgPainter extends CustomPainter {
  EcgPainter({
    required this.couleur,
    this.progression = 1,
    this.phase = 0,
    this.epaisseur = 2,
    this.lueur = false,
    this.battements,
  });

  final Color couleur;
  final double progression;
  final double phase;
  final double epaisseur;
  final bool lueur;
  final int? battements;

  // Un battement normalisé : x de 0 à 1, y de -1 (haut) à 1 (bas).
  static const List<Offset> _battement = [
    Offset(0.00, 0),
    Offset(0.30, 0),
    Offset(0.34, -0.12),
    Offset(0.38, 0),
    Offset(0.44, 0),
    Offset(0.47, 0.18),
    Offset(0.50, -1.0),
    Offset(0.53, 0.45),
    Offset(0.56, 0),
    Offset(0.66, 0),
    Offset(0.72, -0.22),
    Offset(0.78, 0),
    Offset(1.00, 0),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) {
      return;
    }
    final int n =
        battements ?? math.max(1, (size.width / (size.height * 2.2)).round());
    final double largeur = size.width / n;
    final double milieu = size.height / 2;
    final double amplitude = size.height * 0.45;
    final double decalage = (phase % 1) * largeur;

    final Path path = Path();
    bool premier = true;
    for (int b = 0; b <= n + 1; b++) {
      for (final Offset p in _battement) {
        final double x = (b + p.dx) * largeur - decalage;
        final double y = milieu + p.dy * amplitude;
        if (premier) {
          path.moveTo(x, y);
          premier = false;
        } else {
          path.lineTo(x, y);
        }
      }
    }

    final double visible = size.width * progression.clamp(0.0, 1.0);
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, visible, size.height));
    if (lueur) {
      canvas.drawPath(
        path,
        Paint()
          ..color = couleur.withValues(alpha: 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = epaisseur * 3
          ..strokeJoin = StrokeJoin.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = couleur
        ..style = PaintingStyle.stroke
        ..strokeWidth = epaisseur
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant EcgPainter oldDelegate) {
    return oldDelegate.progression != progression ||
        oldDelegate.phase != phase ||
        oldDelegate.couleur != couleur;
  }
}
