import 'package:flutter_test/flutter_test.dart';

import 'package:fleetmanager/services/prenotazione_service.dart';
import 'package:fleetmanager/models/prenotazione.dart';
import 'package:fleetmanager/models/enums/stato_prenotazione.dart';
import 'package:fleetmanager/models/enums/tipo_prenotazione.dart';

import '_service_test_helpers.dart';

void main() {
  late MockSupabaseClient mockSupabase;
  late MockSupabaseQueryBuilder mockQueryBuilder;

  setUp(() {
    mockSupabase = MockSupabaseClient();
    mockQueryBuilder = MockSupabaseQueryBuilder();

    when(() => mockSupabase.from(any()))
        .thenAnswer((_) => mockQueryBuilder);
  });

  PrenotazioneService build() =>
      PrenotazioneService(supabaseClient: mockSupabase);

  test('fetchPrenotazioni ritorna lista', () async {
    final list = [
      {
        'id_prenotazione': 1,
        'data_inizio': DateTime.utc(2024, 1, 1).toIso8601String(),
        'data_fine': DateTime.utc(2024, 1, 2).toIso8601String(),
        'stato': 'confermata',
        'tipo': 'utente',
        'id_utente': 10,
        'targa': 'AA111AA',
      }
    ];

    when(() => mockQueryBuilder.select())
        .thenAnswer((_) => futureBuilder<List<dynamic>>(list));

    final service = build();
    final res = await service.fetchPrenotazioni();

    expect(res.length, 1);
    expect(res.first.idPrenotazione, 1);
  });

  test('fetchPrenotazioni lancia eccezione su errore', () async {
    when(() => mockQueryBuilder.select())
        .thenThrow(Exception('fail'));

    final service = build();
    await expectLater(service.fetchPrenotazioni(), throwsException);
  });

  test('creaPrenotazione rimuove id_prenotazione', () async {
    Map<String, dynamic>? captured;
    when(() => mockQueryBuilder.insert(any())).thenAnswer((invocation) {
      captured = invocation.positionalArguments.first as Map<String, dynamic>;
      return futureBuilder<void>(null);
    });

    final service = build();
    await service.creaPrenotazione(Prenotazione(
      idPrenotazione: 99,
      dataInizio: DateTime.utc(2024, 1, 1),
      dataFine: DateTime.utc(2024, 1, 2),
      statoPrenotazione: StatoPrenotazione.richiesta,
      tipoPrenotazione: TipoPrenotazione.utente,
      idUtente: 1,
      targa: 'AA111AA',
    ));

    expect(captured, isNotNull);
    expect(captured!.containsKey('id_prenotazione'), false);
  });

  test('annullaPrenotazione aggiorna stato', () async {
    when(() => mockQueryBuilder.update(any()))
        .thenAnswer((_) => futureBuilder<void>(null));

    final service = build();
    await service.annullaPrenotazione(1);

    verify(() => mockQueryBuilder.update({'stato': 'annullata'})).called(1);
  });

  test('completaPrenotazione aggiorna stato', () async {
    when(() => mockQueryBuilder.update(any()))
        .thenAnswer((_) => futureBuilder<void>(null));

    final service = build();
    await service.completaPrenotazione(2);

    verify(() => mockQueryBuilder.update({'stato': 'completata'})).called(1);
  });

  test('confermaPrenotazione aggiorna stato', () async {
    when(() => mockQueryBuilder.update(any()))
        .thenAnswer((_) => futureBuilder<void>(null));

    final service = build();
    await service.confermaPrenotazione(3);

    verify(() => mockQueryBuilder.update({'stato': 'confermata'})).called(1);
  });

  test('validaDisponibilita ritorna false su sovrapposizione', () async {
    final list = [
      {
        'id_prenotazione': 1,
        'data_inizio': DateTime.utc(2024, 1, 1, 10).toIso8601String(),
        'data_fine': DateTime.utc(2024, 1, 1, 12).toIso8601String(),
        'stato': 'confermata',
        'tipo': 'utente',
        'id_utente': 1,
        'targa': 'AA111AA',
      }
    ];
    when(() => mockQueryBuilder.select())
        .thenAnswer((_) => futureBuilder<List<dynamic>>(list));

    final service = build();
    final ok = await service.validaDisponibilita(
      'AA111AA',
      DateTime.utc(2024, 1, 1, 11),
      DateTime.utc(2024, 1, 1, 13),
    );

    expect(ok, false);
  });

  test('validaDisponibilita ritorna true se nessuna sovrapposizione', () async {
    final list = [
      {
        'id_prenotazione': 1,
        'data_inizio': DateTime.utc(2024, 1, 1, 8).toIso8601String(),
        'data_fine': DateTime.utc(2024, 1, 1, 9).toIso8601String(),
        'stato': 'confermata',
        'tipo': 'utente',
        'id_utente': 1,
        'targa': 'AA111AA',
      }
    ];
    when(() => mockQueryBuilder.select())
        .thenAnswer((_) => futureBuilder<List<dynamic>>(list));

    final service = build();
    final ok = await service.validaDisponibilita(
      'AA111AA',
      DateTime.utc(2024, 1, 1, 10),
      DateTime.utc(2024, 1, 1, 11),
    );

    expect(ok, true);
  });

  test('validaDisponibilita lancia eccezione su errore', () async {
    when(() => mockQueryBuilder.select())
        .thenThrow(Exception('fail'));

    final service = build();
    await expectLater(
        service.validaDisponibilita('AA', DateTime.now(), DateTime.now()),
        throwsException);
  });
}
