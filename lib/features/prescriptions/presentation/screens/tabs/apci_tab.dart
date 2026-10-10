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
import '../apci_detail_screen.dart';

/// APCI : maladies (code CIM-10) prises en charge à 100 %.
/// Le médecin tient la liste des maladies ; le pharmacien, les médicaments
/// couverts par chacune.
class ApciTab extends StatefulWidget {
  const ApciTab({super.key, required this.role});

  final Role role;

  @override
  State<ApciTab> createState() => _ApciTabState();
}

class _ApciTabState extends State<ApciTab> {
  final ApciRepository _repo = ApciRepository();

  List<Apci> _liste = [];
  Map<String, int> _nbDci = {};
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
    final Map<String, int> nbDci = await _repo.nbDciParCode();
    if (!mounted || requete != _requete) {
      return;
    }
    setState(() {
      _liste = res;
      _nbDci = nbDci;
      _chargement = false;
    });
  }

  Future<void> _ajouter() async {
    final bool modifie = await afficherApciDialog(context);
    if (modifie) {
      _charger();
    }
  }

  Future<void> _ouvrir(Apci apci) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(builder: (_) => ApciDetailScreen(apci: apci, role: widget.role)),
    );
    _charger();
  }

  String _sousTitre(Apci a) {
    final int n = _nbDci[a.codeCim10] ?? 0;
    if (n == 0) {
      return 'Aucun médicament couvert';
    }
    return '$n médicament${n > 1 ? 's' : ''} couvert${n > 1 ? 's' : ''} (DCI)';
  }

  @override
  Widget build(BuildContext context) {
    final bool gererCodes = widget.role.gererApci;

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          EnTetePage(
            surtitre: gererCodes ? 'Maladies prises en charge à 100 %' : 'Médicaments couverts à 100 %',
            titre: 'APCI',
            trailing: gererCodes
                ? BoutonAjout(tooltip: 'Ajouter une maladie', onPressed: _ajouter)
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
                            final bool sansMedicament = (_nbDci[a.codeCim10] ?? 0) == 0;
                            return Card(
                              margin: EdgeInsets.zero,
                              clipBehavior: Clip.antiAlias,
                              child: ListTile(
                                onTap: () => _ouvrir(a),
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
                                subtitle: Text(
                                  _sousTitre(a),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: sansMedicament ? AppColors.warning : AppColors.textSecondary,
                                  ),
                                ),
                                trailing: const Icon(Icons.chevron_right_rounded),
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
