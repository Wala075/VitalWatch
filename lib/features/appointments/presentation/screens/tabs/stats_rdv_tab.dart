import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/utils/formatters.dart';
import '../../../../../core/widgets/empty_state.dart';
import '../../../../../models/utilisateur.dart';
import '../../../domain/rdv_manager.dart';
import '../../../domain/rdv_models.dart';
import '../../widgets/rdv_widgets.dart';

/// Statistiques : absentéisme, charge par médecin, durée réelle moyenne.
/// Admin : tous les médecins. Médecin : ses propres chiffres.
class StatsRdvTab extends StatefulWidget {
  const StatsRdvTab({super.key, required this.utilisateur});

  final Utilisateur utilisateur;

  @override
  State<StatsRdvTab> createState() => _StatsRdvTabState();
}

class _StatsRdvTabState extends State<StatsRdvTab> {
  final RdvManager _manager = RdvManager();

  StatsRdv? _stats;
  bool _chargement = true;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    try {
      final StatsRdv s = await _manager.statistiques(widget.utilisateur);
      if (!mounted) {
        return;
      }
      setState(() {
        _stats = s;
        _chargement = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => _chargement = false);
      afficherErreur(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final StatsRdv? s = _stats;
    if (_chargement) {
      return const Center(child: CircularProgressIndicator());
    }
    if (s == null || s.parMedecin.isEmpty) {
      return const EmptyState(icon: Icons.insights_rounded, message: 'Aucune donnée');
    }
    final int chargeMax = s.parMedecin.fold(
      1,
      (int m, StatsMedecin x) => x.cetteSemaine > m ? x.cetteSemaine : m,
    );

    return RefreshIndicator(
      onRefresh: _charger,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
        children: [
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.7,
            children: [
              _Tuile(
                valeur: '${s.total}',
                libelle: 'Rendez-vous',
                icon: Icons.event_note_rounded,
                couleur: AppColors.primary,
              ),
              _Tuile(
                valeur: '${s.aVenir}',
                libelle: 'À venir',
                icon: Icons.schedule_rounded,
                couleur: AppColors.indigo,
              ),
              _Tuile(
                valeur: '${s.termines}',
                libelle: 'Terminés',
                icon: Icons.check_circle_rounded,
                couleur: AppColors.success,
              ),
              _Tuile(
                valeur: Formatters.pourcentage(s.tauxAbsenteisme),
                libelle: 'Absentéisme',
                icon: Icons.person_off_rounded,
                couleur: s.tauxAbsenteisme > 0.2 ? AppColors.danger : AppColors.warning,
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Text(
            'Par médecin',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          for (final StatsMedecin m in s.parMedecin)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _CarteMedecin(stats: m, chargeMax: chargeMax),
            ),
        ],
      ),
    );
  }
}

class _Tuile extends StatelessWidget {
  const _Tuile({
    required this.valeur,
    required this.libelle,
    required this.icon,
    required this.couleur,
  });

  final String valeur;
  final String libelle;
  final IconData icon;
  final Color couleur;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: couleur),
          Text(
            valeur,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          Text(libelle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _CarteMedecin extends StatelessWidget {
  const _CarteMedecin({required this.stats, required this.chargeMax});

  final StatsMedecin stats;
  final int chargeMax;

  @override
  Widget build(BuildContext context) {
    final double? duree = stats.dureeMoyenne;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(stats.medecinNom, style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(
              '${stats.total} RDV · ${stats.termines} terminés · ${stats.absents} absents · '
              '${stats.annules} annulés',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 10),
            _Barre(
              libelle: 'Charge cette semaine',
              valeur: '${stats.cetteSemaine} RDV',
              ratio: stats.cetteSemaine / chargeMax,
              couleur: AppColors.primary,
            ),
            const SizedBox(height: 8),
            _Barre(
              libelle: 'Absentéisme',
              valeur: Formatters.pourcentage(stats.tauxAbsenteisme),
              ratio: stats.tauxAbsenteisme,
              couleur: stats.tauxAbsenteisme > 0.2 ? AppColors.danger : AppColors.warning,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.timer_outlined, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Text(
                  duree == null
                      ? 'Durée moyenne : pas encore de consultation terminée'
                      : 'Durée réelle moyenne : ${Formatters.decimal(duree)} min',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Barre extends StatelessWidget {
  const _Barre({
    required this.libelle,
    required this.valeur,
    required this.ratio,
    required this.couleur,
  });

  final String libelle;
  final String valeur;
  final double ratio;
  final Color couleur;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(libelle, style: const TextStyle(fontSize: 12))),
            Text(valeur, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: ratio.clamp(0.0, 1.0),
            minHeight: 8,
            backgroundColor: AppColors.surfaceGrey,
            color: couleur,
          ),
        ),
      ],
    );
  }
}
