import 'package:flutter_test/flutter_test.dart';

import 'package:fleetmanager/services/notifica_service.dart';
import 'package:fleetmanager/models/enums/tipo_notifica.dart';

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

  NotificaService build() => NotificaService(supabaseClient: mockSupabase);

  test('fetchMieNotifiche ritorna lista', () async {
    final list = [
      {
        'id_notifica': 1,
        'tipo': 'info',
        'messaggio': 'Test',
        'data_invio': DateTime(2024, 1, 1).toIso8601String(),
        'letta': false,
        'id_utente': 10,
      }
    ];
    when(() => mockQueryBuilder.select())
        .thenAnswer((_) => futureBuilder<List<dynamic>>(list));

    final service = build();
    final res = await service.fetchMieNotifiche(10);

    expect(res.length, 1);
    expect(res.first.idNotifica, 1);
  });

  test('segnaLetta aggiorna flag', () async {
    when(() => mockQueryBuilder.update(any()))
        .thenAnswer((_) => futureBuilder<void>(null));

    final service = build();
    await service.segnaLetta(1);

    verify(() => mockQueryBuilder.update({'letta': true})).called(1);
  });

  test('inviaNotificaScadenza inserisce notifica', () async {
    Map<String, dynamic>? captured;
    when(() => mockQueryBuilder.insert(any())).thenAnswer((invocation) {
      captured = invocation.positionalArguments.first as Map<String, dynamic>;
      return futureBuilder<void>(null);
    });

    final service = build();
    await service.inviaNotificaScadenza(
      5,
      7,
      'AA111AA',
      'bollo',
      DateTime(2024, 1, 1),
    );

    expect(captured, isNotNull);
    expect(captured!['id_utente'], 5);
    expect(captured!['tipo'], TipoNotifica.scadenza.name);
    expect(captured!['id_scadenza'], 7);
    expect((captured!['messaggio'] as String).contains('AA111AA'), true);
  });

  test('notificaRichiestaPrenotazione inserisce notifica', () async {
    Map<String, dynamic>? captured;
    when(() => mockQueryBuilder.insert(any())).thenAnswer((invocation) {
      captured = invocation.positionalArguments.first as Map<String, dynamic>;
      return futureBuilder<void>(null);
    });

    final service = build();
    await service.notificaRichiestaPrenotazione(
      1,
      'Mario Rossi',
      'AA111AA',
      DateTime(2024, 1, 1),
      DateTime(2024, 1, 2),
    );

    expect(captured, isNotNull);
    expect(captured!['id_utente'], 1);
    expect(captured!['tipo'], TipoNotifica.info.name);
  });

  test('eliminaNotifica chiama delete', () async {
    when(() => mockQueryBuilder.delete())
        .thenAnswer((_) => futureBuilder<void>(null));

    final service = build();
    await service.eliminaNotifica(1);

    verify(() => mockQueryBuilder.delete()).called(1);
  });

  test('svuotaNotifiche chiama delete', () async {
    when(() => mockQueryBuilder.delete())
        .thenAnswer((_) => futureBuilder<void>(null));

    final service = build();
    await service.svuotaNotifiche(10);

    verify(() => mockQueryBuilder.delete()).called(1);
  });
}
