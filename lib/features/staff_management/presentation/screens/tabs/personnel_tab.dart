import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/page_title.dart';
import '../../../../../models/utilisateur.dart';
import '../../widgets/bouton_ajout.dart';
import '../ambulancier_form_screen.dart';
import '../infirmier_form_screen.dart';
import '../medecin_form_screen.dart';
import '../pharmacien_form_screen.dart';
import 'ambulanciers_liste.dart';
import 'infirmiers_liste.dart';
import 'medecins_tab.dart';
import 'pharmaciens_liste.dart';

enum CategoriePersonnel {
  medecins('Médecins', 'un médecin'),
  infirmiers('Infirmiers', 'un infirmier'),
  ambulanciers('Ambulanciers', 'un ambulancier'),
  pharmaciens('Pharmaciens', 'un pharmacien');

  const CategoriePersonnel(this.libelle, this.unite);

  final String libelle;
  final String unite;
}

/// Onglet Personnel : médecins, infirmiers, ambulanciers et pharmaciens.
/// L'admin ajoute, modifie et supprime ; les autres consultent.
class PersonnelTab extends StatefulWidget {
  const PersonnelTab({super.key, required this.role});

  final Role role;

  @override
  State<PersonnelTab> createState() => _PersonnelTabState();
}

class _PersonnelTabState extends State<PersonnelTab>
    with SingleTickerProviderStateMixin {
  late final TabController _onglets =
      TabController(length: CategoriePersonnel.values.length, vsync: this);

  /// Change la clé de la liste après un ajout : elle se recharge.
  int _version = 0;

  CategoriePersonnel get _categorie => CategoriePersonnel.values[_onglets.index];

  bool get _peutAjouter => _categorie == CategoriePersonnel.medecins
      ? widget.role.gererMedecins
      : widget.role.gererPersonnel;

  @override
  void initState() {
    super.initState();
    _onglets.addListener(_changement);
  }

  void _changement() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _onglets.removeListener(_changement);
    _onglets.dispose();
    super.dispose();
  }

  Future<void> _ajouter() async {
    final Widget formulaire = switch (_categorie) {
      CategoriePersonnel.medecins => const MedecinFormScreen(),
      CategoriePersonnel.infirmiers => const InfirmierFormScreen(),
      CategoriePersonnel.ambulanciers => const AmbulancierFormScreen(),
      CategoriePersonnel.pharmaciens => const PharmacienFormScreen(),
    };
    final bool? ajoute = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => formulaire),
    );
    if (ajoute == true && mounted) setState(() => _version++);
  }

  @override
  Widget build(BuildContext context) {
    final Widget liste = switch (_categorie) {
      CategoriePersonnel.medecins =>
        MedecinsListe(key: ValueKey<String>('m$_version'), role: widget.role),
      CategoriePersonnel.infirmiers =>
        InfirmiersListe(key: ValueKey<String>('i$_version'), role: widget.role),
      CategoriePersonnel.ambulanciers =>
        AmbulanciersListe(key: ValueKey<String>('a$_version'), role: widget.role),
      CategoriePersonnel.pharmaciens =>
        PharmaciensListe(key: ValueKey<String>('p$_version'), role: widget.role),
    };

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          PageTitle(
            surtitre: 'Équipe',
            titre: 'Personnel',
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
            trailing: _peutAjouter
                ? BoutonAjout(
                    tooltip: 'Ajouter ${_categorie.unite}',
                    onPressed: _ajouter,
                  )
                : null,
          ),
          TabBar(
            controller: _onglets,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primary,
            indicatorSize: TabBarIndicatorSize.label,
            dividerColor: Colors.transparent,
            labelStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            unselectedLabelStyle:
                const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            tabs: [
              for (final CategoriePersonnel c in CategoriePersonnel.values)
                Tab(text: c.libelle),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(child: liste),
        ],
      ),
    );
  }
}
