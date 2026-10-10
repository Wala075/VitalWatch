import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../core/widgets/error_banner.dart';
import '../../../../core/widgets/search_field.dart';
import '../../../../models/utilisateur.dart';
import '../../data/apci_repository.dart';
import '../../data/medicament_repository.dart';
import '../../domain/couverture_apci.dart';
import '../../domain/models/apci.dart';
import '../../domain/prescriptions_exception.dart';
import '../../domain/prescriptions_permissions.dart';
import '../../domain/referentiels_manager.dart';
import '../widgets/apci_dialog.dart';
import '../widgets/elements_ui.dart';

/// Une maladie APCI et les médicaments (par DCI) qu'elle couvre à 100 %.
/// Médecin : code et libellé. Pharmacien : liste des médicaments.
class ApciDetailScreen extends StatefulWidget {
  const ApciDetailScreen({super.key, required this.apci, required this.role});

  final Apci apci;
  final Role role;

  @override
  State<ApciDetailScreen> createState() => _ApciDetailScreenState();
}

class _ApciDetailScreenState extends State<ApciDetailScreen> {
  final ApciRepository _repo = ApciRepository();
  final MedicamentRepository _medicaments = MedicamentRepository();
  final ReferentielsManager _manager = ReferentielsManager();

  late Apci _apci = widget.apci;
  List<String> _dcis = [];
  Map<String, List<String>> _noms = {};
  int _nbContrats = 0;
  bool _chargement = true;
  String? _erreur;

  bool get _gererMedicaments => widget.role.gererMedicamentsApci;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    final List<String> dcis = await _repo.dcis(_apci.codeCim10);
    final Map<String, List<String>> noms = await _medicaments.nomsParDci();
    final int nbContrats = await _repo.nbContrats(_apci.codeCim10);
    if (!mounted) {
      return;
    }
    setState(() {
      _dcis = dcis;
      _noms = noms;
      _nbContrats = nbContrats;
      _chargement = false;
    });
  }

  /// Noms commerciaux du catalogue pour une DCI (comparaison sans casse).
  List<String> _nomsDe(String dci) {
    final String cle = CouvertureApci.normaliser(dci);
    for (final String d in _noms.keys) {
      if (CouvertureApci.normaliser(d) == cle) {
        return _noms[d]!;
      }
    }
    return const [];
  }

  Future<void> _modifierCode() async {
    final bool modifie = await afficherApciDialog(context, apci: _apci);
    if (!modifie || !mounted) {
      return;
    }
    final Apci? a = await _repo.parCode(_apci.codeCim10);
    if (!mounted) {
      return;
    }
    if (a == null) {
      Navigator.pop(context);
      return;
    }
    setState(() => _apci = a);
  }

  Future<void> _ajouter() async {
    final Set<String> deja = {};
    for (final String d in _dcis) {
      deja.add(CouvertureApci.normaliser(d));
    }
    final List<String> choix = [];
    for (final String d in _noms.keys) {
      if (!deja.contains(CouvertureApci.normaliser(d))) {
        choix.add(d);
      }
    }
    final String? dci = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _ChoixDci(dcis: choix, noms: _noms),
    );
    if (dci == null) {
      return;
    }
    await _executer(() => _manager.lierDciApci(_apci.codeCim10, dci));
  }

  Future<void> _retirer(String dci) async {
    final bool ok = await showConfirmDialog(
      context,
      titre: 'Retirer $dci ?',
      message: "Les lignes liées à l'APCI ${_apci.codeCim10} avec ce médicament "
          'passeront au taux normal.',
      confirmer: 'Retirer',
      danger: true,
    );
    if (ok) {
      await _executer(() => _manager.delierDciApci(_apci.codeCim10, dci));
    }
  }

  Future<void> _executer(Future<void> Function() action) async {
    setState(() => _erreur = null);
    try {
      await action();
    } on PrescriptionsException catch (e) {
      if (mounted) {
        setState(() => _erreur = e.message);
      }
    }
    await _charger();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('APCI ${_apci.codeCim10}'),
        actions: [
          if (widget.role.gererApci)
            IconButton(
              tooltip: 'Modifier ou supprimer la maladie',
              icon: const Icon(Icons.edit_outlined),
              onPressed: _modifierCode,
            ),
        ],
      ),
      body: _chargement
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _charger,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                children: [
                  Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _apci.libelle,
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 16,
                            runSpacing: 6,
                            children: [
                              InfoLigne(icon: Icons.tag_rounded, texte: 'CIM-10 ${_apci.codeCim10}'),
                              InfoLigne(
                                icon: Icons.people_outline_rounded,
                                texte: '$_nbContrats patient${_nbContrats > 1 ? 's' : ''} en APCI',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Médicaments couverts à 100 %',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                        ),
                      ),
                      if (_gererMedicaments)
                        TextButton.icon(
                          onPressed: _ajouter,
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Ajouter'),
                        ),
                    ],
                  ),
                  Text(
                    _gererMedicaments
                        ? "À la délivrance, une ligne liée à l'APCI par le médecin n'est prise en "
                            'charge à 100 % que si son médicament (DCI) figure ici : princeps et '
                            'génériques compris.'
                        : 'Liste tenue par le pharmacien. Une ligne cochée « APCI » avec un autre '
                            'médicament est remboursée au taux normal.',
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  if (_erreur != null) ...[
                    ErrorBanner(message: _erreur!),
                    const SizedBox(height: 12),
                  ],
                  if (_dcis.isEmpty)
                    const Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'Aucun médicament couvert pour le moment',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                    )
                  else
                    for (final String dci in _dcis)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Card(
                          margin: EdgeInsets.zero,
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppColors.success.withValues(alpha: 0.12),
                              child: const Icon(Icons.medication_rounded, color: AppColors.success),
                            ),
                            title: Text(dci, style: const TextStyle(fontWeight: FontWeight.w700)),
                            subtitle: Text(
                              _nomsDe(dci).isEmpty ? 'Pas dans le catalogue' : _nomsDe(dci).join(', '),
                            ),
                            trailing: _gererMedicaments
                                ? IconButton(
                                    tooltip: 'Retirer',
                                    icon: const Icon(Icons.remove_circle_outline, color: AppColors.danger),
                                    onPressed: () => _retirer(dci),
                                  )
                                : null,
                          ),
                        ),
                      ),
                ],
              ),
            ),
    );
  }
}

