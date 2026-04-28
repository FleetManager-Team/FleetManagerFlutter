import 'package:flutter_test/flutter_test.dart';
import 'package:fleetmanager/models/prenotazione.dart';
import 'package:fleetmanager/models/enums/stato_prenotazione.dart';
import 'package:fleetmanager/models/enums/tipo_prenotazione.dart';

void main() {
  group('Prenotazione model', () {
    test('fromJson mappa correttamente stato e tipo', () {
      final json = {
        'id_prenotazione': 1,
        'data_inizio': DateTime.utc(2024, 1, 1).toIso8601String(),
        'data_fine': DateTime.utc(2024, 1, 2).toIso8601String(),
        'stato': 'attesa_checkup',
        'tipo': 'UTENTE',
        'id_utente': 10,
        'targa': 'AA111AA',
      };

      final p = Prenotazione.fromJson(json);

      expect(p.idPrenotazione, 1);
      expect(p.statoPrenotazione, StatoPrenotazione.attesaCheckup);
      expect(p.tipoPrenotazione, TipoPrenotazione.utente);
      expect(p.idUtente, 10);
      expect(p.targa, 'AA111AA');
    });

    test('toJson mappa correttamente', () {
      final p = Prenotazione(
        idPrenotazione: 2,
        dataInizio: DateTime.utc(2024, 2, 1),
        dataFine: DateTime.utc(2024, 2, 2),
        statoPrenotazione: StatoPrenotazione.confermata,
        tipoPrenotazione: TipoPrenotazione.aziendale,
        idUtente: 20,
        targa: 'BB222BB',
      );

      final json = p.toJson();
      expect(json['id_prenotazione'], 2);
      expect(json['stato'], 'confermata');
      expect(json['tipo'], 'aziendale');
      expect(json['id_utente'], 20);
      expect(json['targa'], 'BB222BB');
    });
  });
}
