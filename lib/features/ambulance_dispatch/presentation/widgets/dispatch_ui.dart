import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/models/ambulance.dart';
import '../../domain/models/intervention.dart';
import '../../domain/models/maintenance.dart';

/// Couleurs, icônes et formats communs aux écrans du module.
class DispatchUi {
  DispatchUi._();

  static const Color bleu = Color(0xFF2B8FB3);
  static const Color orange = Color(0xFFF97316);

  static Color gravite(Gravite g) {
    switch (g) {
      case Gravite.critique:
        return AppColors.danger;
      case Gravite.urgente:
        return orange;
      case Gravite.moderee:
        return AppColors.warning;
      case Gravite.faible:
        return bleu;
    }
  }

  static IconData iconeGravite(Gravite g) {
    switch (g) {
      case Gravite.critique:
        return Icons.emergency;
      case Gravite.urgente:
        return Icons.priority_high;
      case Gravite.moderee:
        return Icons.report_outlined;
      case Gravite.faible:
        return Icons.info_outline;
    }
  }

  static Color statutAmbulance(StatutAmbulance s) {
    switch (s) {
      case StatutAmbulance.disponible:
        return AppColors.success;
      case StatutAmbulance.enMission:
        return bleu;
      case StatutAmbulance.maintenance:
        return AppColors.warning;
      case StatutAmbulance.horsService:
        return AppColors.textSecondary;
    }
  }

  static IconData iconeStatutAmbulance(StatutAmbulance s) {
    switch (s) {
      case StatutAmbulance.disponible:
        return Icons.check_circle_outline;
      case StatutAmbulance.enMission:
        return Icons.navigation_outlined;
      case StatutAmbulance.maintenance:
        return Icons.build_outlined;
      case StatutAmbulance.horsService:
        return Icons.block;
    }
  }

  static Color statutIntervention(StatutIntervention s) {
    switch (s) {
      case StatutIntervention.enAttente:
        return AppColors.danger;
      case StatutIntervention.assignee:
        return AppColors.purple;
      case StatutIntervention.enRoute:
        return bleu;
      case StatutIntervention.surPlace:
        return orange;
      case StatutIntervention.transport:
        return AppColors.primary;
      case StatutIntervention.terminee:
        return AppColors.success;
      case StatutIntervention.annulee:
        return AppColors.textSecondary;
    }
  }

  static IconData iconeStatutIntervention(StatutIntervention s) {
    switch (s) {
      case StatutIntervention.enAttente:
        return Icons.hourglass_top;
      case StatutIntervention.assignee:
        return Icons.assignment_ind_outlined;
      case StatutIntervention.enRoute:
        return Icons.directions_car_filled_outlined;
      case StatutIntervention.surPlace:
        return Icons.place_outlined;
      case StatutIntervention.transport:
        return Icons.local_hospital_outlined;
      case StatutIntervention.terminee:
        return Icons.task_alt;
      case StatutIntervention.annulee:
        return Icons.cancel_outlined;
    }
  }

  static Color statutMaintenance(StatutMaintenance s) {
    switch (s) {
      case StatutMaintenance.planifiee:
        return bleu;
      case StatutMaintenance.enCours:
        return AppColors.warning;
      case StatutMaintenance.terminee:
        return AppColors.success;
    }
  }

  // ===== Formats =====

  /// 45 s · 12 min · 1 h 05
  static String duree(Duration d) {
    if (d.inSeconds < 60) {
      return '${d.inSeconds < 0 ? 0 : d.inSeconds} s';
    }
    if (d.inHours >= 1) {
      final String m = (d.inMinutes % 60).toString().padLeft(2, '0');
      return '${d.inHours} h $m';
    }
    return '${d.inMinutes} min';
  }

