import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/api/montre_ble_service.dart';
import '../../domain/surveillance_cardiaque.dart';
import 'dispatch_ui.dart';

/// Tableau de bord de la montre : batterie, signal, activité, rythme du jour.
class TableauMontre extends StatelessWidget {
  const TableauMontre({super.key, required this.montre});

  final MontreBleService montre;

  @override
  Widget build(BuildContext context) {
    final int? batterie = montre.batterie;
    final int? signal = montre.signal;
    final DateTime? synchro = montre.derniereSynchro;

    // Rythme du jour (relevés réels de la montre)
    final List<MesureCardiaque> jour = montre.relevesAujourdhui;
    String rythme = '—';
    String detailRythme = 'Aucun relevé aujourd\'hui';
    if (jour.isNotEmpty) {
      int min = jour.first.bpm;
      int max = jour.first.bpm;
      int somme = 0;
      for (final MesureCardiaque m in jour) {
        min = math.min(min, m.bpm);
        max = math.max(max, m.bpm);
        somme += m.bpm;
      }
      rythme = '${(somme / jour.length).round()} bpm';
      detailRythme = 'min $min · max $max · ${jour.length} relevé(s)';
    }

    final List<String> infos = [];
    final String? modele = montre.modele;
    final String? firmware = montre.firmware;
    if (modele != null) {
      infos.add(modele);
    }
    if (firmware != null) {
      infos.add('v$firmware');
    }

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.75,
      children: [
        _TuileMontre(
          icone: iconeBatterie(batterie, montre.enCharge),
          couleur: couleurBatterie(batterie, montre.enCharge),
          titre: 'Batterie',
          valeur: batterie == null ? '—' : '$batterie %',
          detail: batterie == null
              ? 'En attente de la montre'
              : (montre.enCharge ? 'En charge' : 'Sur batterie'),
        ),
        _TuileMontre(
          icone: Icons.bluetooth_connected,
          couleur: couleurSignal(signal),
          titre: 'Signal',
          valeur: qualiteSignal(signal),
          detail: signal == null ? '—' : '$signal dBm',
        ),
        _TuileMontre(
          icone: Icons.directions_walk,
          couleur: AppColors.primary,
          titre: 'Pas aujourd\'hui',
          valeur: milliers(montre.pasAujourdhui),
          detail: '${milliers(montre.caloriesAujourdhui)} kcal',
        ),
        _TuileMontre(
          icone: Icons.favorite_border,
          couleur: AppColors.danger,
          titre: 'Rythme moyen du jour',
          valeur: rythme,
          detail: detailRythme,
        ),
        _TuileMontre(
          icone: Icons.watch_outlined,
          couleur: AppColors.textSecondary,
          titre: 'Montre',
          valeur: montre.nomMontre,
          detail: infos.isEmpty ? 'Mibro C2' : infos.join(' · '),
        ),
        _TuileMontre(
          icone: Icons.sync,
          couleur: AppColors.textSecondary,
          titre: 'Dernière synchro',
          valeur: synchro == null ? '—' : DispatchUi.heure(synchro),
          detail: synchro == null ? '—' : DispatchUi.ilYa(synchro),
        ),
      ],
    );
  }

  static IconData iconeBatterie(int? niveau, bool enCharge) {
    if (enCharge) {
      return Icons.battery_charging_full;
    }
    if (niveau == null) {
      return Icons.battery_unknown;
    }
    if (niveau <= 15) {
      return Icons.battery_alert;
    }
    if (niveau >= 80) {
      return Icons.battery_full;
    }
    return Icons.battery_std;
  }

  static Color couleurBatterie(int? niveau, bool enCharge) {
    if (enCharge) {
      return AppColors.primary;
    }
    if (niveau == null) {
      return AppColors.textSecondary;
    }
    if (niveau <= 15) {
      return AppColors.danger;
    }
    if (niveau <= 30) {
      return AppColors.warning;
    }
    return AppColors.success;
  }

  static String qualiteSignal(int? rssi) {
    if (rssi == null) {
      return '—';
    }
    if (rssi >= -60) {
      return 'Excellent';
    }
    if (rssi >= -75) {
      return 'Bon';
    }
    if (rssi >= -90) {
      return 'Faible';
    }
    return 'Très faible';
  }

  static Color couleurSignal(int? rssi) {
    if (rssi == null) {
      return AppColors.textSecondary;
    }
    if (rssi >= -75) {
      return AppColors.success;
    }
    if (rssi >= -90) {
      return AppColors.warning;
    }
    return AppColors.danger;
  }

  /// 1247 → « 1 247 »
  static String milliers(int v) {
    final String s = v.toString();
    final StringBuffer sb = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) {
        sb.write(' ');
      }
      sb.write(s[i]);
    }
    return sb.toString();
  }
}

class _TuileMontre extends StatelessWidget {
  const _TuileMontre({
    required this.icone,
    required this.couleur,
    required this.titre,
    required this.valeur,
    required this.detail,
  });

  final IconData icone;
  final Color couleur;
  final String titre;
  final String valeur;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: couleur.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icone, size: 16, color: couleur),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  titre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
          const Spacer(),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              valeur,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
          ),
          Text(
            detail,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
