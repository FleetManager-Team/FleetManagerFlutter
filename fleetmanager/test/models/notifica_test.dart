import 'package:flutter_test/flutter_test.dart';
import 'package:FleetManager/models/notifica.dart';
import 'package:FleetManager/models/enums/tipo_notifica.dart';

void main() {
  group('Notifica model', () {
    test('fromJson mappa correttamente', () {
      final json = {
        'id_notifica': 1,
        'tipo': 'scadenza',
        'messaggio': 'Test',
        'data_invio': DateTime(2024, 4, 1).toIso8601String(),
        'letta': false,
        'id_utente': 10,
        'id_scadenza': 5,
      };

      final n = Notifica.fromJson(json);

      expect(n.idNotifica, 1);
      expect(n.tipoNotifica, TipoNotifica.scadenza);
      expect(n.messaggio, 'Test');
      expect(n.letta, false);
      expect(n.idUtente, 10);
      expect(n.idScadenza, 5);
    });

    test('toJson mappa correttamente', () {
      final n = Notifica(
        idNotifica: 2,
        tipoNotifica: TipoNotifica.info,
        messaggio: 'Ok',
        dataInvio: DateTime(2024, 4, 2),
        letta: true,
        idUtente: 20,
      );

      final json = n.toJson();
      expect(json['id_notifica'], 2);
      expect(json['tipo'], 'info');
      expect(json['messaggio'], 'Ok');
      expect(json['letta'], true);
      expect(json['id_utente'], 20);
    });
  });
}
