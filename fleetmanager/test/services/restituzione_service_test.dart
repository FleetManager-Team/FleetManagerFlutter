import 'package:flutter_test/flutter_test.dart';
import 'package:postgrest/postgrest.dart';

import 'package:fleetmanager/services/restituzione_service.dart';

import '_service_test_helpers.dart';

void main() {
  late MockSupabaseClient mockSupabase;
  late MockSupabaseQueryBuilder qbRestituzioni;
  late MockSupabaseQueryBuilder qbVeicoli;
  late MockSupabaseQueryBuilder qbPrenotazioni;

  setUpAll(() {
    registerFallbackValue(const FetchOptions());
  });

  setUp(() {
    mockSupabase = MockSupabaseClient();
    qbRestituzioni = MockSupabaseQueryBuilder();
    qbVeicoli = MockSupabaseQueryBuilder();
    qbPrenotazioni = MockSupabaseQueryBuilder();

    when(() => mockSupabase.from('restituzioni'))
        .thenAnswer((_) => qbRestituzioni);
    when(() => mockSupabase.from('veicoli'))
        .thenAnswer((_) => qbVeicoli);
    when(() => mockSupabase.from('prenotazioni'))
        .thenAnswer((_) => qbPrenotazioni);

    when(() => qbRestituzioni.upsert(any(), onConflict: any(named: 'onConflict')))
        .thenAnswer((_) => futureBuilder<void>(null));
    when(() => qbVeicoli.update(any()))
        .thenAnswer((_) => futureBuilder<void>(null));
    when(() => qbVeicoli.update(any(), options: any(named: 'options')))
        .thenAnswer((_) => futureBuilder<void>(null));
    when(() => qbPrenotazioni.update(any()))
        .thenAnswer((_) => futureBuilder<void>(null));
    when(() => qbPrenotazioni.update(any(), options: any(named: 'options')))
        .thenAnswer((_) => futureBuilder<void>(null));
  });

  RestituzioneService build() =>
      RestituzioneService(supabaseClient: mockSupabase);

  test('completaRestituzione aggiorna km se non emergenza', () async {
    Map<String, dynamic>? veicoloUpdate;
    when(() => qbVeicoli.update(any())).thenAnswer((invocation) {
      veicoloUpdate = invocation.positionalArguments.first as Map<String, dynamic>;
      return futureBuilder<void>(null);
    });

    final service = build();
    await service.completaRestituzione(
      idPrenotazione: 1,
      targa: 'AA111AA',
      kmFinali: 1000,
      livelloCarburante: 0.5,
      rifornimento: false,
      haDanni: false,
      haPedaggi: false,
      isEmergenza: false,
    );

    expect(veicoloUpdate, isNotNull);
    expect(veicoloUpdate!.containsKey('km'), true);
    expect(veicoloUpdate!['stato'], 'disponibile');
  });

  test('completaRestituzione non aggiorna km se emergenza', () async {
    Map<String, dynamic>? veicoloUpdate;
    when(() => qbVeicoli.update(any())).thenAnswer((invocation) {
      veicoloUpdate = invocation.positionalArguments.first as Map<String, dynamic>;
      return futureBuilder<void>(null);
    });

    final service = build();
    await service.completaRestituzione(
      idPrenotazione: 2,
      targa: 'BB222BB',
      kmFinali: 2000,
      livelloCarburante: 0.3,
      rifornimento: false,
      haDanni: true,
      haPedaggi: false,
      isEmergenza: true,
    );

    expect(veicoloUpdate, isNotNull);
    expect(veicoloUpdate!.containsKey('km'), false);
    expect(veicoloUpdate!['stato'], 'fuoriServizio');
  });

  test('completaRestituzione rilancia eccezione su errore', () async {
    when(() => qbRestituzioni.upsert(any(), onConflict: any(named: 'onConflict')))
        .thenThrow(Exception('fail'));

    final service = build();
    await expectLater(
      service.completaRestituzione(
        idPrenotazione: 3,
        targa: 'CC333CC',
        kmFinali: 100,
        livelloCarburante: 0.2,
        rifornimento: false,
        haDanni: false,
        haPedaggi: false,
      ),
      throwsException,
    );
  });
}
