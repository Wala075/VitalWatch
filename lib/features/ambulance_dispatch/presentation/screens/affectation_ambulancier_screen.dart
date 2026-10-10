import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_dropdown_field.dart';
import '../../../../core/widgets/error_banner.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../domain/dispatch_manager.dart';
import '../../domain/dispatch_models.dart';
import '../../domain/models/ambulance.dart';
import '../../domain/models/ambulancier.dart';
import '../providers/dispatch_controller.dart';
import '../widgets/dispatch_ui.dart';

/// Affectation d'un ambulancier à une ambulance (admin).
///
/// L'ambulancier lui-même (nom, rôle, téléphone, disponibilité, compte) est
/// géré par le module 1 (Personnel) : ici on choisit seulement son ambulance.
class AffectationAmbulancierScreen extends StatefulWidget {
  const AffectationAmbulancierScreen({super.key, required this.ambulancier});

  final Ambulancier ambulancier;

  @override
  State<AffectationAmbulancierScreen> createState() => _AffectationAmbulancierScreenState();
}

class _AffectationAmbulancierScreenState extends State<AffectationAmbulancierScreen> {
  final DispatchController _ctrl = DispatchController.instance;

  int? _ambulanceId;
  bool _enregistrement = false;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _ambulanceId = widget.ambulancier.ambulanceId;
  }

  Future<void> _enregistrer() async {
    final int? id = widget.ambulancier.id;
    if (id == null) {
      return;
    }
    setState(() {
      _enregistrement = true;
      _erreur = null;
    });
    try {
      await _ctrl.manager.affecterAmbulancier(id, _ambulanceId);
      await _ctrl.rafraichir();
      if (mounted) {
        Navigator.pop(context, true);
      }
    } on DispatchException catch (e) {
      _echec(e.message);
    } catch (e) {
      _echec('Affectation impossible : $e');
    }
  }

  void _echec(String message) {
    if (!mounted) {
      return;
    }
    setState(() {
      _erreur = message;
      _enregistrement = false;
    });
  }

  List<DropdownMenuItem<int?>> _ambulances() {
    final List<DropdownMenuItem<int?>> items = [
      const DropdownMenuItem<int?>(value: null, child: Text('Non affecté')),
    ];
    bool actuelleListee = _ambulanceId == null;
    for (final AmbulanceDetail d in _ctrl.flotte) {
      final Ambulance a = d.ambulance;
      if (a.id == _ambulanceId) {
        actuelleListee = true;
      }
      final String mission = a.statut == StatutAmbulance.enMission ? ' · en mission' : '';
      items.add(DropdownMenuItem<int?>(
        value: a.id,
        child: Text(
          '${a.immatriculation} · ${a.type.libelle} '
          '(${d.nbEquipiers}/${DispatchManager.maxEquipiers})$mission',
          overflow: TextOverflow.ellipsis,
        ),
      ));
    }
    if (!actuelleListee) {
      // Flotte pas encore chargée : garder l'affectation actuelle.
      items.add(DropdownMenuItem<int?>(
        value: _ambulanceId,
        child: Text('Ambulance n°$_ambulanceId'),
      ));
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final Ambulancier a = widget.ambulancier;
    final String? erreur = _erreur;

    return Scaffold(
      appBar: AppBar(title: const Text('Affecter à une ambulance')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (erreur != null) ...[
            ErrorBanner(message: erreur),
            const SizedBox(height: 12),
          ],
          Section(
            titre: 'Ambulancier',
            icone: Icons.badge_outlined,
            action: Pastille(
              libelle: a.disponible ? 'Dispo' : 'Absent',
              couleur: a.disponible ? AppColors.success : AppColors.textSecondary,
              icone: a.disponible ? Icons.check : Icons.do_not_disturb_on_outlined,
            ),
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                    child: Text(
                      a.initiales,
                      style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(a.nom, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                        Text(
                          '${a.role.libelle} · ${Formatters.telephone(a.telephone)}',
                          style: const TextStyle(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Info(
                icone: Icons.info_outline,
                texte: 'Fiche, disponibilité et compte : espace Personnel (module 1)',
              ),
            ],
          ),
          const SizedBox(height: 14),
          Section(
            titre: 'Affectation',
            icone: Icons.airport_shuttle_outlined,
            children: [
              AppDropdownField<int?>(
                label: 'Ambulance',
                icon: Icons.airport_shuttle,
                value: _ambulanceId,
                items: _ambulances(),
                onChanged: (int? id) => setState(() => _ambulanceId = id),
              ),
              const Info(
                icone: Icons.rule,
                texte: '${DispatchManager.maxEquipiers} ambulanciers maximum par ambulance · '
                    'équipage figé pendant une mission',
              ),
              if (!a.disponible)
                const Info(
                  icone: Icons.warning_amber_rounded,
                  texte: 'Absent : il ne compte pas dans l\'équipage tant qu\'il '
                      'n\'est pas remis disponible',
                  couleur: AppColors.warning,
                ),
            ],
          ),
          const SizedBox(height: 20),
          PrimaryButton(
            label: "Enregistrer l'affectation",
            icon: Icons.save_outlined,
            loading: _enregistrement,
            onPressed: _enregistrer,
          ),
        ],
      ),
    );
  }
}
