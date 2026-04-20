import 'package:flutter_test/flutter_test.dart';
import 'package:FleetManager/models/manutenzione.dart';
import 'package:FleetManager/models/enums/tipo_manutenzione.dart';

void main() {
  group('Manutenzione model', () {
    test('fromJson mappa correttamente con oraFine null', () {
      final json = {
        'id_manutenzione': 1,
        'data': DateTime(2024, 3, 1).toIso8601String(),
        'ora_fine': null,
        'tipo': 'ordinaria',
        'descrizione': 'Tagliando',
        'targa': 'AA111AA',
        'luogo': 'Officina',
      };

      final m = Manutenzione.fromJson(json);

      expect(m.idManutenzione, 1);
      expect(m.oraFine, null);
      expect(m.tipoManutenzione, TipoManutenzione.ordinaria);
      expect(m.descrizione, 'Tagliando');
      expect(m.targa, 'AA111AA');
      expect(m.luogo, 'Officina');
    });

    test('toJson mappa correttamente', () {
      final m = Manutenzione(
        idManutenzione: 2,
        data: DateTime(2024, 3, 2),
        oraFine: DateTime(2024, 3, 2, 18, 30),
        tipoManutenzione: TipoManutenzione.straordinaria,
        descrizione: 'Riparazione',
        targa: 'BB222BB',
        luogo: 'Garage',
      );

      final json = m.toJson();
      expect(json['id_manutenzione'], 2);
      expect(json['tipo'], 'straordinaria');
      expect(json['descrizione'], 'Riparazione');
      expect(json['targa'], 'BB222BB');
      expect(json['luogo'], 'Garage');
      expect(json['ora_fine'], isA<String>());
    });
  });
}
