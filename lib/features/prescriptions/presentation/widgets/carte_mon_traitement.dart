import 'package:flutter/material.dart';

import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared_providers/session.dart';
import '../../domain/models/vues_traitement.dart';
import '../../domain/traitement_manager.dart';

/// Carte « Mon traitement » de l'accueil du patient : prochaine prise et
/// observance. Ouvre l'espace Ordonnances du patient.
class CarteMonTraitement extends StatefulWidget {
  const CarteMonTraitement({super.key});

  @override
  State<CarteMonTraitement> createState() => _CarteMonTraitementState();
}

class _CarteMonTraitementState extends State<CarteMonTraitement> {
  final TraitementManager _manager = TraitementManager();

  PrisePlanifiee? _prochaine;
  double? _observance;
  int _alertesStock = 0;
  bool _charge = false;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    final int? patientId = Session.utilisateur?.refId;
    if (patientId == null) {
      return;
    }
    try {
      await _manager.marquerOubliees();
      final PrisePlanifiee? prochaine = await _manager.prochainePrise(patientId);
      final double? observance = await _manager.observance(patientId);
      int alertes = 0;
      for (final StockTraitement s in await _manager.stocks(patientId)) {
        if (s.alerte) {
          alertes++;
        }
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _prochaine = prochaine;
        _observance = observance;
        _alertesStock = alertes;
        _charge = true;
      });
    } catch (_) {
      // La carte reste discrète si le module n'est pas prêt.
    }
  }

  Future<void> _ouvrir() async {
    await Navigator.pushNamed(context, AppRoutes.prescriptions);
    _charger();
  }

  @override
  Widget build(BuildContext context) {
    final PrisePlanifiee? p = _prochaine;
    final double? obs = _observance;
    final String heure = p == null
        ? ''
        : '${p.prise.heurePrevue.hour.toString().padLeft(2, '0')}:'
            '${p.prise.heurePrevue.minute.toString().padLeft(2, '0')}';

    return Material(
      borderRadius: BorderRadius.circular(22),
      color: AppColors.primaryDark,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: _ouvrir,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.medication_rounded, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Mon traitement',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      !_charge
                          ? 'Ordonnances et remboursements'
                          : p == null
                              ? 'Aucune prise prévue'
                              : '$heure · ${p.medicament}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (_charge)
                      Text(
                        [
                          if (obs != null) 'Observance ${obs.round()} % sur 7 jours',
                          if (_alertesStock > 0)
                            '$_alertesStock médicament${_alertesStock > 1 ? 's' : ''} bientôt épuisé${_alertesStock > 1 ? 's' : ''}',
                        ].join(' · '),
                        style: TextStyle(
                          color: _alertesStock > 0 ? const Color(0xFFFFD58A) : Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}
