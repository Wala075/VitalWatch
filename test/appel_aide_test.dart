import 'package:flutter_test/flutter_test.dart';
import 'package:projet/features/ambulance_dispatch/domain/appel_aide.dart';

void main() {
  test('normalisation : casse, accents, ponctuation', () {
    expect(DetecteurAppelAide.normaliser("  À l'AIDE !! "), 'a l aide');
    expect(DetecteurAppelAide.normaliser('Aidez-moi, vite.'), 'aidez moi vite');
  });

  test('appels à l\'aide reconnus', () {
    expect(DetecteurAppelAide.detecter('Help'), 'help');
    expect(DetecteurAppelAide.detecter('help me please'), 'help me');
    expect(DetecteurAppelAide.detecter('Au secours !'), 'au secours');
    expect(DetecteurAppelAide.detecter("à l'aide"), 'a l aide');
    expect(DetecteurAppelAide.detecter('aidez-moi'), 'aidez moi');
    expect(DetecteurAppelAide.detecter("j'ai besoin d'aide"), 'besoin d aide');
    expect(DetecteurAppelAide.detecter('S.O.S'), 's o s');
    expect(DetecteurAppelAide.detecter('sos'), 'sos');
  });

  test('phrases ordinaires ignorées', () {
    expect(DetecteurAppelAide.detecter(''), isNull);
    expect(DetecteurAppelAide.detecter('bonjour comment ça va'), isNull);
    expect(DetecteurAppelAide.detecter('helpful'), isNull);
    expect(DetecteurAppelAide.detecter('un cours de secourisme'), isNull);
    expect(DetecteurAppelAide.detecter("l'aide sociale"), isNull);
  });
}
