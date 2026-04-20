import 'package:flutter_test/flutter_test.dart';
import 'package:FleetManager/models/utente.dart';
import 'package:FleetManager/models/enums/ruolo_utente.dart';

void main() {
  group('Utente model', () {
    test('fromJson mappa correttamente', () {
      final json = {
        'id_utente': 1,
        'nome': 'Mario',
        'cognome': 'Rossi',
        'email': 'mario@test.it',
        'ruolo': 'driver',
        'patente': 'B',
      };

      final u = Utente.fromJson(json);

      expect(u.idUtente, 1);
      expect(u.nome, 'Mario');
      expect(u.cognome, 'Rossi');
      expect(u.email, 'mario@test.it');
      expect(u.ruoloUtente, RuoloUtente.driver);
      expect(u.patente, 'B');
    });

    test('toJson include id solo se != 0', () {
      final u1 = Utente(
        idUtente: 0,
        nome: 'A',
        cognome: 'B',
        email: 'a@b.it',
        ruoloUtente: RuoloUtente.driver,
      );
      final json1 = u1.toJson();
      expect(json1.containsKey('id_utente'), false);

      final u2 = Utente(
        idUtente: 10,
        nome: 'A',
        cognome: 'B',
        email: 'a@b.it',
        ruoloUtente: RuoloUtente.manager,
        patente: 'C',
      );
      final json2 = u2.toJson();
      expect(json2['id_utente'], 10);
      expect(json2['ruolo'], 'manager');
      expect(json2['patente'], 'C');
    });
  });
}
