import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Compte à rebours « dans 18 h 28 min », mis à jour toutes les 30 s.
class CountdownChip extends StatefulWidget {
  const CountdownChip({super.key, required this.date, this.surFondSombre = false});

  final DateTime date;
  final bool surFondSombre;

  static String texte(DateTime date) {
    final Duration d = date.difference(DateTime.now());
    if (d.isNegative) {
      return 'Maintenant';
    }
    if (d.inDays >= 1) {
      return 'dans ${d.inDays} j ${d.inHours % 24} h';
    }
    if (d.inHours >= 1) {
      return 'dans ${d.inHours} h ${d.inMinutes % 60} min';
    }
    return 'dans ${d.inMinutes} min';
  }

  @override
  State<CountdownChip> createState() => _CountdownChipState();
}

class _CountdownChipState extends State<CountdownChip> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool sombre = widget.surFondSombre;
    final Color texte = sombre ? Colors.white : AppColors.danger;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: sombre ? AppColors.danger : AppColors.danger.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.schedule_rounded, size: 12, color: texte),
          const SizedBox(width: 4),
          Text(
            CountdownChip.texte(widget.date),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: texte,
            ),
          ),
        ],
      ),
    );
  }
}
