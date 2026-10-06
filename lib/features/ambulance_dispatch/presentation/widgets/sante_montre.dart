import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../home/presentation/widgets/ecg_painter.dart';
import '../../data/api/mibro_protocole.dart';
import '../../data/api/montre_ble_service.dart';
import '../../domain/surveillance_cardiaque.dart';
import '../providers/montre_controller.dart';
import '../screens/surveillance_cardiaque_screen.dart';
import 'dispatch_ui.dart';
import 'tableau_montre.dart';

// Onglet « Santé » du patient : vraies données de sa montre Mibro C2,
// mises à jour à chaque synchro (toutes les 30 s) par MontreController.

void _ouvrirMontre(BuildContext context) {
  Navigator.push<void>(
    context,
    MaterialPageRoute(builder: (_) => const SurveillanceCardiaqueScreen()),
  );
}

/// Fréquence cardiaque : dernière mesure réelle de la montre, état par
/// rapport aux seuils du médecin, heure de la mesure. « EN DIRECT » seulement
/// si la montre est connectée et vient d'être synchronisée.
class CarteCoeurMontre extends StatefulWidget {
  const CarteCoeurMontre({super.key});

  @override
  State<CarteCoeurMontre> createState() => _CarteCoeurMontreState();
}

class _CarteCoeurMontreState extends State<CarteCoeurMontre>
    with SingleTickerProviderStateMixin {
  static const int _battements = 3;
  final MontreController _ctrl = MontreController.instance;
  late final AnimationController _ecg = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  );
  int? _bpmAnime;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_maj);
    _maj();
  }

  @override
  void dispose() {
    _ctrl.removeListener(_maj);
    _ecg.dispose();
    super.dispose();
  }

  /// Le tracé bat au rythme réel mesuré (3 battements par défilement).
  void _maj() {
    final int? bpm = _ctrl.derniere?.bpm;
    if (bpm == _bpmAnime) {
      return;
    }
    _bpmAnime = bpm;
    if (bpm == null || bpm <= 0) {
      _ecg.stop();
      return;
    }
    _ecg.duration = Duration(milliseconds: (_battements * 60000 / bpm).round());
    _ecg.repeat();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _ctrl,
      builder: (BuildContext context, Widget? _) {
        final MesureCardiaque? der = _ctrl.derniere;
        final EtatRythme? e = _ctrl.etatRythme;
        final bool anormal = e != null && e != EtatRythme.normal;
        final EtatMontre? etat = _ctrl.etat;
        final DateTime? lu = _ctrl.derniereLecture;
        final bool direct = etat == EtatMontre.connectee &&
            lu != null &&
            DateTime.now().difference(lu) < const Duration(minutes: 2);
        final SeuilsCardiaques s = _ctrl.seuils;

        final String statut;
        final Color couleurStatut;
        if (direct) {
          statut = 'EN DIRECT';
          couleurStatut = AppColors.danger;
        } else if (etat == null) {
          statut = 'CONNEXION…';
          couleurStatut = Colors.white54;
        } else {
          statut = 'MONTRE DÉCONNECTÉE';
          couleurStatut = AppColors.warning;
        }

        return GestureDetector(
          onTap: () => _ouvrirMontre(context),
          child: Container(
            height: 215,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.ink,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Fréquence cardiaque',
                      style: TextStyle(color: Colors.white60, fontSize: 13),
                    ),
                    const Spacer(),
                    AnimatedBuilder(
                      animation: _ecg,
                      builder: (BuildContext context, Widget? child) => Opacity(
                        opacity: direct
                            ? 0.4 + 0.6 * (0.5 + 0.5 * math.sin(_ecg.value * 2 * math.pi))
                            : 1,
                        child: child,
                      ),
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(color: couleurStatut, shape: BoxShape.circle),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      statut,
                      style: TextStyle(
                        color: couleurStatut,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 400),
                      transitionBuilder: (Widget child, Animation<double> anim) =>
                          FadeTransition(opacity: anim, child: child),
                      child: Text(
                        der == null ? '--' : '${der.bpm}',
                        key: ValueKey<String>('${der?.bpm}-${der?.date}'),
                        style: TextStyle(
                          color: anormal ? AppColors.danger : Colors.white,
                          fontSize: 46,
                          height: 1,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Padding(
                      padding: EdgeInsets.only(bottom: 4),
                      child: Text('bpm', style: TextStyle(color: Colors.white60, fontSize: 14)),
                    ),
                    const Spacer(),
                    AnimatedBuilder(
                      animation: _ecg,
                      builder: (BuildContext context, Widget? child) {
                        // Un battement du cœur par battement du tracé.
                        final double v = (_ecg.value * _battements) % 1;
                        final double echelle =
                            v < 0.15 ? 1 + 0.18 * math.sin(v / 0.15 * math.pi) : 1;
                        return Transform.scale(scale: echelle, child: child);
                      },
                      child: Icon(
                        anormal ? Icons.heart_broken_rounded : Icons.favorite_rounded,
                        color: AppColors.danger,
                        size: 34,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  der == null
                      ? 'Aucune mesure de la montre pour l\'instant'
                      : '${e?.libelle ?? ''} · mesuré à ${DispatchUi.heure(der.date)} '
                          '(${DispatchUi.ilYa(der.date)}) · seuils ${s.min}–${s.max}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: anormal ? AppColors.danger : Colors.white54,
                    fontSize: 11.5,
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: AnimatedBuilder(
                    animation: _ecg,
                    builder: (BuildContext context, Widget? child) => CustomPaint(
                      size: Size.infinite,
                      painter: EcgPainter(
                        couleur: anormal ? AppColors.danger : AppColors.ecg,
                        phase: _ecg.value,
                        epaisseur: 2.2,
                        lueur: true,
                        battements: _battements,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Toutes les données de la montre : batterie, signal, pas, calories,
/// rythme du jour, modèle, dernière synchro.
class CarteDonneesMontre extends StatelessWidget {
  const CarteDonneesMontre({super.key});

  @override
  Widget build(BuildContext context) {
    final MontreController c = MontreController.instance;
    return ListenableBuilder(
      listenable: c,
      builder: (BuildContext context, Widget? _) {
        final MontreBleService m = c.montre;
        final EtatMontre? etat = c.etat;
        final bool ok = etat == EtatMontre.connectee;
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.watch_outlined, color: AppColors.primary),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Ma montre',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                    ),
                  ),
                  if (etat == null)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    Pastille(
                      libelle: ok ? 'Connectée' : 'Non connectée',
                      couleur: ok ? AppColors.success : AppColors.danger,
                      icone: ok ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (ok)
                TableauMontre(montre: m)
              else ...[
                Info(
                  icone: Icons.info_outline,
                  texte: etat == null ? 'Recherche de la montre…' : etat.libelle,
                ),
                if (etat != null && etat != EtatMontre.indisponible) ...[
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: c.connecter,
                    icon: const Icon(Icons.bluetooth_searching),
                    label: const Text('Connecter la montre'),
                  ),
                ],
              ],
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _ouvrirMontre(context),
                  icon: const Icon(Icons.show_chart),
                  label: const Text('Courbe et détails'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Pas d'aujourd'hui heure par heure (résumés envoyés par la montre).
class CartePasDuJour extends StatefulWidget {
  const CartePasDuJour({super.key});

  @override
  State<CartePasDuJour> createState() => _CartePasDuJourState();
}

class _CartePasDuJourState extends State<CartePasDuJour> {
  int? _heureChoisie;

  @override
  Widget build(BuildContext context) {
    final MontreController c = MontreController.instance;
    return ListenableBuilder(
      listenable: c,
      builder: (BuildContext context, Widget? _) {
        final MontreBleService m = c.montre;
        final List<int> parHeure = List<int>.filled(24, 0);
        for (final ResumeActivite a in m.activiteDuJour) {
          parHeure[a.heure.hour] += a.pas;
        }
        final int maintenant = DateTime.now().hour;
        int max = 1;
        for (final int p in parHeure) {
          max = math.max(max, p);
        }
        final int? choix = _heureChoisie;
        final int total = m.pasAujourdhui;

        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    "Pas aujourd'hui",
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                  const Spacer(),
                  Text(
                    '${TableauMontre.milliers(total)} pas · '
                    '${TableauMontre.milliers(m.caloriesAujourdhui)} kcal',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                choix == null
                    ? 'Touchez une barre pour voir le détail de l\'heure'
                    : '${choix}h–${choix + 1}h : ${TableauMontre.milliers(parHeure[choix])} pas',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 120,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (int h = 0; h <= maintenant; h++)
                      Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => setState(() => _heureChoisie = h),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeOutCubic,
                                height: parHeure[h] == 0 ? 3 : 4 + 92 * parHeure[h] / max,
                                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(4),
                                  color: h == choix
                                      ? AppColors.primaryDark
                                      : AppColors.primary.withValues(
                                          alpha: parHeure[h] == 0 ? 0.12 : 0.55,
                                        ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              SizedBox(
                                height: 14,
                                child: h % 6 == 0
                                    ? FittedBox(
                                        child: Text(
                                          '${h}h',
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      )
                                    : null,
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (total == 0) ...[
                const SizedBox(height: 8),
                Info(
                  icone: Icons.info_outline,
                  texte: c.connectee
                      ? 'En attente des résumés de la montre (une fois par heure)'
                      : 'Connectez la montre pour voir vos pas',
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
