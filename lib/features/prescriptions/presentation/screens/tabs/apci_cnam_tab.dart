import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/empty_state.dart';
import '../../../data/apci_repository.dart';
import '../../../domain/contrat_manager.dart';
import '../../../domain/models/apci.dart';
import '../../../domain/models/contrat_assurance.dart';
import '../../../domain/models/vues_remboursement.dart';
import '../../../domain/remboursement_manager.dart';
import '../../widgets/elements_ui.dart';
import '../../widgets/graphiques.dart';

/// Espace patient — onglet « Mon APCI & CNAM ».
///
/// Affiche en lecture seule :
/// - La maladie APCI déclarée par le médecin (et les médicaments couverts,
///   tenus par le pharmacien).
/// - Le contrat CNAM actif avec la jauge du plafond annuel.
/// - Les autres contrats (mutuelle / privée).
class ApciCnamTab extends StatefulWidget {
  const ApciCnamTab({super.key, required this.patientId});

  final int patientId;

  @override
  State<ApciCnamTab> createState() => _ApciCnamTabState();
}

class _ApciCnamTabState extends State<ApciCnamTab> {
  final ContratManager _manager = ContratManager();
  final RemboursementManager _remboursement = RemboursementManager();
  final ApciRepository _apciRepo = ApciRepository();

  Apci? _apci;
  List<String> _medicamentsCouvrerts = [];
  List<ContratDetail> _contrats = [];
  bool _chargement = true;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    try {
      final Apci? apci = await _manager.apciDuPatient(widget.patientId);
      List<String> medicaments = [];
      if (apci != null) {
        medicaments = await _apciRepo.dcis(apci.codeCim10);
      }
      final List<ContratDetail> contrats =
          await _remboursement.contratsDuPatient(widget.patientId);
      if (!mounted) return;
      setState(() {
        _apci = apci;
        _medicamentsCouvrerts = medicaments;
        _contrats = contrats;
        _chargement = false;
        _erreur = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erreur = e.toString();
        _chargement = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: _charger,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: EnTetePage(
                surtitre: 'Votre dossier médical',
                titre: 'Mon APCI & CNAM',
              ),
            ),
            if (_chargement)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_erreur != null)
              SliverFillRemaining(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _erreur!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.danger),
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Bandeau informatif lecture seule
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.2)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.visibility_rounded,
                              size: 18, color: AppColors.primary),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Ces informations sont remplies par votre médecin '
                              'et votre pharmacien. Vous pouvez les consulter '
                              'ici en lecture seule.',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.primary),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    _SectionApci(
                      apci: _apci,
                      medicaments: _medicamentsCouvrerts,
                    ),
                    const SizedBox(height: 20),
                    _SectionCnam(contrats: _contrats),
                  ]),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------
// Section APCI
// -----------------------------------------------------------------------

class _SectionApci extends StatelessWidget {
  const _SectionApci({required this.apci, required this.medicaments});

  final Apci? apci;
  final List<String> medicaments;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _TitreSection(
          icone: Icons.favorite_rounded,
          libelle: 'Mon APCI',
          couleur: AppColors.danger,
        ),
        const SizedBox(height: 10),
        if (apci == null)
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded,
                      size: 20, color: AppColors.textSecondary),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Votre médecin n\'a pas encore déclaré d\'APCI pour vous.\n'
                      'L\'APCI est déclarée lors de votre consultation médicale.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
          )
        else ...[
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.danger.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          apci!.codeCim10,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: AppColors.danger,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          apci!.libelle,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      const BadgeStatut(
                        libelle: '100 %',
                        icon: Icons.verified_rounded,
                        couleur: AppColors.success,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Déclarée par votre médecin · Prise en charge CNAM à 100 %',
                    style: TextStyle(
                        fontSize: 13, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Médicaments couverts (tenus par le pharmacien)
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.medication_rounded,
                          size: 18, color: AppColors.primary),
                      const SizedBox(width: 8),
                      const Text(
                        'Médicaments couverts à 100 %',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Liste tenue par le pharmacien',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  if (medicaments.isEmpty)
                    const Text(
                      'Aucun médicament enregistré pour cette APCI.',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 13),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final String dci in medicaments)
                          _PuceDci(dci: dci),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _PuceDci extends StatelessWidget {
  const _PuceDci({required this.dci});

  final String dci;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Text(
        dci,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.primaryDark,
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------
// Section CNAM & autres contrats
// -----------------------------------------------------------------------

class _SectionCnam extends StatelessWidget {
  const _SectionCnam({required this.contrats});

  final List<ContratDetail> contrats;

  @override
  Widget build(BuildContext context) {
    if (contrats.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _TitreSection(
            icone: Icons.shield_rounded,
            libelle: 'Mes contrats d\'assurance',
            couleur: AppColors.primary,
          ),
          const SizedBox(height: 10),
          const EmptyState(
            icon: Icons.shield_outlined,
            message: 'Aucun contrat d\'assurance.\n'
                'Contactez l\'accueil de l\'établissement.',
          ),
        ],
      );
    }

    // Séparer CNAM (obligatoire) des complémentaires
    final List<ContratDetail> cnam = contrats
        .where((c) => c.assurance.estObligatoire)
        .toList();
    final List<ContratDetail> autres = contrats
        .where((c) => !c.assurance.estObligatoire)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // CNAM
        if (cnam.isNotEmpty) ...[
          const _TitreSection(
            icone: Icons.shield_rounded,
            libelle: 'Mon contrat CNAM',
            couleur: AppColors.primary,
          ),
          const SizedBox(height: 10),
          for (final ContratDetail c in cnam) ...[
            _CarteCnamDetail(contrat: c),
            const SizedBox(height: 10),
          ],
        ],
        // Complémentaires
        if (autres.isNotEmpty) ...[
          const SizedBox(height: 8),
          const _TitreSection(
            icone: Icons.add_card_rounded,
            libelle: 'Couverture complémentaire',
            couleur: AppColors.warning,
          ),
          const SizedBox(height: 10),
          for (final ContratDetail c in autres) ...[
            _CarteAssuranceDetail(contrat: c),
            const SizedBox(height: 10),
          ],
        ],
      ],
    );
  }
}

