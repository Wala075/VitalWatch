import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../models/utilisateur.dart';
import '../../../../shared_providers/session.dart';
import '../../data/rythme_repository.dart';
import '../../domain/ambulance_permissions.dart';
import '../../domain/suivi_cardiaque.dart';
import '../../domain/surveillance_cardiaque.dart';
import '../widgets/carte_rythme.dart';
import '../widgets/dispatch_ui.dart';
import 'intervention_detail_screen.dart';

/// Fréquence de lecture de la base côté personnel (= synchro du patient).
const Duration frequenceSuiviCardiaque = Duration(seconds: 30);

/// Espace personnel (médecin, infirmier, admin) : rythme cardiaque des
/// patients, envoyé par le téléphone de chaque patient qui porte une montre
/// et lu ici dans la base, actualisé toutes les 30 s. Le médecin voit
/// d'abord ses patients. Aucune connexion à la montre de ce côté.
class SuiviCardiaqueScreen extends StatefulWidget {
  const SuiviCardiaqueScreen({super.key});

  @override
  State<SuiviCardiaqueScreen> createState() => _SuiviCardiaqueScreenState();
}

class _SuiviCardiaqueScreenState extends State<SuiviCardiaqueScreen> {
  final RythmeRepository _rythme = RythmeRepository();
  List<SuiviPatient>? _liste;
  String? _erreur;
  DateTime? _maj;
  bool _mesPatients = true;
  bool _avecMontre = false;
  Timer? _minuterie;

  /// Médecin connecté (filtre « Mes patients »).
  int? get _medecinId {
    final Utilisateur? u = Session.utilisateur;
    return u != null && u.role == Role.medecin ? u.refId : null;
  }

  @override
  void initState() {
    super.initState();
    _charger();
    _minuterie = Timer.periodic(frequenceSuiviCardiaque, (_) => _charger());
  }

  @override
  void dispose() {
    _minuterie?.cancel();
    super.dispose();
  }

