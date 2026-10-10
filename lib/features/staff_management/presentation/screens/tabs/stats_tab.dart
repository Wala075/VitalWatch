import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/utils/formatters.dart';
import '../../../../../core/widgets/empty_state.dart';
import '../../../data/service_repository.dart';
import '../../../domain/staff_models.dart';
import '../../widgets/info_chip.dart';

/// Statistiques par service : médecins, patients, ratio patients / médecin.
class StatsTab extends StatefulWidget {
  const StatsTab({super.key});

  @override
  State<StatsTab> createState() => _StatsTabState();
}

class _StatsTabState extends State<StatsTab> {
  final ServiceRepository _repo = ServiceRepository();

  List<ServiceStats> _stats = [];
  bool _chargement = true;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    final List<ServiceStats> res = await _repo.statistiques();
    if (!mounted) {
      return;
    }
    setState(() {
      _stats = res;
      _chargement = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_chargement) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_stats.isEmpty) {
      return const EmptyState(icon: Icons.insights, message: 'Aucune donnée');
    }

    int medecins = 0;
    int patients = 0;
    int capacite = 0;
    for (final ServiceStats s in _stats) {
      medecins += s.nbMedecins;
      patients += s.nbPatients;
      capacite += s.service.capacite;
    }
    final double ratioGlobal = medecins == 0 ? 0 : patients / medecins;
    final double occupation = capacite == 0 ? 0 : patients / capacite;

    return RefreshIndicator(
      onRefresh: _charger,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
        children: [
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.4,
            children: [
              _StatTile(
                icon: Icons.apartment,
                valeur: '${_stats.length}',
                libelle: 'Services',
              ),
              _StatTile(
                icon: Icons.medical_services_outlined,
                valeur: '$medecins',
                libelle: 'Médecins',
              ),
              _StatTile(
                icon: Icons.people_outline,
                valeur: '$patients',
                libelle: 'Patients',
              ),
              _StatTile(
                icon: Icons.balance,
                valeur: Formatters.decimal(ratioGlobal),
                libelle: 'Patients / médecin',
              ),
            ],
          ),
          const SizedBox(height: 10),
          _StatTile(
            icon: Icons.bed_outlined,
            valeur: Formatters.pourcentage(occupation),
            libelle: 'Taux d\'occupation global ($patients / $capacite lits)',
          ),
          const SizedBox(height: 20),
          Text(
            'Par service',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
          ),
          const SizedBox(height: 10),
          for (final ServiceStats s in _stats) ...[
            _ServiceStatCard(stats: s),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.valeur,
    required this.libelle,
  });

  final IconData icon;
  final String valeur;
  final String libelle;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: AppColors.primary),
            const SizedBox(height: 6),
            Text(
              valeur,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              libelle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServiceStatCard extends StatelessWidget {
  const _ServiceStatCard({required this.stats});

  final ServiceStats stats;

  @override
  Widget build(BuildContext context) {
    final double taux = stats.tauxOccupation.clamp(0.0, 1.0).toDouble();
    final bool surcharge = stats.ratioPatientsParMedecin > 10;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    stats.service.nom,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                if (stats.nbMedecins == 0)
                  const StatusBadge(
                    libelle: 'Sans médecin',
                    icon: Icons.error_outline,
                    couleur: AppColors.danger,
                  )
                else if (surcharge)
                  const StatusBadge(
                    libelle: 'Surchargé',
                    icon: Icons.warning_amber_rounded,
                    couleur: AppColors.warning,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _Chiffre(valeur: '${stats.nbMedecins}', libelle: 'médecins'),
                _Chiffre(
                  valeur: '${stats.nbMedecinsDisponibles}',
                  libelle: 'disponibles',
                ),
                _Chiffre(valeur: '${stats.nbPatients}', libelle: 'patients'),
                _Chiffre(
                  valeur: Formatters.decimal(stats.ratioPatientsParMedecin),
                  libelle: 'patients / méd.',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: taux,
                      minHeight: 8,
                      backgroundColor: AppColors.surfaceGrey,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${Formatters.pourcentage(stats.tauxOccupation)} occupé',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Chiffre extends StatelessWidget {
  const _Chiffre({required this.valeur, required this.libelle});

  final String valeur;
  final String libelle;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            valeur,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          Text(
            libelle,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
