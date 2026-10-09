import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/empty_state.dart';
import '../../../../../core/widgets/search_field.dart';
import '../../../../../models/utilisateur.dart';
import '../../../data/apci_repository.dart';
import '../../../domain/models/apci.dart';
import '../../../domain/prescriptions_permissions.dart';
import '../../widgets/apci_dialog.dart';
import '../../widgets/elements_ui.dart';

/// Référentiel APCI : maladies (code CIM-10) prises en charge à 100 %.
class ApciTab extends StatefulWidget {
  const ApciTab({super.key, required this.role});

  final Role role;

  @override
  State<ApciTab> createState() => _ApciTabState();
}

class _ApciTabState extends State<ApciTab> {
  final ApciRepository _repo = ApciRepository();

  List<Apci> _liste = [];
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
    final List<Apci> res = await _repo.lister(texte: _texte);
    if (!mounted || requete != _requete) {
      return;
    }
    setState(() {
      _liste = res;
      _chargement = false;
    });
  }

  Future<void> _ouvrir([Apci? apci]) async {
    final bool modifie = await afficherApciDialog(context, apci: apci);
    if (modifie) {
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
            surtitre: 'Prise en charge à 100 %',
            titre: 'APCI',
            trailing: gerer
                ? BoutonAjout(tooltip: 'Ajouter une maladie', onPressed: () => _ouvrir())
                : null,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SearchField(
              hint: 'Code CIM-10 ou maladie',
              onChanged: (String v) {
                _texte = v;
                _charger();
              },
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: _chargement
                ? const Center(child: CircularProgressIndicator())
                : _liste.isEmpty
                    ? const EmptyState(
                        icon: Icons.favorite_border_rounded,
                        message: 'Aucune maladie APCI',
                      )
                    : RefreshIndicator(
                        onRefresh: _charger,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
                          itemCount: _liste.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (BuildContext context, int i) {
                            final Apci a = _liste[i];
                            return Card(
                              margin: EdgeInsets.zero,
                              clipBehavior: Clip.antiAlias,
                              child: ListTile(
                                onTap: gerer ? () => _ouvrir(a) : null,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                leading: Container(
                                  width: 56,
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    a.codeCim10,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.primaryDark,
                                    ),
                                  ),
                                ),
                                title: Text(
                                  a.libelle,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                trailing: gerer
                                    ? const Icon(Icons.chevron_right_rounded)
                                    : null,
                              ),
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
