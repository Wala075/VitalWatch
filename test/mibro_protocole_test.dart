import 'package:flutter_test/flutter_test.dart';
import 'package:projet/features/ambulance_dispatch/data/api/mibro_protocole.dart';
import 'package:projet/features/ambulance_dispatch/domain/surveillance_cardiaque.dart';

/// Paquets réels reçus de la montre Mibro C2 le 04/10/2026.
void main() {
  List<int> hex(String s) {
    final List<int> res = [];
    for (final String o in s.split(' ')) {
      res.add(int.parse(o, radix: 16));
    }
    return res;
  }

  test('relevé cardiaque 51 11 : date + bpm', () {
    final MesureCardiaque? m =
        MibroProtocole.releveCardiaque(hex('AB 00 0B FF 51 11 1A 0A 04 11 1E 55 55 11'));
    expect(m, isNotNull);
    expect(m?.bpm, 85);
    expect(m?.date, DateTime(2026, 10, 4, 17, 30));
    expect(m?.source, 'Mibro C2');
  });

  test('un résumé horaire 51 20 n\'est pas un relevé cardiaque', () {
    expect(
      MibroProtocole.releveCardiaque(
        hex('AB 00 16 FF 51 20 1A 0A 04 0E 00 04 DF 00 00 3D 3B 62 00 00 00 00 00 00 00'),
      ),
      isNull,
    );
  });

  test('bpm à 0 (montre non portée) ignoré', () {
    expect(
      MibroProtocole.releveCardiaque(hex('AB 00 0B FF 51 11 1A 0A 04 11 1E 00 00 11')),
      isNull,
    );
  });

  test('batterie 91 : 0x2C = 44 %', () {
    expect(MibroProtocole.niveauBatterie(hex('AB 00 05 FF 91 80 00 2C')), 44);
    expect(MibroProtocole.niveauBatterie(hex('AB 00 0B FF 51 11 1A 0A 04 11 1E 55 55 11')), isNull);
  });

  test('batterie 91 : niveau + en charge', () {
    final EtatBatterie? b = MibroProtocole.batterie(hex('AB 00 05 FF 91 80 01 5A'));
    expect(b?.niveau, 90);
    expect(b?.enCharge, isTrue);
    expect(MibroProtocole.batterie(hex('AB 00 05 FF 91 80 00 2C'))?.enCharge, isFalse);
  });

  test('résumé horaire 51 20 : pas + calories', () {
    final ResumeActivite? a = MibroProtocole.resumeActivite(
      hex('AB 00 16 FF 51 20 1A 0A 04 0E 00 04 DF 00 00 3D 3B 62 00 00 00 00 00 00 00'),
    );
    expect(a?.heure, DateTime(2026, 10, 4, 14));
    expect(a?.pas, 1247);
    expect(a?.calories, 61);
    expect(
      MibroProtocole.resumeActivite(hex('AB 00 0B FF 51 11 1A 0A 04 11 1E 55 55 11')),
      isNull,
    );
  });

  test('demande des relevés depuis le 04/10/2026 00:00', () {
    expect(
      MibroProtocole.demandeReleves(DateTime(2026, 10, 4)),
      hex('AB 00 0E FF 51 80 00 1A 0A 04 00 00 1A 0A 04 00 00'),
    );
  });

  test('réassemblage d\'un paquet coupé en 20 + 6 octets', () {
    final AssembleurPaquets a = AssembleurPaquets();
    expect(a.ajouter(hex('AB 00 16 FF 51 20 1A 0A 04 0C 00 02 6E 00 00 1E 3B 62 00 00')), isEmpty);
    final List<List<int>> complets = a.ajouter(hex('00 00 00 00 00 00'));
    expect(complets.length, 1);
    expect(complets.first.length, 25);
    expect(complets.first[5], 0x20);
  });

  test('paquets courts complets rendus un par un', () {
    final AssembleurPaquets a = AssembleurPaquets();
    final List<List<int>> p1 = a.ajouter(hex('AB 00 0B FF 51 11 1A 0A 04 00 00 5D 5D 11'));
    final List<List<int>> p2 = a.ajouter(hex('AB 00 0B FF 51 11 1A 0A 04 00 05 49 49 11'));
    expect(p1.length, 1);
    expect(p2.length, 1);
    expect(MibroProtocole.releveCardiaque(p1.first)?.bpm, 93);
    expect(MibroProtocole.releveCardiaque(p2.first)?.bpm, 73);
  });

  test('nom Bluetooth de la montre reconnu', () {
    expect(MibroProtocole.estMontre('XPAW009'), isTrue);
    expect(MibroProtocole.estMontre('Mibro Watch C2'), isTrue);
    expect(MibroProtocole.estMontre('TWS-Y'), isFalse);
  });
}
