import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/empty_state.dart';
import '../../../data/demo_data.dart';
import '../../../data/demo_store.dart';
import '../../widgets/doctor_avatar.dart';
import '../../widgets/page_title.dart';
import '../doctor_detail_screen.dart';

class DoctorsTab extends StatefulWidget {
  const DoctorsTab({super.key});

  @override
  State<DoctorsTab> createState() => _DoctorsTabState();
}

class _DoctorsTabState extends State<DoctorsTab> {
  final DemoStore _store = DemoStore.instance;
  String _recherche = '';

  List<DemoDoctor> _filtrer() {
    final String q = _recherche.trim().toLowerCase();
    final String? categorie = _store.filtreCategorie;
    final List<DemoDoctor> res = [];
    for (final DemoDoctor m in DemoData.medecins) {
      if (categorie != null && m.categorie != categorie) {
        continue;
      }
      if (q.isNotEmpty &&
          !m.nomComplet.toLowerCase().contains(q) &&
          !m.specialite.toLowerCase().contains(q) &&
          !m.hopital.toLowerCase().contains(q)) {
        continue;
      }
      res.add(m);
    }
    return res;
  }

  void _ouvrir(DemoDoctor m) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => DoctorDetailScreen(medecin: m)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _store,
      builder: (BuildContext context, Widget? child) {
        final List<DemoDoctor> liste = _filtrer();
        int enLigne = 0;
        for (final DemoDoctor m in DemoData.medecins) {
          if (m.enLigne) {
            enLigne++;
          }
        }

        return SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PageTitle(
                surtitre: 'Trouvez votre',
                titre: 'Médecin',
                trailing: _ChipEnLigne(nombre: enLigne),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  onChanged: (String v) => setState(() => _recherche = v),
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Nom ou spécialité',
                    prefixIcon: const Icon(Icons.search_rounded),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 42,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    _ChipCategorie(
                      libelle: 'Tous',
                      selectionne: _store.filtreCategorie == null,
                      onTap: () => _store.choisirCategorie(null),
                    ),
                    for (final Specialite s in DemoData.specialites)
                      _ChipCategorie(
                        libelle: s.nom,
                        icon: s.icon,
                        couleur: s.couleur,
                        selectionne: _store.filtreCategorie == s.nom,
                        onTap: () => _store.choisirCategorie(s.nom),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: liste.isEmpty
                    ? const EmptyState(
                        icon: Icons.search_off_rounded,
                        message: 'Aucun médecin ne correspond à votre recherche',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 14, 20, 120),
                        itemCount: liste.length,
                        separatorBuilder: (BuildContext context, int i) =>
                            const SizedBox(height: 12),
                        itemBuilder: (BuildContext context, int i) {
                          final DemoDoctor m = liste[i];
                          return _LigneMedecin(
                            medecin: m,
                            favori: _store.estFavori(m),
                            onFavori: () => _store.basculerFavori(m),
                            onTap: () => _ouvrir(m),
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

class _ChipEnLigne extends StatelessWidget {
  const _ChipEnLigne({required this.nombre});

  final int nombre;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: AppColors.success,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$nombre en ligne',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.success,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChipCategorie extends StatelessWidget {
  const _ChipCategorie({
    required this.libelle,
    required this.selectionne,
    required this.onTap,
    this.icon,
    this.couleur = AppColors.textPrimary,
  });

  final String libelle;
  final bool selectionne;
  final VoidCallback onTap;
  final IconData? icon;
  final Color couleur;

  @override
  Widget build(BuildContext context) {
    final IconData? ic = icon;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: selectionne ? AppColors.ink : Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (ic != null) ...[
                Icon(ic, size: 16, color: selectionne ? Colors.white : couleur),
                const SizedBox(width: 6),
              ],
              Text(
                libelle,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selectionne ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LigneMedecin extends StatelessWidget {
  const _LigneMedecin({
    required this.medecin,
    required this.favori,
    required this.onFavori,
    required this.onTap,
  });

  final DemoDoctor medecin;
  final bool favori;
  final VoidCallback onFavori;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final DemoDoctor m = medecin;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DoctorAvatar(medecin: m, taille: 80, rayon: 18),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            m.nomComplet,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: onFavori,
                          child: Icon(
                            favori ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                            size: 20,
                            color: favori ? AppColors.danger : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      m.specialite,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded, size: 15, color: AppColors.warning),
                        const SizedBox(width: 3),
                        Text(
                          '${m.note.toStringAsFixed(1)} (${m.avis})',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        Text(
                          '  ·  ${m.experience} ans',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          '${m.prix} DT',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                        ),
                        const Text(
                          ' / visite',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                        const Spacer(),
                        _Disponibilite(enLigne: m.enLigne),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Disponibilite extends StatelessWidget {
  const _Disponibilite({required this.enLigne});

  final bool enLigne;

  @override
  Widget build(BuildContext context) {
    final Color c = enLigne ? AppColors.success : AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        enLigne ? 'Disponible' : 'Indisponible',
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c),
      ),
    );
  }
}