/// Carte détaillée du contrat CNAM : filière, numéro, APCI, jauge plafond.
class _CarteCnamDetail extends StatelessWidget {
  const _CarteCnamDetail({required this.contrat});

  final ContratDetail contrat;

  @override
  Widget build(BuildContext context) {
    final ContratAssurance c = contrat.contrat;
    final FiliereCnam? filiere = c.filiere;
    final bool actif = contrat.actif;

    return Opacity(
      opacity: actif ? 1.0 : 0.6,
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // En-tête : nom de l'assurance + badges
              Row(
                children: [
                  Expanded(
                    child: Text(
                      contrat.assurance.nom,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  if (!actif)
                    const BadgeStatut(
                      libelle: 'Résilié',
                      icon: Icons.event_busy_rounded,
                      couleur: AppColors.textSecondary,
                    )
                  else
                    const BadgeStatut(
                      libelle: 'Actif',
                      icon: Icons.check_circle_rounded,
                      couleur: AppColors.success,
                    ),
                ],
              ),
              const SizedBox(height: 6),
              // Numéro adhérent + filière
              Text(
                'N° adhérent : ${c.numeroAdherent}'
                '${c.beneficiaire != Beneficiaire.assure ? ' · ${c.beneficiaire.libelle}' : ''}'
                '${filiere == null ? '' : ' · ${filiere.libelle}'}',
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textSecondary),
              ),
              // Dates
              const SizedBox(height: 4),
              Text(
                'Début : ${_fmtDate(c.dateDebut)}'
                '${c.dateFin == null ? '' : ' · Fin : ${_fmtDate(c.dateFin!)}'}',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary),
              ),
              // Séparateur + jauge plafond
              if (contrat.assurance.plafondAnnuel != null) ...[
                const Divider(height: 20),
                JaugePlafond(contrat: contrat),
              ],
              // Info APCI sur le contrat
              if (c.apci && c.codeApci != null) ...[
                const Divider(height: 20),
                Row(
                  children: [
                    const Icon(Icons.favorite_rounded,
                        size: 16, color: AppColors.danger),
                    const SizedBox(width: 8),
                    Text(
                      'APCI enregistrée : ${c.codeApci}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.danger,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Carte complémentaire (mutuelle / privée) : plus sobre.
class _CarteAssuranceDetail extends StatelessWidget {
  const _CarteAssuranceDetail({required this.contrat});

  final ContratDetail contrat;

  @override
  Widget build(BuildContext context) {
    final ContratAssurance c = contrat.contrat;
    final bool actif = contrat.actif;

    return Opacity(
      opacity: actif ? 1.0 : 0.6,
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      contrat.assurance.nom,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  BadgeStatut(
                    libelle: contrat.assurance.type.libelle,
                    icon: Icons.add_card_rounded,
                    couleur: actif ? AppColors.warning : AppColors.textSecondary,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'N° adhérent : ${c.numeroAdherent}'
                '${c.beneficiaire != Beneficiaire.assure ? ' · ${c.beneficiaire.libelle}' : ''}',
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 4),
              Text(
                'Début : ${_fmtDate(c.dateDebut)}'
                '${c.dateFin == null ? '' : ' · Fin : ${_fmtDate(c.dateFin!)}'}',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------
// Utilitaires
// -----------------------------------------------------------------------

String _fmtDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

// -----------------------------------------------------------------------
// Widget utilitaire
// -----------------------------------------------------------------------

class _TitreSection extends StatelessWidget {
  const _TitreSection({
    required this.icone,
    required this.libelle,
    required this.couleur,
  });

  final IconData icone;
  final String libelle;
  final Color couleur;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icone, size: 18, color: couleur),
        const SizedBox(width: 8),
        Text(
          libelle,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: couleur,
          ),
        ),
      ],
    );
  }
}
