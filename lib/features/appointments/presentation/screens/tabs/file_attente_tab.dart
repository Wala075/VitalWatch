import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/app_dropdown_field.dart';
import '../../../../../core/widgets/empty_state.dart';
import '../../../../../models/medecin.dart';
import '../../../../../models/utilisateur.dart';
import '../../../domain/rdv_manager.dart';
import '../../../domain/rdv_models.dart';
import '../../../domain/rdv_permissions.dart';
import '../../../domain/rdv_regles.dart';
import '../../widgets/rdv_widgets.dart';
import '../rdv_detail_screen.dart';

/// File d'attente du jour, priorisée :
/// en cours > urgent > prioritaire (alerte récente) > normal, puis par heure.
/// Rafraîchie automatiquement toutes les minutes.
class FileAttenteTab extends StatefulWidget {
  const FileAttenteTab({super.key, required this.utilisateur, this.rafraichir});

  final Utilisateur utilisateur;
  final ValueNotifier<int>? rafraichir;

  @override
  State<FileAttenteTab> createState() => _FileAttenteTabState();
}

class _FileAttenteTabState extends State<FileAttenteTab> {
  final RdvManager _manager = RdvManager();

  List<RdvDetail> _file = [];
  List<Medecin> _medecins = [];
  int? _medecinId;
  bool _chargement = true;
  Timer? _timer;
  int _requete = 0;

  Utilisateur get _u => widget.utilisateur;

  @override
  void initState() {
    super.initState();
    widget.rafraichir?.addListener(_charger);
    if (_u.role.voirTousLesRdv) {
      _manager.medecins().then((List<Medecin> m) {
        if (mounted) {
          setState(() => _medecins = m);
        }
      });
    }
    _charger();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => _charger());
  }

  @override
  void dispose() {
    _timer?.cancel();
    widget.rafraichir?.removeListener(_charger);
    super.dispose();
  }

  Future<void> _charger() async {
    final int requete = ++_requete;
    final List<RdvDetail> f = await _manager.fileAttente(_u, medecinId: _medecinId);
    if (!mounted || requete != _requete) {
      return;
    }
    setState(() {
      _file = f;
      _chargement = false;
    });
  }

  Future<void> _ouvrir(RdvDetail d) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => RdvDetailScreen(rdvId: d.rdv.id ?? 0, utilisateur: _u),
      ),
    );
    _charger();
  }

  @override
  Widget build(BuildContext context) {
    final int urgents = _file.where((RdvDetail d) => d.rdv.estUrgent).length;
    final int visios = _file.where((RdvDetail d) => d.rdv.type == TypeRdv.visio).length;
    final bool tous = _u.role.voirTousLesRdv;

    return RefreshIndicator(
      onRefresh: _charger,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
        children: [
          Text(
            "Aujourd'hui · ${RdvFormat.jour(DateTime.now())}",
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _Compteur(valeur: _file.length, libelle: 'En file', couleur: AppColors.primary),
              const SizedBox(width: 8),
              _Compteur(valeur: urgents, libelle: 'Urgents', couleur: AppColors.danger),
              const SizedBox(width: 8),
              _Compteur(valeur: visios, libelle: 'Visios', couleur: AppColors.indigo),
            ],
          ),
          const SizedBox(height: 12),
          if (tous) ...[
            AppDropdownField<int?>(
              label: 'Médecin',
              icon: Icons.medical_services_outlined,
              value: _medecinId,
              items: [
                const DropdownMenuItem<int?>(value: null, child: Text('Tous les médecins')),
                for (final Medecin m in _medecins)
                  DropdownMenuItem<int?>(value: m.id, child: Text(m.nomComplet)),
              ],
              onChanged: (int? v) {
                setState(() => _medecinId = v);
                _charger();
              },
            ),
            const SizedBox(height: 12),
          ],
          if (_chargement)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_file.isEmpty)
            const EmptyState(
              icon: Icons.free_breakfast_rounded,
              message: "Personne en file d'attente pour aujourd'hui",
            )
          else
            for (int i = 0; i < _file.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: RdvCard(
                  detail: _file[i],
                  rang: i + 1,
                  onTap: () => _ouvrir(_file[i]),
                  afficherMedecin: tous,
                ),
              ),
        ],
      ),
    );
  }
}

class _Compteur extends StatelessWidget {
  const _Compteur({required this.valeur, required this.libelle, required this.couleur});

  final int valeur;
  final String libelle;
  final Color couleur;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(
              '$valeur',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: couleur),
            ),
            Text(libelle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}
