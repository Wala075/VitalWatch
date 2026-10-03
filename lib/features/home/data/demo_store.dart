import 'package:flutter/foundation.dart';

import 'demo_data.dart';

/// État partagé (en mémoire) de l'espace santé : rendez-vous, favoris,
/// eau bue et onglet affiché.
class DemoStore extends ChangeNotifier {
  DemoStore._() {
    _initialiser();
  }

  static final DemoStore instance = DemoStore._();

  static const int objectifVerres = 8;

  final List<DemoRdv> _rdvs = [];
  final Set<int> _favoris = {1, 5};
  int _prochainId = 100;

  int verresEau = 3;
  int onglet = 0;
  String? filtreCategorie;

  void _initialiser() {
    final DateTime n = DateTime.now();
    DateTime jour(int decalage, int h, int m) =>
        DateTime(n.year, n.month, n.day + decalage, h, m);
    const List<DemoDoctor> d = DemoData.medecins;

    _rdvs.addAll([
      DemoRdv(id: 1, medecin: d[0], date: jour(1, 10, 30)),
      DemoRdv(id: 2, medecin: d[4], date: jour(2, 11, 30)),
      DemoRdv(id: 3, medecin: d[2], date: jour(4, 15, 0)),
      DemoRdv(
        id: 4,
        medecin: d[5],
        date: jour(-3, 15, 0),
        statut: StatutRdv.annule,
      ),
      DemoRdv(
        id: 5,
        medecin: d[1],
        date: jour(-12, 9, 0),
        statut: StatutRdv.termine,
      ),
      DemoRdv(
        id: 6,
        medecin: d[3],
        date: jour(-26, 11, 30),
        statut: StatutRdv.termine,
      ),
    ]);
  }

  List<DemoRdv> get aVenir {
    final List<DemoRdv> res = [];
    for (final DemoRdv r in _rdvs) {
      if (r.statutEffectif == StatutRdv.aVenir) {
        res.add(r);
      }
    }
    res.sort((a, b) => a.date.compareTo(b.date));
    return res;
  }

  List<DemoRdv> get passes {
    final List<DemoRdv> res = [];
    for (final DemoRdv r in _rdvs) {
      if (r.statutEffectif != StatutRdv.aVenir) {
        res.add(r);
      }
    }
    res.sort((a, b) => b.date.compareTo(a.date));
    return res;
  }

  DemoRdv? get prochain {
    final List<DemoRdv> liste = aVenir;
    return liste.isEmpty ? null : liste.first;
  }

  DemoRdv reserver(DemoDoctor medecin, DateTime date) {
    final DemoRdv r = DemoRdv(id: _prochainId++, medecin: medecin, date: date);
    _rdvs.add(r);
    notifyListeners();
    return r;
  }

  void annuler(DemoRdv r) {
    r.statut = StatutRdv.annule;
    notifyListeners();
  }

  bool estFavori(DemoDoctor m) => _favoris.contains(m.id);

  void basculerFavori(DemoDoctor m) {
    if (!_favoris.remove(m.id)) {
      _favoris.add(m.id);
    }
    notifyListeners();
  }

  void ajouterVerre() {
    if (verresEau < objectifVerres) {
      verresEau++;
      notifyListeners();
    }
  }

  void retirerVerre() {
    if (verresEau > 0) {
      verresEau--;
      notifyListeners();
    }
  }

  /// Change d'onglet (et filtre éventuellement les médecins par spécialité).
  void allerA(int index, {String? categorie}) {
    onglet = index;
    filtreCategorie = categorie;
    notifyListeners();
  }

  void choisirCategorie(String? categorie) {
    filtreCategorie = categorie;
    notifyListeners();
  }
}
