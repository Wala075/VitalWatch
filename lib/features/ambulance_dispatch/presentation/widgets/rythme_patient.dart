import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/rythme_repository.dart';
import '../../domain/suivi_cardiaque.dart';
import '../../domain/surveillance_cardiaque.dart';
import '../screens/suivi_cardiaque_screen.dart';
import 'dispatch_ui.dart';

/// « Rythme du patient » dans une mission (ambulancier, régulation) :
/// dernière mesure envoyée par la montre du patient, relue toutes les 30 s.
class RythmePatient extends StatefulWidget {
  const RythmePatient({super.key, required this.patientId});

  final int patientId;

  @override
  State<RythmePatient> createState() => _RythmePatientState();
}

class _RythmePatientState extends State<RythmePatient> {
  final RythmeRepository _rythme = RythmeRepository();
  SuiviPatient? _suivi;
  List<MesureCardiaque> _heure = [];
  Timer? _minuterie;

  @override
  void initState() {
    super.initState();
    _charger();
    _minuterie = Timer.periodic(frequenceSuiviCardiaque, (_) => _charger());
  }

  @override
  void dispose() {
    _minuterie?.cancel();
    super.dispose();
  }

  Future<void> _charger() async {
    try {
      final SuiviPatient? s = await _rythme.resume(widget.patientId);
      final List<MesureCardiaque> h =
          await _rythme.historique(widget.patientId, periode: const Duration(hours: 1));
      if (mounted) {
        setState(() {
          _suivi = s;
          _heure = h;
        });
      }
    } catch (_) {
      // Carte facultative : on garde la dernière valeur affichée.
    }
  }

  @override
  Widget build(BuildContext context) {
    final SuiviPatient? s = _suivi;
    if (s == null) {
      return const SizedBox.shrink();
    }
    final MesureCardiaque? m = s.derniere;
    final EtatRythme? e = s.etat;
    final bool alerte = s.enAlerte();
    final Color couleur = alerte
        ? AppColors.danger
        : (s.estActif() ? AppColors.success : AppColors.textSecondary);
    final StatsRythme stats = StatsRythme.de(_heure, s.seuils);

    return Section(
      titre: 'Rythme du patient',
      icone: Icons.monitor_heart_outlined,
      action: e == null
          ? null
          : Pastille(
              libelle: e.libelle,
              couleur: couleur,
              icone: alerte ? Icons.warning_amber_rounded : Icons.favorite,
            ),
      children: [
        if (m == null)
          const Info(
            icone: Icons.watch_outlined,
            texte: 'Pas de mesure de montre pour ce patient',
          )
        else ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Icon(Icons.favorite, color: couleur, size: 26),
              const SizedBox(width: 8),
              Text(
                '${m.bpm}',
                style: TextStyle(
                  fontSize: 34,
                  height: 1,
                  fontWeight: FontWeight.w900,
                  color: alerte ? AppColors.danger : AppColors.textPrimary,
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(left: 4, bottom: 3),
                child: Text('bpm', style: TextStyle(color: AppColors.textSecondary)),
              ),
              const Spacer(),
              Text(
                DispatchUi.ilYa(m.date),
                style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
              ),
            ],
          ),
          Info(
            icone: Icons.tune,
            texte: stats.nombre < 2
                ? 'Seuils ${s.seuils.min}–${s.seuils.max} bpm'
                : 'Sur 1 h : ${stats.min}–${stats.max} bpm · seuils ${s.seuils.min}–${s.seuils.max}',
          ),
        ],
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => Navigator.push<void>(
              context,
              MaterialPageRoute(
                builder: (_) => SuiviPatientScreen(patientId: s.patientId, nom: s.nom),
              ),
            ),
            icon: const Icon(Icons.show_chart),
            label: Text('Courbe de ${s.nom}'),
          ),
        ),
      ],
    );
  }
}
