import 'package:flutter_test/flutter_test.dart';

import 'package:fleetmanager/services/manutenzione_service.dart';
import 'package:fleetmanager/models/manutenzione.dart';
import 'package:fleetmanager/models/enums/tipo_manutenzione.dart';

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

  ManutenzioneService build() =>
      ManutenzioneService(supabaseClient: mockSupabase);

  test('registraIntervento rimuove id e inserisce', () async {
    Map<String, dynamic>? captured;
    when(() => mockQueryBuilder.insert(any())).thenAnswer((invocation) {
      captured = invocation.positionalArguments.first as Map<String, dynamic>;
      return futureBuilder<void>(null);
    });

    final service = build();
    await service.registraIntervento(Manutenzione(
      idManutenzione: 99,
      data: DateTime(2024, 1, 1),
      tipoManutenzione: TipoManutenzione.ordinaria,
      descrizione: 'Test',
      targa: 'AA111AA',
      luogo: 'Officina',
    ));

    expect(captured, isNotNull);
    expect(captured!.containsKey('id_manutenzione'), false);
  });

  test('chiudiIntervento aggiorna manutenzioni e veicoli', () async {
    when(() => mockQueryBuilder.update(any()))
        .thenAnswer((_) => futureBuilder<void>(null));

    final service = build();
    await service.chiudiIntervento(1, 5000, 'AA111AA');

    verify(() => mockQueryBuilder.update(any())).called(greaterThan(1));
  });

  test('fetchTutte ritorna lista', () async {
    final list = [
      {
        'id_manutenzione': 1,
        'data': DateTime(2024, 1, 1).toIso8601String(),
        'ora_fine': null,
        'tipo': 'ordinaria',
        'descrizione': 'Test',
        'targa': 'AA111AA',
        'luogo': 'Officina',
      }
    ];
    when(() => mockQueryBuilder.select())
        .thenAnswer((_) => futureBuilder<List<dynamic>>(list));

    final service = build();
    final res = await service.fetchTutte();

    expect(res.length, 1);
    expect(res.first.idManutenzione, 1);
  });

  test('fetchTutte lancia eccezione su errore', () async {
    when(() => mockQueryBuilder.select())
        .thenThrow(Exception('fail'));

    final service = build();
    await expectLater(service.fetchTutte(), throwsException);
  });

  test('segnalareInterventoStraordinario inserisce e aggiorna', () async {
    when(() => mockQueryBuilder.insert(any()))
        .thenAnswer((_) => futureBuilder<void>(null));
    when(() => mockQueryBuilder.update(any()))
        .thenAnswer((_) => futureBuilder<void>(null));

    final service = build();
    await service.segnalareInterventoStraordinario('AA111AA', 'Guasto');

    verify(() => mockQueryBuilder.insert(any())).called(1);
    verify(() => mockQueryBuilder.update(any())).called(1);
  });

  test('updateManutenzione aggiorna dati', () async {
    when(() => mockQueryBuilder.update(any()))
        .thenAnswer((_) => futureBuilder<void>(null));

    final service = build();
    await service.updateManutenzione(1, {'descrizione': 'X'});

    verify(() => mockQueryBuilder.update({'descrizione': 'X'})).called(1);
  });

  test('updateManutenzione lancia eccezione su errore', () async {
    when(() => mockQueryBuilder.update(any()))
        .thenThrow(Exception('fail'));

    final service = build();
    await expectLater(service.updateManutenzione(1, {'a': 1}), throwsException);
  });
}
