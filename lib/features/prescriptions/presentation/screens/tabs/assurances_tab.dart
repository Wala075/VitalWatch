import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/empty_state.dart';
import '../../../../../models/utilisateur.dart';
import '../../../data/assurance_repository.dart';
import '../../../data/taux_couverture_repository.dart';
import '../../../domain/formats_prescriptions.dart';
import '../../../domain/models/assurance.dart';
import '../../../domain/models/taux_couverture.dart';
import '../../../domain/prescriptions_permissions.dart';
import '../../widgets/elements_ui.dart';
import '../assurance_form_screen.dart';

/// Organismes (CNAM, mutuelles, assurances privées) et leurs taux.
class AssurancesTab extends StatefulWidget {
  const AssurancesTab({super.key, required this.role});

  final Role role;

  @override
  State<AssurancesTab> createState() => _AssurancesTabState();
}

class _AssurancesTabState extends State<AssurancesTab> {
  final AssuranceRepository _repo = AssuranceRepository();
  final TauxCouvertureRepository _tauxRepo = TauxCouvertureRepository();

  List<_AssuranceDetail> _assurances = [];
  bool _chargement = true;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    final List<Assurance> liste = await _repo.lister();
    final List<_AssuranceDetail> res = [];
    for (final Assurance a in liste) {
      final int id = a.id!;
      res.add(_AssuranceDetail(
        assurance: a,
        taux: await _tauxRepo.parAssurance(id),
        nbContrats: await _repo.nombreContrats(id),
      ));
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _assurances = res;
      _chargement = false;
    });
  }

  Future<void> _ouvrirFormulaire([Assurance? a]) async {
    final bool? modifie = await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(builder: (_) => AssuranceFormScreen(assurance: a)),
    );
    if (modifie == true) {
      _charger();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool gerer = widget.role.gererReferentiels;

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          EnTetePage(
            surtitre: 'Organismes et taux',
            titre: 'Assurances',
            trailing: gerer
                ? BoutonAjout(
                    tooltip: 'Ajouter une assurance',
                    onPressed: () => _ouvrirFormulaire(),
                  )
                : null,
          ),
          Expanded(
            child: _chargement
                ? const Center(child: CircularProgressIndicator())
                : _assurances.isEmpty
                    ? const EmptyState(
                        icon: Icons.shield_outlined,
                        message: 'Aucune assurance',
                      )
                    : RefreshIndicator(
                        onRefresh: _charger,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
                          itemCount: _assurances.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 10),
                          itemBuilder: (BuildContext context, int i) {
                            final _AssuranceDetail d = _assurances[i];
                            return _CarteAssurance(
                              detail: d,
                              onTap: gerer ? () => _ouvrirFormulaire(d.assurance) : null,
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

class _AssuranceDetail {
  const _AssuranceDetail({
    required this.assurance,
    required this.taux,
    required this.nbContrats,
  });

  final Assurance assurance;
  final List<TauxCouverture> taux;
  final int nbContrats;
}

class _CarteAssurance extends StatelessWidget {
  const _CarteAssurance({required this.detail, this.onTap});

  final _AssuranceDetail detail;
  final VoidCallback? onTap;

  static IconData icone(TypeAssurance t) {
    switch (t) {
      case TypeAssurance.cnam:
        return Icons.account_balance_rounded;
      case TypeAssurance.mutuelle:
        return Icons.groups_rounded;
      case TypeAssurance.privee:
        return Icons.business_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final Assurance a = detail.assurance;
    final double? plafond = a.plafondAnnuel;
    final int nb = detail.nbContrats;

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
                    child: Icon(icone(a.type), color: AppColors.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      a.nom,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  BadgeStatut(
                    libelle: a.estObligatoire ? 'Obligatoire' : a.type.libelle,
                    icon: a.estObligatoire ? Icons.verified_user_outlined : Icons.add_moderator_outlined,
                    couleur: a.estObligatoire ? AppColors.primary : AppColors.purple,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 16,
                runSpacing: 6,
                children: [
                  InfoLigne(
                    icon: Icons.savings_outlined,
                    texte: plafond == null
                        ? 'Sans plafond'
                        : 'Plafond ${FormatsPrescriptions.dt(plafond)} / an',
                  ),
                  InfoLigne(
                    icon: Icons.schedule_rounded,
                    texte: 'Réponse sous ${a.delaiReponseJours} j',
                  ),
                  InfoLigne(
                    icon: Icons.badge_outlined,
                    texte: '$nb contrat${nb > 1 ? 's' : ''}',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (detail.taux.isEmpty)
                const Text(
                  "Aucun taux : rien n'est remboursé",
                  style: TextStyle(fontSize: 13, color: AppColors.danger),
                )
              else
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final TauxCouverture t in detail.taux)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.mint,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${t.libelleCategorie} · ${FormatsPrescriptions.taux(t.taux)}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryDark,
                          ),
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
