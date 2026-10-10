import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_dropdown_field.dart';
import '../../../../core/widgets/error_banner.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../models/patient.dart';
import '../../data/api/geolocalisation_service.dart';
import '../../data/api/nominatim_api.dart';
import '../../data/patient_lookup.dart';
import '../../domain/dispatch_manager.dart';
import '../../domain/dispatch_models.dart';
import '../../domain/models/intervention.dart';
import '../providers/dispatch_controller.dart';
import '../widgets/carte_osm.dart';
import '../widgets/dispatch_ui.dart';
import 'choix_position_screen.dart';
import 'intervention_detail_screen.dart';

/// Nouvelle urgence : lieu (Nominatim / GPS / carte), gravité, patient,
/// aperçu du dispatch automatique puis déclenchement.
class InterventionFormScreen extends StatefulWidget {
  const InterventionFormScreen({super.key, this.position, this.adresse});

  final LatLng? position;
  final String? adresse;

  @override
  State<InterventionFormScreen> createState() => _InterventionFormScreenState();
}

class _InterventionFormScreenState extends State<InterventionFormScreen> {
  final TextEditingController _rechercheCtrl = TextEditingController();
  final NominatimApi _nominatim = NominatimApi();
  final GeolocalisationService _gps = GeolocalisationService();
  final PatientLookup _patients = PatientLookup();
  final DispatchController _ctrl = DispatchController.instance;

