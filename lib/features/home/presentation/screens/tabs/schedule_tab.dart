import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/empty_state.dart';
import '../../../data/demo_data.dart';
import '../../../data/demo_store.dart';
import '../../widgets/countdown_chip.dart';
import '../../../../../core/widgets/page_title.dart';
import '../doctor_detail_screen.dart';

class ScheduleTab extends StatefulWidget {
  const ScheduleTab({super.key});

  @override
  State<ScheduleTab> createState() => _ScheduleTabState();
}

class _ScheduleTabState extends State<ScheduleTab> {
  final DemoStore _store = DemoStore.instance;
  bool _aVenir = true;

  void _annuler(DemoRdv r) {
    _store.annuler(r);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Rendez-vous avec ${r.medecin.nomComplet} annulé')),
    );
  }

  void _reprendre(DemoRdv r) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => DoctorDetailScreen(medecin: r.medecin)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _store,
      builder: (BuildContext context, Widget? child) {
        final List<DemoRdv> aVenir = _store.aVenir;
        final List<DemoRdv> passes = _store.passes;
        final List<DemoRdv> liste = _aVenir ? aVenir : passes;

        return SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PageTitle(
                surtitre: 'Votre',
                titre: 'Planning',
                trailing: Material(
                  color: Colors.white,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Synchronisation avec le calendrier : bientôt'),
                      ),
                    ),
                    child: const SizedBox(
                      width: 46,
                      height: 46,
                      child: Icon(
                        Icons.calendar_month_rounded,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      _Segment(
                        libelle: 'À venir (${aVenir.length})',
                        actif: _aVenir,
                        onTap: () => setState(() => _aVenir = true),
                      ),
                      _Segment(
                        libelle: 'Passés (${passes.length})',
                        actif: !_aVenir,
                        onTap: () => setState(() => _aVenir = false),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: liste.isEmpty
                    ? EmptyState(
                        icon: Icons.event_busy_rounded,
                        message: _aVenir
                            ? 'Aucun rendez-vous à venir'
                            : 'Aucun rendez-vous passé',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 14, 20, 120),
                        itemCount: liste.length,
                        separatorBuilder: (BuildContext context, int i) =>
                            const SizedBox(height: 12),
                        itemBuilder: (BuildContext context, int i) {
                          final DemoRdv r = liste[i];
                          return _CarteRdv(
                            rdv: r,
                            onAnnuler: () => _annuler(r),
                            onReprendre: () => _reprendre(r),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({required this.libelle, required this.actif, required this.onTap});

  final String libelle;
  final bool actif;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: actif
                ? const LinearGradient(colors: [AppColors.primary, AppColors.secondary])
                : null,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            libelle,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: actif ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _CarteRdv extends StatelessWidget {
  const _CarteRdv({
    required this.rdv,
    required this.onAnnuler,
    required this.onReprendre,
  });

  final DemoRdv rdv;
  final VoidCallback onAnnuler;
  final VoidCallback onReprendre;

  @override
  Widget build(BuildContext context) {
    final StatutRdv statut = rdv.statutEffectif;
    final bool aVenir = statut == StatutRdv.aVenir;
    final DemoDoctor m = rdv.medecin;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 64,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: aVenir ? null : AppColors.surfaceGrey,
              gradient: aVenir
                  ? const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.primaryDark, AppColors.primary],
                    )
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${rdv.date.day}',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: aVenir ? Colors.white : AppColors.textPrimary,
                  ),
                ),
                Text(
                  DateFr.mois(rdv.date),
                  style: TextStyle(
                    fontSize: 11,
                    color: aVenir ? Colors.white70 : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  m.nomComplet,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
                const SizedBox(height: 2),
                Text(
                  m.specialite,
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.schedule_rounded,
                          size: 14,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          DateFr.heure(rdv.date),
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    if (aVenir)
                      CountdownChip(date: rdv.date)
                    else
                      _BadgeStatut(statut: statut),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (aVenir)
            _IconeAction(
              icon: Icons.close_rounded,
              couleur: AppColors.danger,
              aide: 'Annuler',
              onTap: onAnnuler,
            )
          else
            _IconeAction(
              icon: Icons.replay_rounded,
              couleur: AppColors.primary,
              aide: 'Reprendre rendez-vous',
              onTap: onReprendre,
            ),
        ],
      ),
    );
  }
}

class _BadgeStatut extends StatelessWidget {
  const _BadgeStatut({required this.statut});

  final StatutRdv statut;

  @override
  Widget build(BuildContext context) {
    final bool annule = statut == StatutRdv.annule;
    final Color c = annule ? AppColors.danger : AppColors.success;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            annule ? Icons.cancel_rounded : Icons.check_circle_rounded,
            size: 12,
            color: c,
          ),
          const SizedBox(width: 4),
          Text(
            annule ? 'Annulé' : 'Terminé',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c),
          ),
        ],
      ),
    );
  }
}

class _IconeAction extends StatelessWidget {
  const _IconeAction({
    required this.icon,
    required this.couleur,
    required this.aide,
    required this.onTap,
  });

  final IconData icon;
  final Color couleur;
  final String aide;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: aide,
      child: Material(
        color: couleur.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: SizedBox(
            width: 38,
            height: 38,
            child: Icon(icon, size: 18, color: couleur),
          ),
        ),
      ),
    );
  }
}
