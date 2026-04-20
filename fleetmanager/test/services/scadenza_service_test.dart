import 'package:flutter_test/flutter_test.dart';

import 'package:FleetManager/services/scadenza_service.dart';

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

  ScadenzaService build() => ScadenzaService(supabaseClient: mockSupabase);

  test('fetchTutteLeScadenze ritorna lista', () async {
    final list = [
      {
        'id_scadenza': 1,
        'tipo': 'bollo',
        'data': DateTime(2024, 1, 1).toIso8601String(),
        'notificata': false,
        'targa': 'AA111AA',
      }
    ];
    when(() => mockQueryBuilder.select())
        .thenAnswer((_) => futureBuilder<List<dynamic>>(list));

    final service = build();
    final res = await service.fetchTutteLeScadenze();

    expect(res.length, 1);
    expect(res.first.idScadenza, 1);
  });

  test('segnaNotificata aggiorna flag', () async {
    when(() => mockQueryBuilder.update(any()))
        .thenAnswer((_) => futureBuilder<void>(null));

    final service = build();
    await service.segnaNotificata(1);

    verify(() => mockQueryBuilder.update({'notificata': true})).called(1);
  });
}
