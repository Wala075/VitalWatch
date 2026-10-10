import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/utils/formatters.dart';
import '../../../../../core/widgets/empty_state.dart';
import '../../../../../core/widgets/search_field.dart';
import '../../../../../models/ambulancier.dart';
import '../../../../../models/utilisateur.dart';
import '../../../data/ambulancier_repository.dart';
import '../../../domain/staff_models.dart';
import '../../widgets/avatar_initiales.dart';
import '../../widgets/bouton_ajout.dart';
import '../../widgets/info_chip.dart';
import '../ambulancier_form_screen.dart';

/// Liste des ambulanciers (onglet Personnel) avec leur compte de connexion.
/// L'affectation aux ambulances est gérée par le module Ambulances.
class AmbulanciersListe extends StatefulWidget {
  const AmbulanciersListe({super.key, required this.role});

  final Role role;

  @override
  State<AmbulanciersListe> createState() => _AmbulanciersListeState();
}

class _AmbulanciersListeState extends State<AmbulanciersListe> {
  final AmbulancierRepository _repo = AmbulancierRepository();

  List<AmbulancierCompte> _liste = [];
  String _texte = '';

  /// Filtre rapide : null = tous, true = avec compte, false = sans compte.
  bool? _avecCompte;
  bool _chargement = true;
  int _requete = 0;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    final int requete = ++_requete;
    final List<AmbulancierCompte> res = await _repo.rechercher(texte: _texte);
    if (!mounted || requete != _requete) return;
    setState(() {
      _liste = res;
      _chargement = false;
    });
  }

  Future<void> _ouvrir(AmbulancierCompte fiche) async {
    final bool? modifie = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => AmbulancierFormScreen(fiche: fiche)),
    );
    if (modifie == true) _charger();
  }

  @override
  Widget build(BuildContext context) {
    final bool gerer = widget.role.gererPersonnel;
    final int nbComptes = _liste.where((f) => f.email != null).length;
    final List<AmbulancierCompte> visibles = _avecCompte == null
        ? _liste
        : _liste.where((f) => (f.email != null) == _avecCompte).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: SearchField(
            hint: 'Nom, téléphone, email...',
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
                selectionne: _avecCompte == null,
                onTap: () => setState(() => _avecCompte = null),
              ),
              const SizedBox(width: 8),
              FiltreRapide(
                libelle: 'Avec compte',
                nombre: nbComptes,
                selectionne: _avecCompte == true,
                couleur: AppColors.success,
                onTap: () => setState(() => _avecCompte = true),
              ),
              const SizedBox(width: 8),
              FiltreRapide(
                libelle: 'Sans compte',
                nombre: _liste.length - nbComptes,
                selectionne: _avecCompte == false,
                couleur: AppColors.warning,
                onTap: () => setState(() => _avecCompte = false),
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
                      icon: Icons.local_hospital_outlined,
                      message: 'Aucun ambulancier trouvé',
                    )
                  : RefreshIndicator(
                      onRefresh: _charger,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
                        itemCount: visibles.length,
                        separatorBuilder: (BuildContext context, int i) =>
                            const SizedBox(height: 10),
                        itemBuilder: (BuildContext context, int i) {
                          final AmbulancierCompte f = visibles[i];
                          return _CarteAmbulancier(
                            fiche: f,
                            onTap: gerer ? () => _ouvrir(f) : null,
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }
}

class _CarteAmbulancier extends StatelessWidget {
  const _CarteAmbulancier({required this.fiche, this.onTap});

  final AmbulancierCompte fiche;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Ambulancier a = fiche.ambulancier;
    final ({String prenom, String nom}) pn = a.prenomNom;
    final String? email = fiche.email;

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
                prenom: pn.prenom,
                nom: pn.nom,
                couleur: AppColors.indigo,
                rayon: 26,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      a.nom,
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
                      a.role.libelle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (email != null)
                      Text(
                        email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (a.disponible)
                          const StatusBadge(
                            libelle: 'Disponible',
                            icon: Icons.check_circle_rounded,
                            couleur: AppColors.success,
                          )
                        else
                          const StatusBadge(
                            libelle: 'Indisponible',
                            icon: Icons.pause_circle_rounded,
                            couleur: AppColors.textSecondary,
                          ),
                        if (a.ambulanceId != null)
                          const StatusBadge(
                            libelle: 'En équipage',
                            icon: Icons.local_hospital_rounded,
                            couleur: AppColors.primary,
                          ),
                        InfoChip(
                          icon: Icons.phone_outlined,
                          texte: Formatters.telephone(a.telephone),
                        ),
                        if (email == null)
                          const StatusBadge(
                            libelle: 'Sans compte',
                            icon: Icons.no_accounts_outlined,
                            couleur: AppColors.warning,
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
