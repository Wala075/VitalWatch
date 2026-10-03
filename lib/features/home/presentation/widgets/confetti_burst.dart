import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Explosion de confettis (écran de confirmation).
class ConfettiBurst extends StatefulWidget {
  const ConfettiBurst({super.key});

  @override
  State<ConfettiBurst> createState() => _ConfettiBurstState();
}

class _ConfettiBurstState extends State<ConfettiBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  final List<_Confetti> _confettis = _generer();

  static List<_Confetti> _generer() {
    final math.Random r = math.Random(11);
    const List<Color> couleurs = [
      Color(0xFF0E7C7B),
      Color(0xFF2BA79B),
      Color(0xFFF5A524),
      Color(0xFFE5484D),
      Color(0xFF7C5CC4),
      Color(0xFF34D399),
    ];
    final List<_Confetti> liste = [];
    for (int i = 0; i < 70; i++) {
      liste.add(_Confetti(
        angle: r.nextDouble() * 2 * math.pi,
        vitesse: 0.35 + r.nextDouble() * 0.65,
        couleur: couleurs[i % couleurs.length],
        taille: 4 + r.nextDouble() * 6,
        rotation: r.nextDouble() * 6,
      ));
    }
    return liste;
  }

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (BuildContext context, Widget? child) {
          return CustomPaint(
            size: Size.infinite,
            painter: _ConfettiPainter(_confettis, _c.value),
          );
        },
      ),
    );
  }
}

class _Confetti {
  const _Confetti({
    required this.angle,
    required this.vitesse,
    required this.couleur,
    required this.taille,
    required this.rotation,
  });

  final double angle;
  final double vitesse;
  final Color couleur;
  final double taille;
  final double rotation;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.confettis, this.t);

  final List<_Confetti> confettis;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset centre = Offset(size.width / 2, size.height * 0.3);
    final double ease = Curves.easeOutCubic.transform(t);
    final double opacite = (1 - t).clamp(0.0, 1.0).toDouble();

    for (final _Confetti c in confettis) {
      final double distance = c.vitesse * ease * size.width * 0.55;
      final double x = centre.dx + math.cos(c.angle) * distance;
      final double y = centre.dy +
          math.sin(c.angle) * distance * 0.8 +
          t * t * size.height * 0.35;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(c.rotation * t * 4);
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset.zero,
          width: c.taille,
          height: c.taille * 0.6,
        ),
        Paint()..color = c.couleur.withValues(alpha: opacite),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) =>
      oldDelegate.t != t;
}