  Future<void> _charger() async {
    try {
      final int? medecin = _medecinId;
      final List<SuiviPatient> l = await _rythme.suivi(
        medecinId: medecin != null && _mesPatients ? medecin : null,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _liste = l;
        _erreur = null;
        _maj = DateTime.now();
      });
    } catch (e) {
      if (mounted) {
        setState(() => _erreur = 'Lecture impossible : $e');
      }
    }
  }

  Future<void> _ouvrir(SuiviPatient s) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => SuiviPatientScreen(patientId: s.patientId, nom: s.nom),
      ),
    );
    await _charger();
  }

  @override
  Widget build(BuildContext context) {
    final List<SuiviPatient>? liste = _liste;
    final DateTime? maj = _maj;
    final DateTime maintenant = DateTime.now();

    final List<SuiviPatient> visibles = [];
    int alertes = 0;
    int actifs = 0;
    for (final SuiviPatient s in liste ?? const <SuiviPatient>[]) {
      if (s.enAlerte(maintenant)) {
        alertes++;
      }
      if (s.estActif(maintenant)) {
        actifs++;
      }
      if (!_avecMontre || s.derniere != null) {
        visibles.add(s);
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Suivi cardiaque'),
        actions: [
          IconButton(
            tooltip: 'Actualiser',
            icon: const Icon(Icons.refresh),
            onPressed: _charger,
          ),
        ],
      ),
      body: liste == null
          ? Center(
              child: _erreur == null
                  ? const CircularProgressIndicator()
                  : Text(_erreur ?? '', style: const TextStyle(color: AppColors.danger)),
            )
          : RefreshIndicator(
              onRefresh: _charger,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _Compteur(
                          valeur: alertes,
                          libelle: 'En alerte',
                          couleur: AppColors.danger,
                          icone: Icons.warning_amber_rounded,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _Compteur(
                          valeur: actifs,
                          libelle: 'Montres actives',
                          couleur: AppColors.success,
                          icone: Icons.watch_outlined,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _Compteur(
                          valeur: liste.length,
                          libelle: 'Patients',
                          couleur: AppColors.primary,
                          icone: Icons.people_outline,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      if (_medecinId != null) ...[
                        ChoiceChip(
                          label: const Text('Mes patients'),
                          selected: _mesPatients,
                          onSelected: (_) {
                            setState(() => _mesPatients = true);
                            _charger();
                          },
                        ),
                        ChoiceChip(
                          label: const Text('Tous'),
                          selected: !_mesPatients,
                          onSelected: (_) {
                            setState(() => _mesPatients = false);
                            _charger();
                          },
                        ),
                      ],
                      FilterChip(
                        label: const Text('Avec montre'),
                        selected: _avecMontre,
                        onSelected: (bool v) => setState(() => _avecMontre = v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Info(
                    icone: Icons.sync,
                    texte: '${maj == null ? '' : 'Actualisé à ${DispatchUi.heure(maj)} · '}'
                        'mesures envoyées par le téléphone du patient',
                  ),
                  if (_erreur != null) ...[
                    const SizedBox(height: 6),
                    Info(icone: Icons.error_outline, texte: _erreur ?? '', couleur: AppColors.danger),
                  ],
                  const SizedBox(height: 12),
                  if (visibles.isEmpty)
                    EmptyState(
                      icon: Icons.monitor_heart_outlined,
                      message: _medecinId != null && _mesPatients
                          ? 'Aucun de vos patients à afficher.\nChoisissez « Tous ».'
                          : 'Aucun patient à afficher.',
                    )
                  else
                    for (final SuiviPatient s in visibles)
                      _TuilePatient(suivi: s, maintenant: maintenant, onTap: () => _ouvrir(s)),
                ],
              ),
            ),
    );
  }
}

class _Compteur extends StatelessWidget {
  const _Compteur({
    required this.valeur,
    required this.libelle,
    required this.couleur,
    required this.icone,
  });

  final int valeur;
  final String libelle;
  final Color couleur;
  final IconData icone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: couleur.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icone, size: 16, color: couleur),
              const SizedBox(width: 6),
              Text(
                '$valeur',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: couleur),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            libelle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _TuilePatient extends StatelessWidget {
  const _TuilePatient({required this.suivi, required this.maintenant, required this.onTap});

  final SuiviPatient suivi;
  final DateTime maintenant;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final MesureCardiaque? m = suivi.derniere;
    final EtatRythme? e = suivi.etat;
    final bool alerte = suivi.enAlerte(maintenant);
    final bool actif = suivi.estActif(maintenant);
    final Color couleur = alerte
        ? AppColors.danger
        : (actif ? AppColors.success : AppColors.textSecondary);
    final SeuilsCardiaques s = suivi.seuils;

    final List<String> details = [];
    if (m == null) {
      details.add('Aucune mesure de montre');
    } else {
      details.add(DispatchUi.ilYa(m.date));
      details.add(m.simulee ? 'simulation' : 'montre');
    }
    details.add('seuils ${s.min}–${s.max}');
    if (suivi.interventionId != null) {
      details.add('ambulance en cours');
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: couleur.withValues(alpha: 0.12),
          child: Icon(alerte ? Icons.heart_broken : Icons.favorite, color: couleur),
        ),
        title: Text(suivi.nom, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(
          details.join(' · '),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12.5,
            color: suivi.interventionId != null ? AppColors.danger : AppColors.textSecondary,
          ),
        ),
        trailing: m == null
            ? const Icon(Icons.chevron_right)
            : Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${m.bpm}',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: alerte ? AppColors.danger : AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    e == null ? 'bpm' : 'bpm · ${e.libelle}',
                    style: TextStyle(fontSize: 11, color: couleur),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Détail d'un patient : courbe 3 h, statistiques du jour, seuils (réglables
/// par le médecin ou l'admin), dernières mesures, ambulance en cours.
class SuiviPatientScreen extends StatefulWidget {
  const SuiviPatientScreen({super.key, required this.patientId, required this.nom});

  final int patientId;
  final String nom;

  @override
  State<SuiviPatientScreen> createState() => _SuiviPatientScreenState();
}

class _SuiviPatientScreenState extends State<SuiviPatientScreen> {
  final RythmeRepository _rythme = RythmeRepository();
  SuiviPatient? _suivi;
  List<MesureCardiaque> _mesures = [];
  List<MesureCardiaque> _jour = [];
  RangeValues? _reglage;
  bool _enregistrement = false;
  String? _erreur;
  Timer? _minuterie;

  bool get _peutRegler => (Session.utilisateur?.role ?? Role.patient).reglerSeuils;

  @override
  void initState() {
    super.initState();
    _charger();
    _minuterie = Timer.periodic(frequenceSuiviCardiaque, (_) => _charger());
  }

  @override
  void dispose() {
    _minuterie?.cancel();
    super.dispose();
  }

  Future<void> _charger() async {
    try {
      final DateTime maintenant = DateTime.now();
      final DateTime minuit = DateTime(maintenant.year, maintenant.month, maintenant.day);
      final SuiviPatient? s = await _rythme.resume(widget.patientId);
      final List<MesureCardiaque> jour =
          await _rythme.historique(widget.patientId, periode: maintenant.difference(minuit));
      final List<MesureCardiaque> recentes = await _rythme.historique(widget.patientId);
      if (!mounted) {
        return;
      }
      setState(() {
        _suivi = s;
        _jour = jour;
        _mesures = recentes;
        _erreur = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _erreur = 'Lecture impossible : $e');
      }
    }
  }

  Future<void> _enregistrerSeuils(RangeValues v) async {
    final SeuilsCardiaques s = SeuilsCardiaques(min: v.start.round(), max: v.end.round());
    setState(() => _enregistrement = true);
    try {
      await _rythme.enregistrerSeuils(widget.patientId, s);
      await _charger();
      if (!mounted) {
        return;
      }
      setState(() => _reglage = null);
      final MesureCardiaque? der = _suivi?.derniere;
      String suite = '';
      if (der != null && s.evaluer(der.bpm) != EtatRythme.normal) {
        suite = '. ${der.bpm} bpm est hors seuils : le patient recevra « Ça va ? »';
      }
      DispatchUi.snack(
        context,
        'Seuils ${s.min}–${s.max} bpm enregistrés : le téléphone du patient les applique '
        'à sa prochaine synchro (30 s)$suite',
      );
    } catch (e) {
      if (mounted) {
        DispatchUi.snack(context, 'Enregistrement impossible : $e', erreur: true);
      }
    } finally {
      if (mounted) {
        setState(() => _enregistrement = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final SuiviPatient? s = _suivi;
    final SeuilsCardiaques seuils = s?.seuils ?? const SeuilsCardiaques();
    final StatsRythme stats = StatsRythme.de(_jour, seuils);
    final int? interventionId = s?.interventionId;

    return Scaffold(
      appBar: AppBar(title: Text(widget.nom)),
      body: RefreshIndicator(
        onRefresh: _charger,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
          children: [
            CarteRythme(
              derniere: s?.derniere,
              etat: s?.etat,
              mesures: _mesures,
              seuils: seuils,
            ),
            if (_erreur != null) ...[
              const SizedBox(height: 8),
              Info(icone: Icons.error_outline, texte: _erreur ?? '', couleur: AppColors.danger),
            ],
            const SizedBox(height: 8),
            const Info(
              icone: Icons.sync,
              texte: 'Envoyé par le téléphone du patient · actualisé toutes les 30 s',
            ),
            if (interventionId != null) ...[
              const SizedBox(height: 14),
              Card(
                margin: EdgeInsets.zero,
                color: AppColors.danger.withValues(alpha: 0.08),
                child: ListTile(
                  leading: const Icon(Icons.emergency, color: AppColors.danger),
                  title: Text('Ambulance en cours · intervention n°$interventionId'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push<void>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => InterventionDetailScreen(interventionId: interventionId),
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 14),
            Section(
              titre: "Aujourd'hui",
              icone: Icons.today_outlined,
              children: [
                if (stats.nombre == 0)
                  const Info(icone: Icons.info_outline, texte: "Aucune mesure aujourd'hui")
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _Valeur(libelle: 'Moyenne', valeur: '${stats.moyenne} bpm'),
                      _Valeur(libelle: 'Min', valeur: '${stats.min} bpm'),
                      _Valeur(libelle: 'Max', valeur: '${stats.max} bpm'),
                      _Valeur(libelle: 'Mesures', valeur: '${stats.nombre}'),
                      _Valeur(
                        libelle: 'Hors seuils',
                        valeur: '${stats.horsSeuils}',
                        alerte: stats.horsSeuils > 0,
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 14),
            _seuils(seuils),
            const SizedBox(height: 14),
            Section(
              titre: 'Dernières mesures',
              icone: Icons.list_alt,
              children: [
                if (_jour.isEmpty)
                  const Info(icone: Icons.watch_outlined, texte: 'Pas encore de mesure de la montre'),
                for (final MesureCardiaque m in _jour.reversed.take(12))
                  _LigneMesure(mesure: m, etat: seuils.evaluer(m.bpm)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _seuils(SeuilsCardiaques seuils) {
    final RangeValues valeurs =
        _reglage ?? RangeValues(seuils.min.toDouble(), seuils.max.toDouble());
    final bool modifie = _reglage != null &&
        (valeurs.start.round() != seuils.min || valeurs.end.round() != seuils.max);

    return Section(
      titre: "Seuils d'alerte",
      icone: Icons.tune,
      action: _peutRegler
          ? null
          : const Pastille(
              libelle: 'Fixés par le médecin',
              couleur: AppColors.primary,
              icone: Icons.lock_outline,
            ),
      children: [
        Text(
          '${valeurs.start.round()} – ${valeurs.end.round()} bpm',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
        ),
        if (_peutRegler) ...[
          RangeSlider(
            values: valeurs,
            min: 30,
            max: 200,
            divisions: 34,
            labels: RangeLabels('${valeurs.start.round()}', '${valeurs.end.round()}'),
            onChanged: _enregistrement ? null : (RangeValues v) => setState(() => _reglage = v),
          ),
          FilledButton.icon(
            onPressed: modifie && !_enregistrement ? () => _enregistrerSeuils(valeurs) : null,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Enregistrer pour ce patient'),
          ),
        ],
        const Info(
          icone: Icons.info_outline,
          texte: 'Appliqués par le téléphone du patient : « Ça va ? » puis ambulance',
        ),
      ],
    );
  }
}

class _Valeur extends StatelessWidget {
  const _Valeur({required this.libelle, required this.valeur, this.alerte = false});

  final String libelle;
  final String valeur;
  final bool alerte;

  @override
  Widget build(BuildContext context) {
    final Color c = alerte ? AppColors.danger : AppColors.primary;
    return Container(
      width: 96,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(libelle, style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
          const SizedBox(height: 2),
          Text(valeur, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: c)),
        ],
      ),
    );
  }
}

class _LigneMesure extends StatelessWidget {
  const _LigneMesure({required this.mesure, required this.etat});

  final MesureCardiaque mesure;
  final EtatRythme etat;

  @override
  Widget build(BuildContext context) {
    final bool normal = etat == EtatRythme.normal;
    return Row(
      children: [
        SizedBox(
          width: 52,
          child: Text(
            DispatchUi.heure(mesure.date),
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ),
        Icon(
          Icons.favorite,
          size: 16,
          color: normal ? AppColors.success : AppColors.danger,
        ),
        const SizedBox(width: 6),
        Text('${mesure.bpm} bpm', style: const TextStyle(fontWeight: FontWeight.w700)),
        const Spacer(),
        Text(
          mesure.simulee ? 'simulation' : (normal ? 'montre' : etat.libelle),
          style: TextStyle(
            fontSize: 12,
            color: normal ? AppColors.textSecondary : AppColors.danger,
          ),
        ),
      ],
    );
  }
}
