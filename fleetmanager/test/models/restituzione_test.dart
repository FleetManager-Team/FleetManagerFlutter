import 'package:flutter_test/flutter_test.dart';
import 'package:fleetmanager/models/restituzione.dart';

void main() {
  group('Restituzione model', () {
    test('fromJson mappa correttamente', () {
      final json = {
        'id_restituzione': 1,
        'id_prenotazione': 2,
        'km_finali': 1200,
        'data_restituzione': DateTime.utc(2024, 5, 1).toIso8601String(),
        'rifornimento_effettuato': true,
        'litri_carburante': 20.5,
        'importo_euro': 50.0,
        'url_scontrino': 's',
        'ha_pedaggi': true,
        'importo_pedaggi': 5.0,
        'url_foto_pedaggio': 'p',
        'danni_presenti': false,
        'descrizione_danni': null,
        'url_foto_danni': null,
        'is_emergenza': true,
        'note_emergenza': 'g',
        'posizione_emergenza': '45,9',
      };

      final r = Restituzione.fromJson(json);

      expect(r.idRestituzione, 1);
      expect(r.idPrenotazione, 2);
      expect(r.kmFinali, 1200);
      expect(r.rifornimentoEffettuato, true);
      expect(r.litriCarburante, 20.5);
      expect(r.importoEuro, 50.0);
      expect(r.haPedaggi, true);
      expect(r.importoPedaggi, 5.0);
      expect(r.isEmergenza, true);
      expect(r.noteEmergenza, 'g');
      expect(r.posizioneEmergenza, '45,9');
    });

    test('toJson include id se presente', () {
      final r = Restituzione(
        idRestituzione: 3,
        idPrenotazione: 4,
        kmFinali: 2000,
        dataRestituzione: DateTime(2024, 5, 2),
        rifornimentoEffettuato: false,
        haPedaggi: false,
        danniPresenti: true,
      );

      final json = r.toJson();
      expect(json['id_restituzione'], 3);
      expect(json['id_prenotazione'], 4);
      expect(json['km_finali'], 2000);
      expect(json['danni_presenti'], true);
    });
  });
}
