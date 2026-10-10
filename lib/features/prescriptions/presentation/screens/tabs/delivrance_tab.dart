import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/empty_state.dart';
import '../../../../../core/widgets/error_banner.dart';
import '../../../domain/delivrance_manager.dart';
import '../../../domain/models/vues_ordonnance.dart';
import '../../../domain/prescriptions_exception.dart';
import '../../widgets/elements_ui.dart';
import '../delivrance_screen.dart';
import '../scan_screen.dart';
import 'ordonnances_tab.dart';

/// Pharmacien : scan du QR code (ou numéro), ordonnances à délivrer.
class DelivranceTab extends StatefulWidget {
  const DelivranceTab({super.key});

  @override
  State<DelivranceTab> createState() => _DelivranceTabState();
}

class _DelivranceTabState extends State<DelivranceTab> {
  final DelivranceManager _manager = DelivranceManager();
  final TextEditingController _numeroCtrl = TextEditingController();

  List<OrdonnanceResume> _attente = [];
  bool _chargement = true;
  bool _recherche = false;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  @override
  void dispose() {
    _numeroCtrl.dispose();
    super.dispose();
  }

  Future<void> _charger() async {
    final List<OrdonnanceResume> res = await _manager.enAttente();
    if (!mounted) {
      return;
    }
    setState(() {
      _attente = res;
      _chargement = false;
    });
  }

  Future<void> _ouvrir(OrdonnanceADelivrer o) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(builder: (_) => DelivranceScreen(ordonnance: o)),
    );
    _charger();
  }

  Future<void> _chercher(String saisie) async {
    setState(() {
      _recherche = true;
      _erreur = null;
    });
    try {
      final OrdonnanceADelivrer o = await _manager.rechercher(saisie);
      if (!mounted) {
        return;
      }
      setState(() => _recherche = false);
      _numeroCtrl.clear();
      await _ouvrir(o);
    } on PrescriptionsException catch (e) {
      if (mounted) {
        setState(() {
          _erreur = e.message;
          _recherche = false;
        });
      }
    }
  }

  Future<void> _scanner() async {
    final String? lu = await Navigator.push<String>(
      context,
      MaterialPageRoute<String>(builder: (_) => const ScanScreen()),
    );
    if (lu != null) {
      await _chercher(lu);
    }
  }

  Future<void> _ouvrirDepuisListe(OrdonnanceResume r) async {
    try {
      final OrdonnanceADelivrer o = await _manager.controler(r.ordonnance.id!);
      if (!mounted) {
        return;
      }
      await _ouvrir(o);
    } on PrescriptionsException catch (e) {
      if (mounted) {
        setState(() => _erreur = e.message);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: _charger,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 120),
          children: [
            const EnTetePage(surtitre: 'Pharmacie', titre: 'Délivrance'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 56,
                    child: FilledButton.icon(
                      onPressed: _recherche ? null : _scanner,
                      icon: const Icon(Icons.qr_code_scanner_rounded),
                      label: const Text('Scanner le QR code', style: TextStyle(fontSize: 16)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _numeroCtrl,
                    textCapitalization: TextCapitalization.characters,
                    textInputAction: TextInputAction.search,
                    onSubmitted: _chercher,
                    decoration: InputDecoration(
                      hintText: 'ou saisir le numéro : ORD-2026-0002',
                      prefixIcon: const Icon(Icons.keyboard_rounded),
                      suffixIcon: IconButton(
                        tooltip: 'Rechercher',
                        icon: const Icon(Icons.arrow_forward_rounded),
                        onPressed: _recherche ? null : () => _chercher(_numeroCtrl.text),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(color: AppColors.divider),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(color: AppColors.divider),
                      ),
                    ),
                  ),
                  if (_erreur != null) ...[
                    const SizedBox(height: 12),
                    ErrorBanner(message: _erreur!),
                  ],
                  const SizedBox(height: 20),
                  Text(
                    'À délivrer (${_attente.length})',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_chargement)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_attente.isEmpty)
                    const EmptyState(
                      icon: Icons.inventory_2_outlined,
                      message: 'Aucune ordonnance en attente de délivrance',
                    )
                  else
                    for (final OrdonnanceResume r in _attente)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: CarteOrdonnance(resume: r, onTap: () => _ouvrirDepuisListe(r)),
                      ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
