import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/empty_state.dart';
import '../../../../../core/widgets/search_field.dart';
import '../../../../../models/utilisateur.dart';
import '../../../data/medicament_repository.dart';
import '../../../domain/formats_prescriptions.dart';
import '../../../domain/models/medicament.dart';
import '../../../domain/prescriptions_permissions.dart';
import '../../widgets/elements_ui.dart';
import '../medicament_form_screen.dart';

/// Catalogue des médicaments : recherche par nom ou DCI, filtres catégorie et
/// générique, tri par prix. L'admin ajoute, modifie, archive.
class CatalogueTab extends StatefulWidget {
  const CatalogueTab({super.key, required this.role});

  final Role role;

  @override
  State<CatalogueTab> createState() => _CatalogueTabState();
}

class _CatalogueTabState extends State<CatalogueTab> {
  final MedicamentRepository _repo = MedicamentRepository();

  List<Medicament> _medicaments = [];
  bool _chargement = true;
  String _texte = '';
  CategorieMedicament? _categorie;
  bool _generiques = false;
  bool _triPrix = false;
  bool _archives = false;
  int _requete = 0;

  bool get _gerer => widget.role.gererReferentiels;

  int get _nbFiltres {
    int n = 0;
    if (_generiques) {
      n++;
    }
    if (_triPrix) {
      n++;
    }
    if (_archives) {
      n++;
    }
    return n;
  }

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    final int requete = ++_requete;
    final List<Medicament> res = await _repo.lister(
      texte: _texte,
      categorie: _categorie,
      generique: _generiques ? true : null,
      inclureArchives: _archives,
      triParPrix: _triPrix,
    );
    if (!mounted || requete != _requete) {
      return;
    }
    setState(() {
      _medicaments = res;
      _chargement = false;
    });
  }

  Future<void> _ouvrirFormulaire([Medicament? m]) async {
    final bool? modifie = await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(builder: (_) => MedicamentFormScreen(medicament: m)),
    );
    if (modifie == true) {
      _charger();
    }
  }

  Future<void> _ouvrirFiltres() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) {
        return StatefulBuilder(
          builder: (_, StateSetter majFeuille) {
            void basculer(VoidCallback changement) {
              majFeuille(changement);
              setState(() {});
            }

            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SwitchListTile(
                    title: const Text('Génériques uniquement'),
                    secondary: const Icon(Icons.recycling_rounded),
                    value: _generiques,
                    onChanged: (bool v) => basculer(() => _generiques = v),
                  ),
                  SwitchListTile(
                    title: const Text('Du moins cher au plus cher'),
                    secondary: const Icon(Icons.sort_rounded),
                    value: _triPrix,
                    onChanged: (bool v) => basculer(() => _triPrix = v),
                  ),
                  if (_gerer)
                    SwitchListTile(
                      title: const Text('Afficher les médicaments archivés'),
                      secondary: const Icon(Icons.inventory_2_outlined),
                      value: _archives,
                      onChanged: (bool v) => basculer(() => _archives = v),
                    ),
                  const SizedBox(height: 12),
                ],
              ),
            );
          },
        );
      },
    );
    _charger();
  }

  void _choisirCategorie(CategorieMedicament? c) {
    setState(() => _categorie = c);
    _charger();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          EnTetePage(
            surtitre: 'Ordonnances & Assurance',
            titre: 'Catalogue',
            trailing: _gerer
                ? BoutonAjout(
                    tooltip: 'Ajouter un médicament',
                    onPressed: () => _ouvrirFormulaire(),
                  )
                : null,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SearchField(
              hint: 'Nom commercial ou DCI',
              onChanged: (String v) {
                _texte = v;
                _charger();
              },
              onFilterTap: _ouvrirFiltres,
              nbFiltres: _nbFiltres,
            ),
          ),
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
              children: [
                _PuceCategorie(
                  libelle: 'Toutes',
                  selectionnee: _categorie == null,
                  onTap: () => _choisirCategorie(null),
                ),
                for (final CategorieMedicament c in CategorieMedicament.values)
                  _PuceCategorie(
                    libelle: c.libelle,
                    couleur: StyleCategorie.couleur(c),
                    selectionnee: _categorie == c,
                    onTap: () => _choisirCategorie(c),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _chargement
                ? const Center(child: CircularProgressIndicator())
                : _medicaments.isEmpty
                    ? const EmptyState(
                        icon: Icons.medication_outlined,
                        message: 'Aucun médicament ne correspond à la recherche',
                      )
                    : RefreshIndicator(
                        onRefresh: _charger,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
                          itemCount: _medicaments.length + 1,
                          separatorBuilder: (_, _) => const SizedBox(height: 10),
                          itemBuilder: (BuildContext context, int i) {
                            if (i == 0) {
                              return Text(
                                '${_medicaments.length} médicament${_medicaments.length > 1 ? 's' : ''}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary,
                                ),
                              );
                            }
                            final Medicament m = _medicaments[i - 1];
                            return _CarteMedicament(
                              medicament: m,
                              onTap: _gerer ? () => _ouvrirFormulaire(m) : null,
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

class _PuceCategorie extends StatelessWidget {
  const _PuceCategorie({
    required this.libelle,
    required this.selectionnee,
    required this.onTap,
    this.couleur = AppColors.primary,
  });

  final String libelle;
  final bool selectionnee;
  final VoidCallback onTap;
  final Color couleur;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: selectionnee ? couleur : Colors.white,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Text(
              libelle,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: selectionnee ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CarteMedicament extends StatelessWidget {
  const _CarteMedicament({required this.medicament, this.onTap});

  final Medicament medicament;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Medicament m = medicament;
    final double? reference = m.prixReference;

    return Opacity(
      opacity: m.actif ? 1 : 0.6,
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  child: Icon(StyleCategorie.iconeForme(m.forme), color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        m.libelle,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        m.description,
                        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          StyleCategorie.badge(m.categorie),
                          if (m.generique)
                            const BadgeStatut(
                              libelle: 'Générique',
                              icon: Icons.recycling_rounded,
                              couleur: AppColors.success,
                            ),
                          if (!m.actif)
                            const BadgeStatut(
                              libelle: 'Archivé',
                              icon: Icons.inventory_2_outlined,
                              couleur: AppColors.textSecondary,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      FormatsPrescriptions.dt(m.prixPublic),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    if (reference != null && reference < m.prixPublic)
                      Text(
                        'Réf. ${FormatsPrescriptions.dt(reference)}',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
