import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_dropdown_field.dart';
import '../../../../models/patient.dart';
import '../../../../models/utilisateur.dart';
import '../../../../shared_providers/session.dart';
import '../../data/api/montre_ble_service.dart';
import '../../data/patient_lookup.dart';
import '../../domain/dispatch_manager.dart';
import '../../domain/dispatch_models.dart';
import '../../domain/surveillance_cardiaque.dart';
import '../providers/dispatch_controller.dart';
import '../widgets/dispatch_ui.dart';
import 'intervention_detail_screen.dart';

/// Surveillance du rythme cardiaque de la montre connectée :
/// lecture Bluetooth directe de la Mibro C2 toutes les minutes, seuils,
/// confirmation « Ça va ? » puis envoi automatique d'une ambulance.
class SurveillanceCardiaqueScreen extends StatefulWidget {
  const SurveillanceCardiaqueScreen({super.key});

  @override
  State<SurveillanceCardiaqueScreen> createState() => _SurveillanceCardiaqueScreenState();
}

class _SurveillanceCardiaqueScreenState extends State<SurveillanceCardiaqueScreen> {
  static const Duration _frequence = Duration(minutes: 1);
  static const Duration _periode = Duration(hours: 3);

  final MontreBleService _montre = MontreBleService();
  final AnalyseurCardiaque _analyseur = AnalyseurCardiaque();
  final PatientLookup _patients = PatientLookup();
  final DispatchController _ctrl = DispatchController.instance;

  EtatMontre? _etatMontre;
  List<MesureCardiaque> _mesures = [];
  List<Patient> _listePatients = [];
  int? _patientId;
  RangeValues _seuils = const RangeValues(45, 120);
  double _bpmSimule = 155;
  Timer? _minuterie;
  bool _lecture = false;
  bool _alerteOuverte = false;
  DateTime? _derniereLecture;
  String? _erreur;

  bool get _estPatient => Session.utilisateur?.role == Role.patient;

  @override
  void initState() {
    super.initState();
    _ctrl.demarrer();
    _initialiser();
  }

  @override
  void dispose() {
    _minuterie?.cancel();
    _montre.deconnecter();
    super.dispose();
  }

  Future<void> _initialiser() async {
    final List<Patient> patients = await _patients.lister();
    if (!mounted) {
      return;
    }
    setState(() {
      _listePatients = patients;
      _patientId = _estPatient
          ? Session.utilisateur?.refId
          : (patients.isEmpty ? null : patients.first.id);
    });
    await _connecter();
    _minuterie = Timer.periodic(_frequence, (_) => _lire());
  }

  /// Cherche la montre (déjà connectée à Mibro Fit, appairée ou par scan)
  /// et s'y connecte en Bluetooth.
  Future<void> _connecter() async {
    setState(() => _etatMontre = null);
    final EtatMontre etat = await _montre.connecter();
    if (!mounted) {
      return;
    }
    setState(() => _etatMontre = etat);
    if (etat == EtatMontre.connectee) {
      await _lire(premiere: true);
    }
  }

