import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/utils/formatters.dart';
import '../../../../../core/widgets/empty_state.dart';
import '../../../../../core/widgets/search_field.dart';
import '../../../data/ambulancier_repository.dart';
import '../../../domain/dispatch_models.dart';
import '../../../domain/models/ambulancier.dart';
import '../../providers/dispatch_controller.dart';
import '../../widgets/dispatch_ui.dart';
import '../affectation_ambulancier_screen.dart';

/// Ambulanciers et leur affectation aux ambulances.
///
/// Les ambulanciers sont ajoutés, modifiés et supprimés dans le module 1
/// (Personnel, table partagée) : l'admin les affecte ici à une ambulance.
class EquipagesTab extends StatefulWidget {
  const EquipagesTab({super.key, required this.gerer});

  final bool gerer;

  @override
  State<EquipagesTab> createState() => _EquipagesTabState();
}

class _EquipagesTabState extends State<EquipagesTab> {
  final AmbulancierRepository _repo = AmbulancierRepository();
  final DispatchController _ctrl = DispatchController.instance;

  List<AmbulancierDetail> _liste = [];
  bool _chargement = true;
  String _texte = '';
  RoleAmbulancier? _role;
  int _requete = 0;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    final int requete = ++_requete;
    final List<AmbulancierDetail> res = await _repo.rechercher(texte: _texte, role: _role);
    if (!mounted || requete != _requete) {
      return;
    }
    setState(() {
      _liste = res;
      _chargement = false;
    });
  }

  Future<void> _affecter(Ambulancier a) async {
    final bool? modifie = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AffectationAmbulancierScreen(ambulancier: a),
      ),
    );
    if (modifie == true) {
      await _ctrl.rafraichir();
      _charger();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          if (widget.gerer)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Info(
                icone: Icons.info_outline,
                texte: 'Touchez un ambulancier pour l\'affecter à une ambulance. '
                    'Ajout et modification : espace Personnel.',
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: SearchField(
              hint: 'Nom ou téléphone',
              onChanged: (String v) {
                _texte = v;
                _charger();
              },
            ),
          ),
          SizedBox(
            height: 46,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: const Text('Tous'),
                    selected: _role == null,
                    showCheckmark: false,
                    onSelected: (_) {
                      _role = null;
                      _charger();
                    },
                  ),
                ),
                for (final RoleAmbulancier r in RoleAmbulancier.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(r.libelle),
                      selected: _role == r,
                      showCheckmark: false,
                      onSelected: (_) {
                        _role = r;
                        _charger();
                      },
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _chargement
                ? const Center(child: CircularProgressIndicator())
                : _liste.isEmpty
                    ? const EmptyState(icon: Icons.groups_outlined, message: 'Aucun ambulancier')
                    : RefreshIndicator(
                        onRefresh: _charger,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                          itemCount: _liste.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (BuildContext context, int i) {
                            final AmbulancierDetail d = _liste[i];
                            return _CarteAmbulancier(
                              detail: d,
                              onTap: widget.gerer ? () => _affecter(d.ambulancier) : null,
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

class _CarteAmbulancier extends StatelessWidget {
  const _CarteAmbulancier({required this.detail, this.onTap});

  final AmbulancierDetail detail;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Ambulancier a = detail.ambulancier;
    final String? immat = detail.immatriculation;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withValues(alpha: 0.12),
          child: Text(
            a.initiales,
            style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary),
          ),
        ),
        title: Text(a.nom, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(
          '${a.role.libelle} · ${Formatters.telephone(a.telephone)}\n'
          '${immat == null ? 'Non affecté' : 'Ambulance $immat'}',
        ),
        isThreeLine: true,
        trailing: Pastille(
          libelle: a.disponible ? 'Dispo' : 'Absent',
          couleur: a.disponible ? AppColors.success : AppColors.textSecondary,
          icone: a.disponible ? Icons.check : Icons.do_not_disturb_on_outlined,
        ),
      ),
    );
  }
}
