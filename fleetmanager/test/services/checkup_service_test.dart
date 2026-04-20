import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:gotrue/gotrue.dart';

import 'package:fleetmanager/services/checkup_iniziale_service.dart';

import '_service_test_helpers.dart';

void main() {
  late MockSupabaseClient mockSupabase;
  late MockSupabaseQueryBuilder mockQueryBuilder;
  late MockGoTrueClient mockAuth;

  setUp(() {
    mockSupabase = MockSupabaseClient();
    mockQueryBuilder = MockSupabaseQueryBuilder();
    mockAuth = MockGoTrueClient();

    when(() => mockSupabase.auth).thenReturn(mockAuth);
    when(() => mockSupabase.from(any()))
        .thenAnswer((_) => mockQueryBuilder);
  });

  CheckupService build() => CheckupService(supabaseClient: mockSupabase);

  test('inviaCheckupCompleto lancia se utente non autenticato', () async {
    when(() => mockAuth.currentUser).thenReturn(null);

    final service = build();
    await expectLater(
      service.inviaCheckupCompleto(
        idPrenotazione: 1,
        targa: 'AA111AA',
        fotoPerimetrali: [null, null, null, null],
        luci: true,
        gomme: true,
        interni: true,
        firmaBytes: null,
      ),
      throwsException,
    );
  });

  test('inviaCheckupCompleto invia dati e upsert', () async {
    when(() => mockAuth.currentUser)
        .thenReturn(User.fromJson({'id': '1', 'aud': 'x', 'created_at': 'now'}));

    Map<String, dynamic>? captured;
    when(() => mockQueryBuilder.upsert(any(), onConflict: any(named: 'onConflict')))
        .thenAnswer((invocation) {
      captured = invocation.positionalArguments.first as Map<String, dynamic>;
      return futureBuilder<void>(null);
    });

    final service = build();
    await service.inviaCheckupCompleto(
      idPrenotazione: 2,
      targa: 'BB222BB',
      fotoPerimetrali: [null, null, null, null],
      luci: false,
      gomme: true,
      interni: false,
      note: 'ok',
      firmaBytes: Uint8List(0),
    );

    expect(captured, isNotNull);
    expect(captured!['targa'], 'BB222BB');
    expect(captured!['luci_ok'], false);
    expect(captured!['interni_ok'], false);
  });

  test('getStoricoCheckup ritorna lista', () async {
    final list = [
      {'id_prenotazione': 1, 'targa': 'AA111AA'}
    ];
    when(() => mockQueryBuilder.select(any()))
        .thenAnswer((_) => futureBuilder<List<Map<String, dynamic>>>(list));

    final service = build();
    final res = await service.getStoricoCheckup();

    expect(res.length, 1);
  });

  test('getStoricoCheckup filtra per targa', () async {
    final list = [
      {'id_prenotazione': 1, 'targa': 'AA111AA'}
    ];
    when(() => mockQueryBuilder.select(any()))
        .thenAnswer((_) => futureBuilder<List<Map<String, dynamic>>>(list));

    final service = build();
    final res = await service.getStoricoCheckup(targa: 'AA111AA');

    expect(res.length, 1);
  });
}
