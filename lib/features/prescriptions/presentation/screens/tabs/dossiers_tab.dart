import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/empty_state.dart';
import '../../../domain/models/dossier_remboursement.dart';
import '../../../domain/models/vues_remboursement.dart';
import '../../../domain/remboursement_manager.dart';
import '../../widgets/carte_dossier.dart';
import '../../widgets/elements_ui.dart';
import '../dossier_detail_screen.dart';

/// Admin : tous les dossiers de remboursement, par statut, avec relances.
class DossiersTab extends StatefulWidget {
  const DossiersTab({super.key});

  @override
  State<DossiersTab> createState() => _DossiersTabState();
}

class _DossiersTabState extends State<DossiersTab> {
  final RemboursementManager _manager = RemboursementManager();

  List<DossierResume> _dossiers = [];
  StatutDossier? _statut;
  bool _chargement = true;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    final List<DossierResume> res = await _manager.dossiers(statut: _statut);
    if (!mounted) {
      return;
    }
    setState(() {
      _dossiers = res;
      _chargement = false;
    });
  }

  Future<void> _ouvrir(DossierResume d) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(builder: (_) => DossierDetailScreen(dossierId: d.dossier.id!, admin: true)),
    );
    _charger();
  }

  @override
  Widget build(BuildContext context) {
    int relances = 0;
    for (final DossierResume d in _dossiers) {
      if (d.enRetard) {
        relances++;
      }
    }

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          const EnTetePage(surtitre: 'CNAM simulée', titre: 'Dossiers'),
          SizedBox(
            height: 46,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                _Puce(
                  libelle: 'Tous',
                  selectionnee: _statut == null,
                  onTap: () {
                    setState(() => _statut = null);
                    _charger();
                  },
                ),
                for (final StatutDossier s in StatutDossier.values)
                  _Puce(
                    libelle: s.libelle,
                    selectionnee: _statut == s,
                    onTap: () {
                      setState(() => _statut = s);
                      _charger();
                    },
                  ),
              ],
            ),
          ),
          if (relances > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  '$relances dossier${relances > 1 ? 's' : ''} sans réponse au-delà du délai : '
                  'relance automatique',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          Expanded(
            child: _chargement
                ? const Center(child: CircularProgressIndicator())
                : _dossiers.isEmpty
                    ? const EmptyState(icon: Icons.receipt_long_outlined, message: 'Aucun dossier')
                    : RefreshIndicator(
                        onRefresh: _charger,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(20, 10, 20, 120),
                          itemCount: _dossiers.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 10),
                          itemBuilder: (BuildContext context, int i) {
                            final DossierResume d = _dossiers[i];
                            return CarteDossier(resume: d, afficherPatient: true, onTap: () => _ouvrir(d));
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _Puce extends StatelessWidget {
  const _Puce({required this.libelle, required this.selectionnee, required this.onTap});

  final String libelle;
  final bool selectionnee;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(libelle),
        selected: selectionnee,
        showCheckmark: false,
        selectedColor: AppColors.primary,
        labelStyle: TextStyle(
          fontWeight: FontWeight.w700,
          color: selectionnee ? Colors.white : AppColors.textPrimary,
        ),
        onSelected: (_) => onTap(),
      ),
    );
  }
}
