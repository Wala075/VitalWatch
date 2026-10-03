import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/utils/formatters.dart';
import '../../../../../core/widgets/empty_state.dart';
import '../../../../../core/widgets/search_field.dart';
import '../../../../../models/service.dart';
import '../../../../../models/utilisateur.dart';
import '../../../data/service_repository.dart';
import '../../../domain/staff_models.dart';
import '../../widgets/info_chip.dart';
import '../service_form_screen.dart';

class ServicesTab extends StatefulWidget {
  const ServicesTab({super.key, required this.role});

  final Role role;

  @override
  State<ServicesTab> createState() => _ServicesTabState();
}

class _ServicesTabState extends State<ServicesTab> {
  final ServiceRepository _repo = ServiceRepository();

  List<ServiceStats> _services = [];
  bool _chargement = true;
  String _texte = '';
  int _requete = 0;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    final int requete = ++_requete;
    final List<ServiceStats> res = await _repo.statistiques(texte: _texte);
    if (!mounted || requete != _requete) {
      return;
    }
    setState(() {
      _services = res;
      _chargement = false;
    });
  }

  Future<void> _ouvrirFormulaire([Service? service]) async {
    final bool? modifie = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ServiceFormScreen(
          service: service,
          peutSupprimer: widget.role.gererServices,
        ),
      ),
    );
    if (modifie == true) {
      _charger();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool gerer = widget.role.gererServices;

    return Scaffold(
      floatingActionButton: gerer
          ? FloatingActionButton.extended(
              heroTag: 'fab_services',
              onPressed: () => _ouvrirFormulaire(),
              icon: const Icon(Icons.add),
              label: const Text('Service'),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: SearchField(
              hint: 'Rechercher un service',
              onChanged: (String v) {
                _texte = v;
                _charger();
              },
            ),
          ),
          Expanded(
            child: _chargement
                ? const Center(child: CircularProgressIndicator())
                : _services.isEmpty
                    ? const EmptyState(
                        icon: Icons.apartment,
                        message: 'Aucun service',
                      )
                    : RefreshIndicator(
                        onRefresh: _charger,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                          itemCount: _services.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 10),
                          itemBuilder: (BuildContext context, int i) {
                            final ServiceStats s = _services[i];
                            return _ServiceCard(
                              stats: s,
                              onTap: gerer
                                  ? () => _ouvrirFormulaire(s.service)
                                  : null,
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({required this.stats, this.onTap});

  final ServiceStats stats;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Service s = stats.service;
    final double taux = stats.tauxOccupation.clamp(0.0, 1.0).toDouble();

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                    child: const Icon(Icons.apartment, color: AppColors.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.nom,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'Étage ${s.etage ?? '-'} · ${Formatters.telephone(s.telephone)}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (stats.estComplet)
                    const StatusBadge(
                      libelle: 'Complet',
                      icon: Icons.block,
                      couleur: AppColors.danger,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              InfoChip(
                icon: Icons.workspace_premium,
                texte: 'Chef : ${stats.chefNom ?? 'non défini'}',
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 16,
                runSpacing: 4,
                children: [
                  InfoChip(
                    icon: Icons.medical_services_outlined,
                    texte: '${stats.nbMedecins} médecin(s)',
                  ),
                  InfoChip(
                    icon: Icons.people_outline,
                    texte: '${stats.nbPatients} / ${s.capacite} patients',
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: taux,
                  minHeight: 6,
                  backgroundColor: AppColors.surfaceGrey,
                  color: stats.estComplet ? AppColors.danger : AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
