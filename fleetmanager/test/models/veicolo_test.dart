import 'package:flutter_test/flutter_test.dart';
import 'package:FleetManager/models/veicolo.dart';
import 'package:FleetManager/models/enums/tipo_veicolo.dart';
import 'package:FleetManager/models/enums/stato_veicolo.dart';

void main() {
  group('Veicolo model', () {
    test('fromJson mappa correttamente', () {
      final json = {
        'targa': 'AA111AA',
        'tipo': 'auto',
        'marca': 'Fiat',
        'modello': 'Panda',
        'anno_immatricolazione': 2020,
        'stato': 'disponibile',
        'km': 10000,
      };

      final v = Veicolo.fromJson(json);

      expect(v.targa, 'AA111AA');
      expect(v.tipoVeicolo, TipoVeicolo.auto);
      expect(v.marca, 'Fiat');
      expect(v.modello, 'Panda');
      expect(v.annoImmatricolazione, 2020);
      expect(v.statoVeicolo, StatoVeicolo.disponibile);
      expect(v.km, 10000);
    });

    test('toJson mappa correttamente', () {
      final v = Veicolo(
        targa: 'BB222BB',
        tipoVeicolo: TipoVeicolo.auto,
        marca: 'Ford',
        modello: 'Focus',
        annoImmatricolazione: 2021,
        statoVeicolo: StatoVeicolo.prenotato,
        km: 5000,
      );

      final json = v.toJson();
      expect(json['targa'], 'BB222BB');
      expect(json['tipo'], 'auto');
      expect(json['marca'], 'Ford');
      expect(json['modello'], 'Focus');
      expect(json['anno_immatricolazione'], 2021);
      expect(json['stato'], 'prenotato');
      expect(json['km'], 5000);
    });
  });
}