  /// Lit les relevés de la montre et analyse les nouvelles mesures.
  /// [premiere] : l'historique déjà présent n'est pas analysé (pas d'alerte
  /// sur des valeurs anciennes), seule la dernière mesure sert de référence.
  Future<void> _lire({bool premiere = false}) async {
    // Montre déconnectée : mesures() tente une reconnexion.
    if (_lecture ||
        (_etatMontre != EtatMontre.connectee && _etatMontre != EtatMontre.deconnectee)) {
      return;
    }
    setState(() => _lecture = true);
    try {
      final List<MesureCardiaque> res = await _montre.mesures(periode: _periode);
      if (!mounted) {
        return;
      }
      final List<MesureCardiaque> simulees = [];
      for (final MesureCardiaque m in _mesures) {
        if (m.simulee) {
          simulees.add(m);
        }
      }
      setState(() {
        _mesures = [...res, ...simulees]
          ..sort((MesureCardiaque a, MesureCardiaque b) => a.date.compareTo(b.date));
        _derniereLecture = DateTime.now();
        _etatMontre = _montre.etat;
        _erreur = null;
      });
      if (premiere) {
        if (res.isNotEmpty) {
          _analyseur.analyser(res.last);
        }
        return;
      }
      for (final MesureCardiaque m in res) {
        final AlerteCardiaque? alerte = _analyseur.analyser(m);
        if (alerte != null) {
          await _alerter(alerte);
          break;
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _etatMontre = _montre.etat;
          _erreur = 'Lecture de la montre impossible : $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _lecture = false);
      }
    }
  }

  /// Mode démo : 2 mesures anormales d'affilée → déclenche la règle d'alerte.
  Future<void> _simuler() async {
    final DateTime maintenant = DateTime.now();
    final int bpm = _bpmSimule.round();
    final List<MesureCardiaque> deux = [
      MesureCardiaque(
        bpm: bpm - 3,
        date: maintenant.subtract(const Duration(seconds: 30)),
        source: 'Simulation',
        simulee: true,
      ),
      MesureCardiaque(bpm: bpm, date: maintenant, source: 'Simulation', simulee: true),
    ];
    setState(() => _mesures = [..._mesures, ...deux]);
    for (final MesureCardiaque m in deux) {
      final AlerteCardiaque? alerte = _analyseur.analyser(m);
      if (alerte != null) {
        await _alerter(alerte);
        return;
      }
    }
    if (mounted) {
      DispatchUi.snack(
        context,
        _analyseur.enPause
            ? 'Alertes en pause (15 min après « Je vais bien »)'
            : '$bpm bpm : dans les seuils, pas d\'alerte',
      );
    }
  }

  Future<void> _alerter(AlerteCardiaque alerte) async {
    if (_alerteOuverte || !mounted) {
      return;
    }
    _alerteOuverte = true;
    final bool? envoyer = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _DialogueAlerte(alerte: alerte),
    );
    _alerteOuverte = false;
    _analyseur.suspendre();
    if (envoyer == true) {
      await _envoyerAmbulance(alerte);
    } else if (mounted) {
      DispatchUi.snack(context, 'Alerte annulée. Surveillance en pause 15 min.');
    }
  }

  Future<void> _envoyerAmbulance(AlerteCardiaque alerte) async {
    if (!mounted) {
      return;
    }
    final int? patientId = _patientId;
    if (patientId == null) {
      DispatchUi.snack(context, 'Choisissez le patient qui porte la montre', erreur: true);
      return;
    }
    LatLng position = DispatchManager.centreZone;
    bool positionDemo = true;
    try {
      final LatLng p = await _ctrl.gps.positionActuelle();
      if (DispatchManager.dansZone(p)) {
        position = p;
        positionDemo = false;
      }
    } on DispatchException {
      // GPS indisponible : position de démonstration (Sousse)
    }
    try {
      final ResultatDispatch r = await _ctrl.creerDepuisAlerte(
        patientId: patientId,
        position: position,
        gravite: alerte.gravite,
      );
      if (!mounted) {
        return;
      }
      DispatchUi.snack(
        context,
        '${r.justification ?? 'Alerte transmise'}'
        '${positionDemo ? ' (position de démonstration : Sousse)' : ''}',
      );
      final int? id = r.intervention.id;
      if (id != null) {
        Navigator.push<void>(
          context,
          MaterialPageRoute(builder: (_) => InterventionDetailScreen(interventionId: id)),
        );
      }
    } on DispatchException catch (e) {
      if (mounted) {
        DispatchUi.snack(context, e.message, erreur: true);
      }
    }
  }

  void _changerSeuils(RangeValues v) {
    setState(() {
      _seuils = v;
      _analyseur.seuils = SeuilsCardiaques(min: v.start.round(), max: v.end.round());
    });
  }

