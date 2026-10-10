import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/utils/formatters.dart';
import '../../../../../core/widgets/empty_state.dart';
import '../../../../../core/widgets/search_field.dart';
import '../../../../../models/infirmier.dart';
import '../../../../../models/utilisateur.dart';
import '../../../data/infirmier_repository.dart';
import '../../../domain/staff_models.dart';
import '../../widgets/avatar_initiales.dart';
import '../../widgets/bouton_ajout.dart';
import '../../widgets/info_chip.dart';
import '../infirmier_form_screen.dart';

/// Liste des infirmiers (onglet Personnel). L'admin touche une fiche
/// pour la modifier ou la supprimer.
class InfirmiersListe extends StatefulWidget {
  const InfirmiersListe({super.key, required this.role});

  final Role role;

  @override
  State<InfirmiersListe> createState() => _InfirmiersListeState();
}

class _InfirmiersListeState extends State<InfirmiersListe> {
  final InfirmierRepository _repo = InfirmierRepository();

  List<InfirmierDetail> _liste = [];
  String _texte = '';

  /// Filtre rapide : null = tous, true = disponibles, false = en congé.
  bool? _disponible;
  bool _chargement = true;
  int _requete = 0;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    final int requete = ++_requete;
    final List<InfirmierDetail> res = await _repo.rechercher(texte: _texte);
    if (!mounted || requete != _requete) return;
    setState(() {
      _liste = res;
      _chargement = false;
    });
  }

  Future<void> _ouvrir(Infirmier i) async {
    final bool? modifie = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => InfirmierFormScreen(infirmier: i)),
    );
    if (modifie == true) _charger();
  }

  @override
  Widget build(BuildContext context) {
    final bool gerer = widget.role.gererPersonnel;
    final int nbDispo = _liste.where((d) => d.infirmier.disponible).length;
    final List<InfirmierDetail> visibles = _disponible == null
        ? _liste
        : _liste.where((d) => d.infirmier.disponible == _disponible).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: SearchField(
            hint: 'Nom, matricule, téléphone...',
            onChanged: (String v) {
              _texte = v;
              _charger();
            },
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 38,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              FiltreRapide(
                libelle: 'Tous',
                nombre: _liste.length,
                selectionne: _disponible == null,
                onTap: () => setState(() => _disponible = null),
              ),
              const SizedBox(width: 8),
              FiltreRapide(
                libelle: 'Disponibles',
                nombre: nbDispo,
                selectionne: _disponible == true,
                couleur: AppColors.success,
                onTap: () => setState(() => _disponible = true),
              ),
              const SizedBox(width: 8),
              FiltreRapide(
                libelle: 'En congé',
                nombre: _liste.length - nbDispo,
                selectionne: _disponible == false,
                couleur: AppColors.danger,
                onTap: () => setState(() => _disponible = false),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: _chargement
              ? const Center(child: CircularProgressIndicator())
              : visibles.isEmpty
                  ? const EmptyState(
                      icon: Icons.health_and_safety_outlined,
                      message: 'Aucun infirmier trouvé',
                    )
                  : RefreshIndicator(
                      onRefresh: _charger,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
                        itemCount: visibles.length,
                        separatorBuilder: (BuildContext context, int i) =>
                            const SizedBox(height: 10),
                        itemBuilder: (BuildContext context, int i) {
                          final InfirmierDetail d = visibles[i];
                          return _CarteInfirmier(
                            detail: d,
                            onTap: gerer ? () => _ouvrir(d.infirmier) : null,
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }
}

class _CarteInfirmier extends StatelessWidget {
  const _CarteInfirmier({required this.detail, this.onTap});

  final InfirmierDetail detail;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Infirmier i = detail.infirmier;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              AvatarInitiales(
                prenom: i.prenom,
                nom: i.nom,
                couleur: AppColors.secondary,
                rayon: 26,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      i.nomComplet,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Infirmier · ${detail.serviceNom ?? 'Sans service'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (i.disponible)
                          const StatusBadge(
                            libelle: 'Disponible',
                            icon: Icons.check_circle_rounded,
                            couleur: AppColors.success,
                          )
                        else
                          const StatusBadge(
                            libelle: 'En congé',
                            icon: Icons.event_busy_rounded,
                            couleur: AppColors.danger,
                          ),
                        if (!detail.aCompte)
                          const StatusBadge(
                            libelle: 'Sans compte',
                            icon: Icons.no_accounts_outlined,
                            couleur: AppColors.warning,
                          ),
                        InfoChip(icon: Icons.badge_outlined, texte: i.matricule),
                        InfoChip(
                          icon: Icons.phone_outlined,
                          texte: Formatters.telephone(i.telephone),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textSecondary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
