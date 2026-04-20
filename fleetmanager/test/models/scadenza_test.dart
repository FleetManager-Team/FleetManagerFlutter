import 'package:flutter_test/flutter_test.dart';
import 'package:FleetManager/models/scadenza.dart';
import 'package:FleetManager/models/enums/tipo_scadenza.dart';

void main() {
  group('Scadenza model', () {
    test('fromJson mappa correttamente', () {
      final json = {
        'id_scadenza': 1,
        'tipo': 'bollo',
        'data': DateTime(2024, 7, 1).toIso8601String(),
        'notificata': true,
        'targa': 'AA111AA',
      };

      final s = Scadenza.fromJson(json);

      expect(s.idScadenza, 1);
      expect(s.tipoScadenza, TipoScadenza.bollo);
      expect(s.notificata, true);
      expect(s.targa, 'AA111AA');
    });

    test('toJson mappa correttamente', () {
      final s = Scadenza(
        idScadenza: 2,
        tipoScadenza: TipoScadenza.assicurazione,
        data: DateTime(2024, 7, 2),
        notificata: false,
        targa: 'BB222BB',
      );

      final json = s.toJson();
      expect(json['id_scadenza'], 2);
      expect(json['tipo'], 'assicurazione');
      expect(json['notificata'], false);
      expect(json['targa'], 'BB222BB');
    });
  });
}