  @override
  Widget build(BuildContext context) {
    final MesureCardiaque? derniere = _mesures.isEmpty ? null : _mesures.last;
    final SeuilsCardiaques seuils = _analyseur.seuils;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Surveillance cardiaque'),
        actions: [
          IconButton(
            tooltip: 'Lire maintenant',
            icon: _lecture
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            onPressed: _lecture ? null : () => _lire(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          _connexion(),
          const SizedBox(height: 14),
          _CarteRythme(
            derniere: derniere,
            etat: derniere == null ? null : seuils.evaluer(derniere.bpm),
            mesures: _mesures,
            seuils: seuils,
            anomalies: _analyseur.anomaliesEnCours,
          ),
          if (_erreur != null) ...[
            const SizedBox(height: 8),
            Info(icone: Icons.error_outline, texte: _erreur ?? '', couleur: AppColors.danger),
          ],
          const SizedBox(height: 14),
          Section(
            titre: "Seuils d'alerte",
            icone: Icons.tune,
            children: [
              RangeSlider(
                values: _seuils,
                min: 30,
                max: 200,
                divisions: 34,
                labels: RangeLabels('${_seuils.start.round()}', '${_seuils.end.round()}'),
                onChanged: _changerSeuils,
              ),
              Info(
                icone: Icons.info_outline,
                texte: 'Alerte si < ${seuils.min} ou > ${seuils.max} bpm sur '
                    '${_analyseur.mesuresConsecutives} mesures de suite, '
                    'puis 30 s pour répondre « Je vais bien »',
              ),
            ],
          ),
          const SizedBox(height: 14),
          Section(
            titre: 'Patient qui porte la montre',
            icone: Icons.person_outline,
            children: [
              if (_estPatient)
                Info(
                  icone: Icons.verified_user_outlined,
                  texte: Session.utilisateur?.nomComplet ?? 'Patient connecté',
                  couleur: AppColors.textPrimary,
                )
              else
                AppDropdownField<int?>(
                  label: 'Patient',
                  icon: Icons.person_search_outlined,
                  value: _patientId,
                  items: [
                    for (final Patient p in _listePatients)
                      DropdownMenuItem<int?>(value: p.id, child: Text(p.nomComplet)),
                  ],
                  onChanged: (int? v) => setState(() => _patientId = v),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Section(
            titre: 'Mode démo',
            icone: Icons.science_outlined,
            children: [
              Row(
                children: [
                  const Icon(Icons.favorite, color: AppColors.danger, size: 18),
                  Expanded(
                    child: Slider(
                      value: _bpmSimule,
                      min: 30,
                      max: 200,
                      divisions: 170,
                      label: '${_bpmSimule.round()} bpm',
                      onChanged: (double v) => setState(() => _bpmSimule = v),
                    ),
                  ),
                  SizedBox(
                    width: 64,
                    child: Text(
                      '${_bpmSimule.round()} bpm',
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
              OutlinedButton.icon(
                onPressed: _simuler,
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Simuler 2 mesures'),
              ),
              const Info(
                icone: Icons.info_outline,
                texte: 'Pour la soutenance : déclenche la même chaîne qu\'une vraie '
                    'mesure (alerte → « Ça va ? » → ambulance)',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _connexion() {
    final EtatMontre? etat = _etatMontre;
    final bool ok = etat == EtatMontre.connectee;
    final DateTime? lu = _derniereLecture;
    final int? batterie = _montre.batterie;
    final bool batterieFaible = batterie != null && batterie <= 15 && !_montre.enCharge;

    return Section(
      titre: 'Montre Mibro C2 (Bluetooth)',
      icone: Icons.watch_outlined,
      action: etat == null
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Pastille(
              libelle: ok ? 'Connectée' : 'Non connectée',
              couleur: ok ? AppColors.success : AppColors.danger,
              icone: ok ? Icons.check_circle_outline : Icons.link_off,
            ),
      children: [
        Info(
          icone: Icons.info_outline,
          texte: etat == null
              ? 'Recherche de la montre...'
              : (ok ? '${etat.libelle} (${_montre.nomMontre})' : etat.libelle),
        ),
        if (ok && lu != null)
          Info(
            icone: Icons.schedule,
            texte: 'Dernière lecture ${DispatchUi.heure(lu)} · toutes les minutes',
          ),
        if (batterieFaible)
          Info(
            icone: Icons.battery_alert,
            texte: 'Batterie faible ($batterie %) : recharge la montre, '
                'sinon la surveillance s\'arrête',
            couleur: AppColors.danger,
          ),
        if (ok) _TableauMontre(montre: _montre),
        if (ok)
          const Info(
            icone: Icons.timer_outlined,
            texte: 'Mesure automatique : à activer dans Mibro Fit '
                '(surveillance continue du rythme cardiaque)',
          ),
        if (etat != null && !ok && etat != EtatMontre.indisponible)
          FilledButton.icon(
            onPressed: _connecter,
            icon: const Icon(Icons.bluetooth_searching),
            label: const Text('Connecter la montre'),
          ),
        if (etat == EtatMontre.indisponible)
          const Info(
            icone: Icons.phone_android,
            texte: 'Lancez l\'app sur un vrai téléphone Android avec Bluetooth. '
                'Le mode démo reste utilisable.',
          ),
      ],
    );
  }
}

/// Carte sombre : dernière valeur + courbe des 3 dernières heures.
class _CarteRythme extends StatelessWidget {
  const _CarteRythme({
    required this.derniere,
    required this.etat,
    required this.mesures,
    required this.seuils,
    required this.anomalies,
  });

  final MesureCardiaque? derniere;
  final EtatRythme? etat;
  final List<MesureCardiaque> mesures;
  final SeuilsCardiaques seuils;
  final int anomalies;

  @override
  Widget build(BuildContext context) {
    final MesureCardiaque? m = derniere;
    final EtatRythme? e = etat;
    final bool normal = e == null || e == EtatRythme.normal;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Icon(Icons.favorite, color: normal ? AppColors.ecg : AppColors.danger, size: 30),
              const SizedBox(width: 10),
              Text(
                m == null ? '--' : '${m.bpm}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 48,
                  height: 1,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(left: 6, bottom: 4),
                child: Text('bpm', style: TextStyle(color: Colors.white70, fontSize: 16)),
              ),
              const Spacer(),
              if (e != null)
                Pastille(
                  libelle: e.libelle,
                  couleur: normal ? AppColors.ecg : AppColors.danger,
                  icone: normal ? Icons.check_circle_outline : Icons.warning_amber_rounded,
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            m == null
                ? 'Aucune mesure sur les 3 dernières heures'
                : '${DispatchUi.ilYa(m.date)} · ${m.simulee ? 'simulation' : (m.source.isEmpty ? 'montre' : m.source)}'
                    '${anomalies > 0 ? ' · $anomalies mesure(s) anormale(s) de suite' : ''}',
            style: const TextStyle(color: Colors.white60, fontSize: 12.5),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 130,
            width: double.infinity,
            child: CustomPaint(
              painter: _CourbePainter(mesures: mesures, seuils: seuils),
            ),
          ),
          const SizedBox(height: 6),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('-3 h', style: TextStyle(color: Colors.white38, fontSize: 11)),
              Text('maintenant', style: TextStyle(color: Colors.white38, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}

/// Courbe du rythme (une série) + lignes de seuil pointillées.
class _CourbePainter extends CustomPainter {
  _CourbePainter({required this.mesures, required this.seuils});

  final List<MesureCardiaque> mesures;
  final SeuilsCardiaques seuils;

  @override
  void paint(Canvas canvas, Size size) {
    final DateTime fin = DateTime.now();
    final DateTime debut = fin.subtract(const Duration(hours: 3));
    int bas = seuils.min - 10;
    int haut = seuils.max + 20;
    for (final MesureCardiaque m in mesures) {
      bas = math.min(bas, m.bpm - 5);
      haut = math.max(haut, m.bpm + 5);
    }

    double x(DateTime d) {
      final double t = d.difference(debut).inSeconds / fin.difference(debut).inSeconds;
      return t.clamp(0.0, 1.0) * size.width;
    }

    double y(int bpm) => size.height - (bpm - bas) / (haut - bas) * size.height;

    // Seuils (pointillés) + étiquettes
    final Paint seuil = Paint()
      ..color = AppColors.danger.withValues(alpha: 0.7)
      ..strokeWidth = 1;
    for (final int v in [seuils.min, seuils.max]) {
      final double yy = y(v);
      for (double xx = 0; xx < size.width; xx += 8) {
        canvas.drawLine(Offset(xx, yy), Offset(math.min(xx + 4, size.width), yy), seuil);
      }
      final TextPainter tp = TextPainter(
        text: TextSpan(
          text: '$v',
          style: const TextStyle(color: Colors.white54, fontSize: 10),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(0, yy - tp.height - 1));
    }

    final List<MesureCardiaque> visibles = [];
    for (final MesureCardiaque m in mesures) {
      if (!m.date.isBefore(debut)) {
        visibles.add(m);
      }
    }
    if (visibles.isEmpty) {
      return;
    }

    final Path chemin = Path();
    for (int i = 0; i < visibles.length; i++) {
      final Offset p = Offset(x(visibles[i].date), y(visibles[i].bpm));
      if (i == 0) {
        chemin.moveTo(p.dx, p.dy);
      } else {
        chemin.lineTo(p.dx, p.dy);
      }
    }
    canvas.drawPath(
      chemin,
      Paint()
        ..color = AppColors.ecg
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round,
    );

    final MesureCardiaque der = visibles.last;
    final Offset point = Offset(x(der.date), y(der.bpm));
    final bool anormal = seuils.evaluer(der.bpm) != EtatRythme.normal;
    canvas.drawCircle(point, 6, Paint()..color = AppColors.ink);
    canvas.drawCircle(point, 4.5, Paint()..color = anormal ? AppColors.danger : AppColors.ecg);
  }

  @override
  bool shouldRepaint(_CourbePainter ancien) => true;
}

/// « Ça va ? » : 30 s pour annuler, sinon l'ambulance part.
class _DialogueAlerte extends StatefulWidget {
  const _DialogueAlerte({required this.alerte});

  final AlerteCardiaque alerte;

  @override
  State<_DialogueAlerte> createState() => _DialogueAlerteState();
}

class _DialogueAlerteState extends State<_DialogueAlerte> {
  static const int _delai = 30;
  int _restant = _delai;
  Timer? _minuterie;

  @override
  void initState() {
    super.initState();
    _minuterie = Timer.periodic(const Duration(seconds: 1), (Timer t) {
      if (!mounted) {
        return;
      }
      if (_restant <= 1) {
        t.cancel();
        Navigator.pop(context, true);
        return;
      }
      setState(() => _restant--);
    });
  }

  @override
  void dispose() {
    _minuterie?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AlerteCardiaque a = widget.alerte;
    return AlertDialog(
      icon: const Icon(Icons.monitor_heart, color: AppColors.danger, size: 44),
      title: Text('${a.mesure.bpm} bpm : rythme ${a.etat.libelle.toLowerCase()}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Est-ce que tout va bien ?',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'Sans réponse, une ambulance (urgence ${a.gravite.libelle.toLowerCase()}) '
            'sera envoyée dans $_restant s.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          LinearProgressIndicator(
            value: _restant / _delai,
            minHeight: 6,
            color: AppColors.danger,
            backgroundColor: AppColors.surfaceGrey,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Je vais bien'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Envoyer maintenant'),
        ),
      ],
    );
  }
}

/// Tableau de bord de la montre : batterie, signal, activité, rythme du jour.
class _TableauMontre extends StatelessWidget {
  const _TableauMontre({required this.montre});

  final MontreBleService montre;

  @override
  Widget build(BuildContext context) {
    final int? batterie = montre.batterie;
    final int? signal = montre.signal;
    final DateTime? synchro = montre.derniereSynchro;

    // Rythme du jour (relevés réels de la montre)
    final List<MesureCardiaque> jour = montre.relevesAujourdhui;
    String rythme = '—';
    String detailRythme = 'Aucun relevé aujourd\'hui';
    if (jour.isNotEmpty) {
      int min = jour.first.bpm;
      int max = jour.first.bpm;
      int somme = 0;
      for (final MesureCardiaque m in jour) {
        min = math.min(min, m.bpm);
        max = math.max(max, m.bpm);
        somme += m.bpm;
      }
      rythme = '${(somme / jour.length).round()} bpm';
      detailRythme = 'min $min · max $max · ${jour.length} relevé(s)';
    }

    final List<String> infos = [];
    final String? modele = montre.modele;
    final String? firmware = montre.firmware;
    if (modele != null) {
      infos.add(modele);
    }
    if (firmware != null) {
      infos.add('v$firmware');
    }

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.75,
      children: [
        _TuileMontre(
          icone: _iconeBatterie(batterie, montre.enCharge),
          couleur: _couleurBatterie(batterie, montre.enCharge),
          titre: 'Batterie',
          valeur: batterie == null ? '—' : '$batterie %',
          detail: batterie == null
              ? 'En attente de la montre'
              : (montre.enCharge ? 'En charge' : 'Sur batterie'),
        ),
        _TuileMontre(
          icone: Icons.bluetooth_connected,
          couleur: _couleurSignal(signal),
          titre: 'Signal',
          valeur: _qualiteSignal(signal),
          detail: signal == null ? '—' : '$signal dBm',
        ),
        _TuileMontre(
          icone: Icons.directions_walk,
          couleur: AppColors.primary,
          titre: 'Pas aujourd\'hui',
          valeur: _milliers(montre.pasAujourdhui),
          detail: '${_milliers(montre.caloriesAujourdhui)} kcal',
        ),
        _TuileMontre(
          icone: Icons.favorite_border,
          couleur: AppColors.danger,
          titre: 'Rythme moyen du jour',
          valeur: rythme,
          detail: detailRythme,
        ),
        _TuileMontre(
          icone: Icons.watch_outlined,
          couleur: AppColors.textSecondary,
          titre: 'Montre',
          valeur: montre.nomMontre,
          detail: infos.isEmpty ? 'Mibro C2' : infos.join(' · '),
        ),
        _TuileMontre(
          icone: Icons.sync,
          couleur: AppColors.textSecondary,
          titre: 'Dernière synchro',
          valeur: synchro == null ? '—' : DispatchUi.heure(synchro),
          detail: synchro == null ? '—' : DispatchUi.ilYa(synchro),
        ),
      ],
    );
  }

  static IconData _iconeBatterie(int? niveau, bool enCharge) {
    if (enCharge) {
      return Icons.battery_charging_full;
    }
    if (niveau == null) {
      return Icons.battery_unknown;
    }
    if (niveau <= 15) {
      return Icons.battery_alert;
    }
    if (niveau >= 80) {
      return Icons.battery_full;
    }
    return Icons.battery_std;
  }

  static Color _couleurBatterie(int? niveau, bool enCharge) {
    if (enCharge) {
      return AppColors.primary;
    }
    if (niveau == null) {
      return AppColors.textSecondary;
    }
    if (niveau <= 15) {
      return AppColors.danger;
    }
    if (niveau <= 30) {
      return AppColors.warning;
    }
    return AppColors.success;
  }

  static String _qualiteSignal(int? rssi) {
    if (rssi == null) {
      return '—';
    }
    if (rssi >= -60) {
      return 'Excellent';
    }
    if (rssi >= -75) {
      return 'Bon';
    }
    if (rssi >= -90) {
      return 'Faible';
    }
    return 'Très faible';
  }

  static Color _couleurSignal(int? rssi) {
    if (rssi == null) {
      return AppColors.textSecondary;
    }
    if (rssi >= -75) {
      return AppColors.success;
    }
    if (rssi >= -90) {
      return AppColors.warning;
    }
    return AppColors.danger;
  }

  /// 1247 → « 1 247 »
  static String _milliers(int v) {
    final String s = v.toString();
    final StringBuffer sb = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) {
        sb.write(' ');
      }
      sb.write(s[i]);
    }
    return sb.toString();
  }
}

class _TuileMontre extends StatelessWidget {
  const _TuileMontre({
    required this.icone,
    required this.couleur,
    required this.titre,
    required this.valeur,
    required this.detail,
  });

  final IconData icone;
  final Color couleur;
  final String titre;
  final String valeur;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
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
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  titre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
          const Spacer(),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              valeur,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
          ),
          Text(
            detail,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
