import 'package:flutter/material.dart';

import '../../../../../core/widgets/empty_state.dart';
import '../../../data/ordonnance_repository.dart';
import '../../../domain/models/ordonnance.dart';
import '../../../domain/models/vues_ordonnance.dart';
import '../../widgets/elements_ui.dart';
import '../ordonnance_detail_screen.dart';
import 'ordonnances_tab.dart';

/// Patient : ses ordonnances (QR code, simulation, renouvellement).
class MesOrdonnancesTab extends StatefulWidget {
  const MesOrdonnancesTab({super.key, required this.patientId});

  final int patientId;

  @override
  State<MesOrdonnancesTab> createState() => _MesOrdonnancesTabState();
}

class _MesOrdonnancesTabState extends State<MesOrdonnancesTab> {
  final OrdonnanceRepository _repo = OrdonnanceRepository();

  List<OrdonnanceResume> _liste = [];
  bool _chargement = true;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    final List<OrdonnanceResume> res = await _repo.listerResumes(patientId: widget.patientId);
    final List<OrdonnanceResume> visibles = [];
    for (final OrdonnanceResume r in res) {
      // Les brouillons du médecin ne sont pas montrés au patient.
      if (r.ordonnance.statut != StatutOrdonnance.brouillon) {
        visibles.add(r);
      }
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _liste = visibles;
      _chargement = false;
    });
  }

  Future<void> _ouvrir(int id) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => OrdonnanceDetailScreen(ordonnanceId: id, lectureSeule: true, modePatient: true),
      ),
    );
    _charger();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          const EnTetePage(surtitre: 'Mon traitement', titre: 'Mes ordonnances'),
          Expanded(
            child: _chargement
                ? const Center(child: CircularProgressIndicator())
                : _liste.isEmpty
                    ? const EmptyState(icon: Icons.description_outlined, message: 'Aucune ordonnance')
                    : RefreshIndicator(
                        onRefresh: _charger,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
                          itemCount: _liste.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 10),
                          itemBuilder: (BuildContext context, int i) {
                            final OrdonnanceResume r = _liste[i];
                            return CarteOrdonnance(resume: r, onTap: () => _ouvrir(r.ordonnance.id!));
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