  LatLng? _position;
  String? _adresse;
  Gravite _gravite = Gravite.urgente;
  OrigineIntervention _origine = OrigineIntervention.appel;
  int? _patientId;
  List<Patient> _listePatients = [];
  List<AdresseTrouvee> _resultats = [];
  List<CandidatDispatch> _candidats = [];
  bool _recherche = false;
  bool _envoi = false;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _position = widget.position;
    _adresse = widget.adresse;
    _chargerPatients();
    final LatLng? p = widget.position;
    if (p != null) {
      _apercu();
      if (_adresse == null) {
        _adresseDe(p);
      }
    }
  }

  @override
  void dispose() {
    _rechercheCtrl.dispose();
    super.dispose();
  }

  Future<void> _chargerPatients() async {
    final List<Patient> res = await _patients.lister();
    if (mounted) {
      setState(() => _listePatients = res);
    }
  }

  Future<void> _adresseDe(LatLng p) async {
    final String? a = await _nominatim.adresseDe(p);
    if (mounted && _position == p) {
      setState(() => _adresse = a ?? _coordonnees(p));
    }
  }

  String _coordonnees(LatLng p) =>
      '${p.latitude.toStringAsFixed(5)}, ${p.longitude.toStringAsFixed(5)}';

  /// Géocodage Nominatim (lancé à la validation : 1 requête/s max).
  Future<void> _rechercher() async {
    FocusScope.of(context).unfocus();
    final String texte = _rechercheCtrl.text.trim();
    if (texte.length < 3) {
      DispatchUi.snack(context, 'Saisissez au moins 3 caractères', erreur: true);
      return;
    }
    setState(() {
      _recherche = true;
      _resultats = [];
    });
    final List<AdresseTrouvee> res = await _nominatim.rechercher(texte);
    if (!mounted) {
      return;
    }
    setState(() {
      _recherche = false;
      _resultats = res;
    });
    if (res.isEmpty) {
      DispatchUi.snack(context, 'Aucune adresse trouvée (ou pas de réseau)', erreur: true);
    }
  }

  void _choisir(LatLng p, String? adresse) {
    setState(() {
      _position = p;
      _adresse = adresse;
      _resultats = [];
      _erreur = null;
    });
    if (adresse == null) {
      _adresseDe(p);
    }
    _apercu();
  }

  Future<void> _maPosition() async {
    try {
      final LatLng p = await _gps.positionActuelle();
      if (!mounted) {
        return;
      }
      if (!DispatchManager.dansZone(p)) {
        DispatchUi.snack(
          context,
          'Votre position GPS est hors zone : choisissez le lieu sur la carte',
          erreur: true,
        );
        return;
      }
      _choisir(p, null);
    } on DispatchException catch (e) {
      if (mounted) {
        DispatchUi.snack(context, e.message, erreur: true);
      }
    }
  }

  Future<void> _surCarte() async {
    final PositionChoisie? choix = await Navigator.push<PositionChoisie>(
      context,
      MaterialPageRoute(
        builder: (_) => ChoixPositionScreen(initiale: _position, titre: "Lieu de l'urgence"),
      ),
    );
    if (choix != null && mounted) {
      _choisir(choix.position, choix.adresse);
    }
  }

  /// Classement Haversine des ambulances pour le lieu + la gravité choisis.
  Future<void> _apercu() async {
    final LatLng? p = _position;
    if (p == null) {
      return;
    }
    final List<CandidatDispatch> res = await _ctrl.manager.apercu(p, _gravite);
    if (mounted) {
      setState(() => _candidats = res);
    }
  }

  Future<void> _declencher() async {
    final LatLng? p = _position;
    if (p == null) {
      setState(() => _erreur = "Indiquez le lieu de l'urgence");
      return;
    }
    if (_origine == OrigineIntervention.alerte && _patientId == null) {
      setState(() => _erreur = 'Une alerte vitale concerne un patient : sélectionnez-le');
      return;
    }
    setState(() {
      _envoi = true;
      _erreur = null;
    });
    try {
      final ResultatDispatch r = await _ctrl.creerIntervention(
        adresse: _adresse ?? _coordonnees(p),
        position: p,
        gravite: _gravite,
        origine: _origine,
        patientId: _patientId,
      );
      if (!mounted) {
        return;
      }
      await _afficherResultat(r);
      final int? id = r.intervention.id;
      if (!mounted || id == null) {
        return;
      }
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => InterventionDetailScreen(interventionId: id)),
      );
    } on DispatchException catch (e) {
      _echec(e.message);
    } catch (e) {
      _echec('Création impossible : $e');
    }
  }

  void _echec(String message) {
    if (!mounted) {
      return;
    }
    setState(() {
      _erreur = message;
      _envoi = false;
    });
  }

  Future<void> _afficherResultat(ResultatDispatch r) {
    final bool ok = r.assignee;
    return showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        icon: Icon(
          ok ? Icons.airport_shuttle : Icons.hourglass_top,
          color: ok ? AppColors.success : AppColors.danger,
          size: 40,
        ),
        title: Text(ok ? 'Ambulance envoyée' : "En file d'attente"),
        content: Text(r.justification ?? ''),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Suivre'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final LatLng? p = _position;
    final String? erreur = _erreur;

    return Scaffold(
      appBar: AppBar(title: const Text('Nouvelle urgence')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (erreur != null) ...[
            ErrorBanner(message: erreur),
            const SizedBox(height: 12),
          ],
          Section(
            titre: "Lieu de l'urgence",
            icone: Icons.place_outlined,
            children: [
              TextField(
                controller: _rechercheCtrl,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _rechercher(),
                decoration: InputDecoration(
                  hintText: 'Adresse, quartier, ville... (Nominatim)',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _recherche
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : IconButton(
                          icon: const Icon(Icons.arrow_forward),
                          onPressed: _rechercher,
                        ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              for (final AdresseTrouvee a in _resultats)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.location_on_outlined, color: AppColors.primary),
                  title: Text(a.libelle),
                  onTap: () => _choisir(a.position, a.libelle),
                ),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _maPosition,
                      icon: const Icon(Icons.my_location),
                      label: const Text('Ma position'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _surCarte,
                      icon: const Icon(Icons.map_outlined),
                      label: const Text('Sur la carte'),
                    ),
                  ),
                ],
              ),
              if (p != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(height: 170, child: _apercuCarte(p)),
                ),
                Info(
                  icone: Icons.place,
                  texte: _adresse ?? 'Recherche de l\'adresse...',
                  couleur: AppColors.textPrimary,
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          Section(
            titre: 'Gravité',
            icone: Icons.emergency_outlined,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final Gravite g in Gravite.values)
                    ChoiceChip(
                      avatar: Icon(
                        DispatchUi.iconeGravite(g),
                        size: 18,
                        color: _gravite == g ? Colors.white : DispatchUi.gravite(g),
                      ),
                      label: Text(g.libelle),
                      selected: _gravite == g,
                      showCheckmark: false,
                      selectedColor: DispatchUi.gravite(g),
                      labelStyle: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: _gravite == g ? Colors.white : DispatchUi.gravite(g),
                      ),
                      onSelected: (_) {
                        setState(() => _gravite = g);
                        _apercu();
                      },
                    ),
                ],
              ),
              Info(icone: Icons.info_outline, texte: _aideGravite(_gravite)),
            ],
          ),
          const SizedBox(height: 14),
          Section(
            titre: 'Patient et origine',
            icone: Icons.person_outline,
            children: [
              AppDropdownField<int?>(
                label: 'Patient (facultatif)',
                icon: Icons.person_search_outlined,
                value: _patientId,
                items: [
                  const DropdownMenuItem<int?>(value: null, child: Text('Inconnu / non identifié')),
                  for (final Patient pa in _listePatients)
                    DropdownMenuItem<int?>(
                      value: pa.id,
                      child: Text('${pa.nomComplet} · ${pa.age} ans'),
                    ),
                ],
                onChanged: (int? v) => setState(() => _patientId = v),
              ),
              SegmentedButton<OrigineIntervention>(
                segments: const [
                  ButtonSegment(
                    value: OrigineIntervention.appel,
                    icon: Icon(Icons.phone_in_talk_outlined),
                    label: Text('Appel'),
                  ),
                  ButtonSegment(
                    value: OrigineIntervention.alerte,
                    icon: Icon(Icons.monitor_heart_outlined),
                    label: Text('Alerte vitale'),
                  ),
                ],
                selected: {_origine},
                onSelectionChanged: (Set<OrigineIntervention> s) =>
                    setState(() => _origine = s.first),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _apercuDispatch(),
          const SizedBox(height: 20),
          PrimaryButton(
            label: "Déclencher l'intervention",
            icon: Icons.send_rounded,
            loading: _envoi,
            onPressed: _declencher,
          ),
        ],
      ),
    );
  }

  String _aideGravite(Gravite g) {
    switch (g) {
      case Gravite.critique:
        return 'Type C (SMUR) en priorité, type B accepté. Peut réquisitionner une '
            'ambulance engagée sur une mission moins grave.';
      case Gravite.urgente:
        return 'Type B en priorité, puis C, puis A.';
      case Gravite.moderee:
        return 'Type A en priorité pour garder les B/C libres.';
      case Gravite.faible:
        return 'Type A en priorité, le type C est réservé aux urgences graves.';
    }
  }

  Widget _apercuCarte(LatLng p) {
    final List<Marker> marqueurs = [];
    for (int k = 0; k < _candidats.length && k < 3; k++) {
      marqueurs.add(Marker(
        point: _candidats[k].ambulance.position,
        width: 38,
        height: 38,
        child: MarqueurAmbulance(ambulance: _candidats[k].ambulance, selection: k == 0),
      ));
    }
    marqueurs.add(Marker(
      point: p,
      width: 44,
      height: 44,
      alignment: Alignment.topCenter,
      child: const MarqueurChoix(),
    ));
    return CarteOsm(
      key: ValueKey<LatLng>(p),
      centre: p,
      zoom: 12,
      interactive: false,
      couches: [MarkerLayer(markers: marqueurs)],
    );
  }

  Widget _apercuDispatch() {
    if (_position == null) {
      return const SizedBox.shrink();
    }
    return Section(
      titre: 'Dispatch automatique (Haversine)',
      icone: Icons.alt_route,
      children: [
        if (_candidats.isEmpty)
          Info(
            icone: Icons.hourglass_top,
            texte: _gravite == Gravite.critique
                ? 'Aucune ambulance libre : réquisition ou file d\'attente prioritaire'
                : "Aucune ambulance adaptée libre : mise en file d'attente",
            couleur: AppColors.danger,
          ),
        for (int k = 0; k < _candidats.length && k < 3; k++)
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: k == 0 ? AppColors.success : AppColors.surfaceGrey,
                child: Text(
                  '${k + 1}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: k == 0 ? Colors.white : AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${_candidats[k].ambulance.immatriculation} · ${_candidats[k].ambulance.type.libelle}',
                  style: TextStyle(fontWeight: k == 0 ? FontWeight.w800 : FontWeight.w500),
                ),
              ),
              Text(
                '${DispatchUi.distance(_candidats[k].distanceKm)} · score ${_candidats[k].score.toStringAsFixed(1)}',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
      ],
    );
  }
}
