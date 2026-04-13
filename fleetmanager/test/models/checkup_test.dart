import 'package:flutter_test/flutter_test.dart';
import 'package:fleetmanager/models/checkup.dart';

void main() {
  group('CheckupVeicolo model', () {
    test('fromJson mappa correttamente', () {
      final json = {
        'id': '1',
        'id_prenotazione': 10,
        'targa': 'AA111AA',
        'driver_id': '7',
        'data_check': DateTime(2024, 6, 1).toIso8601String(),
        'url_foto_fronte': 'f1',
        'url_foto_retro': 'f2',
        'url_foto_dx': 'f3',
        'url_foto_sx': 'f4',
        'luci_ok': true,
        'gomme_ok': false,
        'interni_ok': true,
        'note_danni': 'n',
        'url_firma': 'u',
      };

      final c = CheckupVeicolo.fromJson(json);

      expect(c.id, '1');
      expect(c.idPrenotazione, 10);
      expect(c.targa, 'AA111AA');
      expect(c.driverId, '7');
      expect(c.luciOk, true);
      expect(c.gommeOk, false);
      expect(c.interniOk, true);
      expect(c.noteDanni, 'n');
      expect(c.urlFirma, 'u');
    });

    test('toJson mappa correttamente', () {
      final c = CheckupVeicolo(
        idPrenotazione: 11,
        targa: 'BB222BB',
        driverId: '8',
        dataCheck: DateTime(2024, 6, 2),
        urlFotoFronte: 'a',
        urlFotoRetro: 'b',
        urlFotoDx: 'c',
        urlFotoSx: 'd',
        luciOk: false,
        gommeOk: true,
        interniOk: false,
        noteDanni: 'x',
        urlFirma: 'y',
      );

      final json = c.toJson();
      expect(json['id_prenotazione'], 11);
      expect(json['targa'], 'BB222BB');
      expect(json['driver_id'], '8');
      expect(json['url_foto_fronte'], 'a');
      expect(json['luci_ok'], false);
      expect(json['interni_ok'], false);
      expect(json['note_danni'], 'x');
      expect(json['url_firma'], 'y');
      expect(json.containsKey('data_check'), false);
    });
  });
}
