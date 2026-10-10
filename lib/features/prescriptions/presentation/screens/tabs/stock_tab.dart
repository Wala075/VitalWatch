import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/empty_state.dart';
import '../../../../../core/widgets/search_field.dart';
import '../../../data/medicament_repository.dart';
import '../../../domain/formats_prescriptions.dart';
import '../../../domain/models/medicament.dart';
import '../../../domain/regles_stock.dart';
import '../../widgets/elements_ui.dart';
import '../../widgets/graphiques.dart';

/// Pharmacien : stock des médicaments (ruptures et stocks faibles d'abord),
/// entrées de stock. Chaque délivrance retire les boîtes du stock.
class StockTab extends StatefulWidget {
  const StockTab({super.key});

  @override
  State<StockTab> createState() => _StockTabState();
}

class _StockTabState extends State<StockTab> {
  final MedicamentRepository _repo = MedicamentRepository();

  List<Medicament> _medicaments = [];
  int _ruptures = 0;
  int _faibles = 0;
  NiveauStock? _niveau;
  String _texte = '';
  bool _chargement = true;
  int _requete = 0;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    final int requete = ++_requete;
    final List<Medicament> res = await _repo.stock(texte: _texte, niveau: _niveau);
    final ({int ruptures, int faibles}) alertes = await _repo.alertesStock();
    if (!mounted || requete != _requete) {
      return;
    }
    setState(() {
      _medicaments = res;
      _ruptures = alertes.ruptures;
      _faibles = alertes.faibles;
      _chargement = false;
    });
  }

  void _filtrer(NiveauStock? n) {
    setState(() => _niveau = _niveau == n ? null : n);
    _charger();
  }

  Future<void> _entree(Medicament m) async {
    final int? boites = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _EntreeStock(medicament: m),
    );
    if (boites == null) {
      return;
    }
    await _repo.ajouterStock(m.id!, boites);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${m.libelle} : +${ReglesStock.boites(boites)}')),
    );
    _charger();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          const EnTetePage(surtitre: 'Pharmacie', titre: 'Stock'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: _TuileFiltre(
                    selectionnee: _niveau == NiveauStock.rupture,
                    onTap: () => _filtrer(NiveauStock.rupture),
                    child: TuileChiffre(
                      libelle: 'En rupture',
                      valeur: '$_ruptures',
                      icon: StyleStock.icone(NiveauStock.rupture),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _TuileFiltre(
                    selectionnee: _niveau == NiveauStock.faible,
                    onTap: () => _filtrer(NiveauStock.faible),
                    child: TuileChiffre(
                      libelle: 'Stock faible (≤ ${ReglesStock.seuilFaible})',
                      valeur: '$_faibles',
                      icon: StyleStock.icone(NiveauStock.faible),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SearchField(
              hint: 'Nom, DCI ou code-barres',
              onChanged: (String v) {
                _texte = v;
                _charger();
              },
            ),
          ),
          if (_niveau != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: InputChip(
                  label: Text(_niveau!.libelle),
                  onDeleted: () => _filtrer(null),
                ),
              ),
            ),
          Expanded(
            child: _chargement
                ? const Center(child: CircularProgressIndicator())
                : _medicaments.isEmpty
                    ? const EmptyState(icon: Icons.inventory_2_outlined, message: 'Aucun médicament')
                    : RefreshIndicator(
                        onRefresh: _charger,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(20, 10, 20, 120),
                          itemCount: _medicaments.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (BuildContext context, int i) {
                            final Medicament m = _medicaments[i];
                            return Card(
                              margin: EdgeInsets.zero,
                              clipBehavior: Clip.antiAlias,
                              child: ListTile(
                                onTap: () => _entree(m),
                                contentPadding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
                                leading: CircleAvatar(
                                  backgroundColor:
                                      StyleStock.couleur(ReglesStock.niveau(m.stock)).withValues(alpha: 0.12),
                                  child: Text(
                                    '${m.stock}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: StyleStock.couleur(ReglesStock.niveau(m.stock)),
                                    ),
                                  ),
                                ),
                                title: Text(m.libelle, style: const TextStyle(fontWeight: FontWeight.w700)),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${m.dci} · ${FormatsPrescriptions.dt(m.prixPublic)} la boîte',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    const SizedBox(height: 4),
                                    StyleStock.badge(m.stock),
                                  ],
                                ),
                                trailing: IconButton(
                                  tooltip: 'Entrée de stock',
                                  icon: const Icon(Icons.add_box_outlined, color: AppColors.primary),
                                  onPressed: () => _entree(m),
                                ),
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

/// Tuile chiffrée qui sert aussi de filtre.
class _TuileFiltre extends StatelessWidget {
  const _TuileFiltre({required this.selectionnee, required this.onTap, required this.child});

  final bool selectionnee;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selectionnee ? AppColors.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: child,
      ),
    );
  }
}

/// Saisie d'une entrée de stock (boîtes reçues).
class _EntreeStock extends StatefulWidget {
  const _EntreeStock({required this.medicament});

  final Medicament medicament;

  @override
  State<_EntreeStock> createState() => _EntreeStockState();
}

class _EntreeStockState extends State<_EntreeStock> {
  final TextEditingController _ctrl = TextEditingController(text: '10');
  String? _erreur;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _valider() {
    final int? n = int.tryParse(_ctrl.text.trim());
    final String? erreur = ReglesStock.verifierEntree(n);
    if (erreur != null) {
      setState(() => _erreur = erreur);
      return;
    }
    Navigator.pop(context, n);
  }

  void _ajouter(int delta) {
    final int n = (int.tryParse(_ctrl.text.trim()) ?? 0) + delta;
    _ctrl.text = '${n < 1 ? 1 : n}';
  }

  @override
  Widget build(BuildContext context) {
    final Medicament m = widget.medicament;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(m.libelle, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Row(children: [const Text('Stock actuel : '), StyleStock.badge(m.stock)]),
            const SizedBox(height: 16),
            Row(
              children: [
                IconButton(
                  tooltip: 'Moins',
                  onPressed: () => _ajouter(-1),
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: 'Boîtes reçues',
                      errorText: _erreur,
                      border: const OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _valider(),
                  ),
                ),
                IconButton(
                  tooltip: 'Plus',
                  onPressed: () => _ajouter(1),
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _valider,
              icon: const Icon(Icons.move_to_inbox_rounded),
              label: const Text('Ajouter au stock'),
            ),
          ],
        ),
      ),
    );
  }
}
