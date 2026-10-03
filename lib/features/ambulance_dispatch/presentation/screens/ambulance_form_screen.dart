import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/widgets/app_dropdown_field.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/error_banner.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../domain/dispatch_manager.dart';
import '../../domain/dispatch_models.dart';
import '../../domain/models/ambulance.dart';
import '../providers/dispatch_controller.dart';
import '../widgets/carte_osm.dart';
import '../widgets/dispatch_ui.dart';
import 'choix_position_screen.dart';

class AmbulanceFormScreen extends StatefulWidget {
  const AmbulanceFormScreen({super.key, this.ambulance});

  final Ambulance? ambulance;

  @override
  State<AmbulanceFormScreen> createState() => _AmbulanceFormScreenState();
}

class _AmbulanceFormScreenState extends State<AmbulanceFormScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _immatCtrl = TextEditingController();
  final TextEditingController _kmCtrl = TextEditingController();
  final DispatchManager _manager = DispatchController.instance.manager;

  TypeAmbulance _type = TypeAmbulance.b;
  StatutAmbulance _statut = StatutAmbulance.disponible;
  LatLng _position = DispatchManager.centreZone;
  String? _adresse;
  bool _enregistrement = false;
  String? _erreur;

  bool get _edition => widget.ambulance != null;

  bool get _enMission => widget.ambulance?.statut == StatutAmbulance.enMission;

  @override
  void initState() {
    super.initState();
    final Ambulance? a = widget.ambulance;
    if (a != null) {
      _immatCtrl.text = a.immatriculation;
      _kmCtrl.text = '${a.kilometrage}';
      _type = a.type;
      _statut = a.statut;
      _position = a.position;
    } else {
      _kmCtrl.text = '0';
    }
  }

  @override
  void dispose() {
    _immatCtrl.dispose();
    _kmCtrl.dispose();
    super.dispose();
  }

  Future<void> _choisirPosition() async {
    final PositionChoisie? choix = await Navigator.push<PositionChoisie>(
      context,
      MaterialPageRoute(
        builder: (_) => ChoixPositionScreen(
          initiale: _position,
          titre: "Base de l'ambulance",
        ),
      ),
    );
    if (choix == null || !mounted) {
      return;
    }
    setState(() {
      _position = choix.position;
      _adresse = choix.adresse;
    });
  }

  Future<void> _enregistrer() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _enregistrement = true;
      _erreur = null;
    });
    try {
      await _manager.enregistrerAmbulance(Ambulance(
        id: widget.ambulance?.id,
        immatriculation: _immatCtrl.text,
        type: _type,
        statut: _statut,
        latitude: _position.latitude,
        longitude: _position.longitude,
        kilometrage: int.parse(_kmCtrl.text.trim()),
      ));
      await DispatchController.instance.rafraichir();
      if (!mounted) {
        return;
      }
      Navigator.pop(context, true);
    } on DispatchException catch (e) {
      _echec(e.message);
    } catch (e) {
      _echec('Enregistrement impossible : $e');
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

  String? _validerImmat(String? v) {
    if (v == null || v.trim().isEmpty) {
      return "L'immatriculation est obligatoire";
    }
    if (DispatchManager.normaliserImmatriculation(v) == null) {
      return 'Format tunisien attendu : 214 TU 5521';
    }
    return null;
  }

  String? _validerKm(String? v) {
    final int? km = int.tryParse((v ?? '').trim());
    if (km == null) {
      return 'Kilométrage invalide';
    }
    if (km < 0) {
      return 'Le kilométrage ne peut pas être négatif';
    }
    final Ambulance? a = widget.ambulance;
    if (a != null && km < a.kilometrage) {
      return 'Ne peut pas diminuer (actuel : ${a.kilometrage})';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final List<StatutAmbulance> statuts = [
      StatutAmbulance.disponible,
      StatutAmbulance.horsService,
      if (_statut == StatutAmbulance.maintenance) StatutAmbulance.maintenance,
      if (_statut == StatutAmbulance.enMission) StatutAmbulance.enMission,
    ];
    final String? erreur = _erreur;

    return Scaffold(
      appBar: AppBar(title: Text(_edition ? "Modifier l'ambulance" : 'Nouvelle ambulance')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (erreur != null) ...[
              ErrorBanner(message: erreur),
              const SizedBox(height: 12),
            ],
            Section(
              titre: 'Véhicule',
              icone: Icons.airport_shuttle,
              children: [
                AppTextField(
                  controller: _immatCtrl,
                  label: 'Immatriculation',
                  hint: '214 TU 5521',
                  icon: Icons.pin_outlined,
                  textCapitalization: TextCapitalization.characters,
                  validator: _validerImmat,
                ),
                AppDropdownField<TypeAmbulance>(
                  label: 'Type',
                  icon: Icons.category_outlined,
                  value: _type,
                  items: [
                    for (final TypeAmbulance t in TypeAmbulance.values)
                      DropdownMenuItem(
                        value: t,
                        child: Text('${t.libelle} · ${t.description}'),
                      ),
                  ],
                  onChanged: (TypeAmbulance? t) {
                    if (t != null) {
                      setState(() => _type = t);
                    }
                  },
                ),
                AppTextField(
                  controller: _kmCtrl,
                  label: 'Kilométrage',
                  icon: Icons.speed,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: _validerKm,
                ),
                AppDropdownField<StatutAmbulance>(
                  label: 'Statut',
                  icon: Icons.toggle_on_outlined,
                  value: _statut,
                  enabled: !_enMission && _statut != StatutAmbulance.maintenance,
                  items: [
                    for (final StatutAmbulance s in statuts)
                      DropdownMenuItem(value: s, child: Text(s.libelle)),
                  ],
                  onChanged: (StatutAmbulance? s) {
                    if (s != null) {
                      setState(() => _statut = s);
                    }
                  },
                ),
                if (_statut == StatutAmbulance.maintenance)
                  const Info(
                    icone: Icons.info_outline,
                    texte: 'Statut géré automatiquement par la maintenance préventive',
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Section(
              titre: 'Base / position',
              icone: Icons.place_outlined,
              action: _enMission
                  ? null
                  : TextButton.icon(
                      onPressed: _choisirPosition,
                      icon: const Icon(Icons.edit_location_alt_outlined, size: 18),
                      label: const Text('Modifier'),
                    ),
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    height: 170,
                    child: CarteOsm(
                      key: ValueKey<LatLng>(_position),
                      centre: _position,
                      zoom: 14,
                      interactive: false,
                      couches: [
                        MarkerLayer(markers: [
                          Marker(
                            point: _position,
                            width: 44,
                            height: 44,
                            alignment: Alignment.topCenter,
                            child: const MarqueurChoix(),
                          ),
                        ]),
                      ],
                    ),
                  ),
                ),
                Info(
                  icone: Icons.my_location,
                  texte: _adresse ??
                      '${_position.latitude.toStringAsFixed(5)}, '
                          '${_position.longitude.toStringAsFixed(5)}',
                ),
                if (_enMission)
                  const Info(
                    icone: Icons.navigation_outlined,
                    texte: 'En mission : position mise à jour par le suivi temps réel',
                  ),
              ],
            ),
            const SizedBox(height: 20),
            PrimaryButton(
              label: _edition ? 'Enregistrer' : "Ajouter l'ambulance",
              icon: Icons.save_outlined,
              loading: _enregistrement,
              onPressed: _enregistrer,
            ),
          ],
        ),
      ),
    );
  }
}