/// Choix d'une DCI du catalogue pas encore couverte par l'APCI.
class _ChoixDci extends StatefulWidget {
  const _ChoixDci({required this.dcis, required this.noms});

  final List<String> dcis;
  final Map<String, List<String>> noms;

  @override
  State<_ChoixDci> createState() => _ChoixDciState();
}

class _ChoixDciState extends State<_ChoixDci> {
  String _texte = '';

  List<String> get _filtrees {
    final String t = _texte.trim().toLowerCase();
    if (t.isEmpty) {
      return widget.dcis;
    }
    final List<String> res = [];
    for (final String d in widget.dcis) {
      final String noms = (widget.noms[d] ?? const <String>[]).join(' ').toLowerCase();
      if (d.toLowerCase().contains(t) || noms.contains(t)) {
        res.add(d);
      }
    }
    return res;
  }

  @override
  Widget build(BuildContext context) {
    final List<String> liste = _filtrees;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: SearchField(
                  hint: 'DCI ou nom commercial',
                  onChanged: (String v) => setState(() => _texte = v),
                ),
              ),
              Expanded(
                child: liste.isEmpty
                    ? const Center(
                        child: Text(
                          'Tous les médicaments du catalogue sont déjà couverts',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      )
                    : ListView.builder(
                        itemCount: liste.length,
                        itemBuilder: (BuildContext context, int i) {
                          final String d = liste[i];
                          return ListTile(
                            leading: const Icon(Icons.medication_outlined, color: AppColors.primary),
                            title: Text(d, style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text((widget.noms[d] ?? const <String>[]).join(', ')),
                            onTap: () => Navigator.pop(context, d),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
