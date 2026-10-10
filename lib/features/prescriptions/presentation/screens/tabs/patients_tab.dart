import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/empty_state.dart';
import '../../../../../core/widgets/search_field.dart';
import '../../../../../models/patient.dart';
import '../../../../../models/utilisateur.dart';
import '../../../data/prescriptions_schema.dart';
import '../../../domain/prescriptions_permissions.dart';
import '../../widgets/elements_ui.dart';
import '../../widgets/ordonnances_patient_tab.dart';

/// Admin et infirmier : patients, puis leur fiche Ordonnances & Assurance.
class PatientsTab extends StatefulWidget {
  const PatientsTab({super.key, required this.role});

  final Role role;

  @override
  State<PatientsTab> createState() => _PatientsTabState();
}

class _PatientsTabState extends State<PatientsTab> {
  List<Patient> _patients = [];
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
    final String t = _texte.trim();
    final Database db = await PrescriptionsSchema.database;
    final List<Map<String, Object?>> rows = await db.query(
      'patients',
      where: t.isEmpty ? null : 'nom LIKE ? OR prenom LIKE ? OR cin LIKE ?',
      whereArgs: t.isEmpty ? null : ['%$t%', '%$t%', '%$t%'],
      orderBy: 'nom COLLATE NOCASE, prenom COLLATE NOCASE',
    );
    final List<Patient> res = [];
    for (final Map<String, Object?> r in rows) {
      res.add(Patient.fromMap(r));
    }
    if (!mounted || requete != _requete) {
      return;
    }
    setState(() {
      _patients = res;
      _chargement = false;
    });
  }

  void _ouvrir(Patient p) {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text(p.nomComplet)),
          body: OrdonnancesPatientTab(
            patientId: p.id!,
            gererContrats: widget.role.gererContrats,
            traiterDossiers: widget.role.traiterDossiers,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          const EnTetePage(surtitre: 'Contrats, ordonnances, dossiers', titre: 'Patients'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SearchField(
              hint: 'Nom ou CIN',
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
                : _patients.isEmpty
                    ? const EmptyState(icon: Icons.people_outline, message: 'Aucun patient')
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
                        itemCount: _patients.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (BuildContext context, int i) {
                          final Patient p = _patients[i];
                          return Card(
                            margin: EdgeInsets.zero,
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: AppColors.mint,
                                child: Text(
                                  p.nom.isEmpty ? '?' : p.nom[0],
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primaryDark,
                                  ),
                                ),
                              ),
                              title: Text(p.nomComplet),
                              subtitle: Text('${p.age} ans · CIN ${p.cin}'),
                              trailing: const Icon(Icons.chevron_right_rounded),
                              onTap: () => _ouvrir(p),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
