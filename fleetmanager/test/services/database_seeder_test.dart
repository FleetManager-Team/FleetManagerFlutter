import 'package:flutter_test/flutter_test.dart';
import 'package:gotrue/gotrue.dart';

import 'package:FleetManager/services/database_seeder.dart';

import '_service_test_helpers.dart';

void main() {
  late MockSupabaseClient mockSupabase;
  late MockSupabaseQueryBuilder qbVeicoli;
  late MockSupabaseQueryBuilder qbManutenzioni;
  late MockSupabaseQueryBuilder qbScadenze;
  late MockSupabaseQueryBuilder qbUtenti;
  late MockGoTrueClient mockAuth;

  setUp(() {
    mockSupabase = MockSupabaseClient();
    qbVeicoli = MockSupabaseQueryBuilder();
    qbManutenzioni = MockSupabaseQueryBuilder();
    qbScadenze = MockSupabaseQueryBuilder();
    qbUtenti = MockSupabaseQueryBuilder();
    mockAuth = MockGoTrueClient();

    when(() => mockSupabase.auth).thenReturn(mockAuth);

    when(() => mockSupabase.from('veicoli'))
        .thenAnswer((_) => qbVeicoli);
    when(() => mockSupabase.from('manutenzioni'))
        .thenAnswer((_) => qbManutenzioni);
    when(() => mockSupabase.from('scadenze'))
        .thenAnswer((_) => qbScadenze);
    when(() => mockSupabase.from('utenti'))
        .thenAnswer((_) => qbUtenti);

    when(() => qbVeicoli.insert(any()))
        .thenAnswer((_) => futureBuilder<void>(null));
    when(() => qbManutenzioni.insert(any()))
        .thenAnswer((_) => futureBuilder<void>(null));
    when(() => qbScadenze.insert(any()))
        .thenAnswer((_) => futureBuilder<void>(null));
    when(() => qbUtenti.insert(any()))
        .thenAnswer((_) => futureBuilder<void>(null));

    when(() => mockAuth.signUp(email: any(named: 'email'), password: any(named: 'password')))
        .thenAnswer((_) async => AuthResponse(user: User.fromJson({'id': '1', 'aud': 'x', 'created_at': 'now'})));
  });

  test('eseguiSeedCompleto esce se veicoli già presenti', () async {
    when(() => qbVeicoli.select(any()))
        .thenAnswer((_) => futureBuilder<List<dynamic>>([{'targa': 'X'}]));

    await DatabaseSeeder.eseguiSeedCompleto(supabaseClient: mockSupabase);

    verifyNever(() => qbVeicoli.insert(any()));
  });

  test('eseguiSeedCompleto inserisce dati se database vuoto', () async {
    when(() => qbVeicoli.select(any()))
        .thenAnswer((_) => futureBuilder<List<dynamic>>(<dynamic>[]));

    await DatabaseSeeder.eseguiSeedCompleto(supabaseClient: mockSupabase);

    verify(() => qbVeicoli.insert(any()));
    verify(() => qbManutenzioni.insert(any()));
    verify(() => qbScadenze.insert(any()));
    verify(() => qbUtenti.insert(any())).called(2);
    verify(() => mockAuth.signUp(email: any(named: 'email'), password: any(named: 'password')))
        .called(2);
  });
}