  static String heure(DateTime d) {
    final String h = d.hour.toString().padLeft(2, '0');
    final String m = d.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  static String dateHeure(DateTime d) => '${Formatters.date(d)} · ${heure(d)}';

  /// 850 m · 2,4 km
  static String distance(double km) {
    if (km < 1) {
      return '${(km * 1000).round()} m';
    }
    return '${km.toStringAsFixed(1).replaceAll('.', ',')} km';
  }

  /// 121450 → 121 450 km
  static String kilometrage(int km) => '${_milliers(km)} km';

  static String cout(double dt) => '${_milliers(dt.round())} DT';

  static String ilYa(DateTime d) {
    final Duration e = DateTime.now().difference(d);
    if (e.inMinutes < 1) {
      return "à l'instant";
    }
    if (e.inHours < 1) {
      return 'il y a ${e.inMinutes} min';
    }
    if (e.inDays < 1) {
      return 'il y a ${e.inHours} h';
    }
    return 'le ${Formatters.date(d)}';
  }

  static String _milliers(int v) {
    final String s = v.abs().toString();
    final StringBuffer sb = StringBuffer(v < 0 ? '-' : '');
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) {
        sb.write(' ');
      }
      sb.write(s[i]);
    }
    return sb.toString();
  }

  static void snack(BuildContext context, String message, {bool erreur = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: erreur ? AppColors.danger : null,
      ));
  }
}

/// Pastille d'état : icône + libellé (jamais la couleur seule).
class Pastille extends StatelessWidget {
  const Pastille({
    super.key,
    required this.libelle,
    required this.couleur,
    this.icone,
    this.plein = false,
  });

  final String libelle;
  final Color couleur;
  final IconData? icone;
  final bool plein;

  @override
  Widget build(BuildContext context) {
    final IconData? i = icone;
    final Color texte = plein ? Colors.white : couleur;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: plein ? couleur : couleur.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (i != null) ...[
            Icon(i, size: 13, color: texte),
            const SizedBox(width: 4),
          ],
          Text(
            libelle,
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: texte),
          ),
        ],
      ),
    );
  }
}

class PastilleGravite extends StatelessWidget {
  const PastilleGravite(this.gravite, {super.key, this.plein = false});

  final Gravite gravite;
  final bool plein;

  @override
  Widget build(BuildContext context) {
    return Pastille(
      libelle: gravite.libelle,
      couleur: DispatchUi.gravite(gravite),
      icone: DispatchUi.iconeGravite(gravite),
      plein: plein,
    );
  }
}

class PastilleStatutAmbulance extends StatelessWidget {
  const PastilleStatutAmbulance(this.statut, {super.key});

  final StatutAmbulance statut;

  @override
  Widget build(BuildContext context) {
    return Pastille(
      libelle: statut.libelle,
      couleur: DispatchUi.statutAmbulance(statut),
      icone: DispatchUi.iconeStatutAmbulance(statut),
    );
  }
}

class PastilleStatutIntervention extends StatelessWidget {
  const PastilleStatutIntervention(this.statut, {super.key});

  final StatutIntervention statut;

  @override
  Widget build(BuildContext context) {
    return Pastille(
      libelle: statut.libelle,
      couleur: DispatchUi.statutIntervention(statut),
      icone: DispatchUi.iconeStatutIntervention(statut),
    );
  }
}

/// Icône + texte secondaire (ex : « 3 équipiers »).
class Info extends StatelessWidget {
  const Info({super.key, required this.icone, required this.texte, this.couleur});

  final IconData icone;
  final String texte;
  final Color? couleur;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icone, size: 15, color: couleur ?? AppColors.textSecondary),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            texte,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12.5, color: couleur ?? AppColors.textSecondary),
          ),
        ),
      ],
    );
  }
}

/// Bloc titré d'un formulaire ou d'une fiche.
class Section extends StatelessWidget {
  const Section({
    super.key,
    required this.titre,
    required this.icone,
    required this.children,
    this.action,
  });

  final String titre;
  final IconData icone;
  final List<Widget> children;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final Widget? a = action;
    final List<Widget> contenu = [];
    for (int i = 0; i < children.length; i++) {
      if (i > 0) {
        contenu.add(const SizedBox(height: 12));
      }
      contenu.add(children[i]);
    }
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icone, size: 20, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    titre,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                if (a != null) a,
              ],
            ),
            const SizedBox(height: 14),
            ...contenu,
          ],
        ),
      ),
    );
  }
}
