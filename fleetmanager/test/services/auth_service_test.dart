import 'package:flutter_test/flutter_test.dart';
import 'package:gotrue/gotrue.dart';
import 'package:postgrest/postgrest.dart';

import 'package:fleetmanager/models/utente.dart';
import 'package:fleetmanager/services/auth_service.dart';
import 'package:fleetmanager/models/enums/ruolo_utente.dart';

import '_service_test_helpers.dart';

void main() {
  late MockSupabaseClient mockSupabase;
  late MockGoTrueClient mockAuth;
  late MockSupabaseQueryBuilder mockQueryBuilder;

  setUpAll(() {
    registerFallbackValue(const FetchOptions());
  });

  setUp(() {
    mockSupabase = MockSupabaseClient();
    mockAuth = MockGoTrueClient();
    mockQueryBuilder = MockSupabaseQueryBuilder();

    when(() => mockSupabase.auth).thenReturn(mockAuth);
    when(() => mockSupabase.from(any()))
        .thenAnswer((_) => mockQueryBuilder);
  });

  AuthService build() => AuthService(supabaseClient: mockSupabase);

  test('login ritorna Utente se auth OK e record trovato', () async {
    when(() => mockAuth.signInWithPassword(email: any(named: 'email'), password: any(named: 'password')))
        .thenAnswer((_) async => AuthResponse(user: User.fromJson({'id': '1', 'aud': 'x', 'created_at': 'now'})));

    final json = {
      'id_utente': 1,
      'nome': 'Mario',
      'cognome': 'Rossi',
      'email': 'm@test.it',
      'ruolo': 'driver',
      'patente': 'B',
    };

    when(() => mockQueryBuilder.select())
        .thenAnswer((_) => futureBuilder<Map<String, dynamic>?>(json));

    final service = build();
    final user = await service.login('m@test.it', 'pwd');

    expect(user, isNotNull);
    expect(user!.ruoloUtente, RuoloUtente.driver);
  });

  test('login ritorna null se auth non ha user', () async {
    when(() => mockAuth.signInWithPassword(email: any(named: 'email'), password: any(named: 'password')))
        .thenAnswer((_) async => AuthResponse());

    final service = build();
    final user = await service.login('x@y.it', 'pwd');

    expect(user, isNull);
  });

  test('login ritorna null su eccezione', () async {
    when(() => mockAuth.signInWithPassword(email: any(named: 'email'), password: any(named: 'password')))
        .thenThrow(Exception('fail'));

    final service = build();
    final user = await service.login('x@y.it', 'pwd');

    expect(user, isNull);
  });

  test('getTuttiUtenti ritorna lista', () async {
    final list = [
      {
        'id_utente': 1,
        'nome': 'A',
        'cognome': 'B',
        'email': 'a@b.it',
        'ruolo': 'driver',
      }
    ];
    when(() => mockQueryBuilder.select())
        .thenAnswer((_) => futureBuilder<List<dynamic>>(list));

    final service = build();
    final res = await service.getTuttiUtenti();

    expect(res.length, 1);
    expect(res.first.idUtente, 1);
  });

  test('getUtenteByEmail ritorna null se record nullo', () async {
    when(() => mockQueryBuilder.select())
        .thenAnswer((_) => futureBuilder<Map<String, dynamic>?>(null));

    final service = build();
    final res = await service.getUtenteByEmail('x@y.it');

    expect(res, isNull);
  });

  test('updateProfilo ritorna true su successo', () async {
    when(() => mockQueryBuilder.update(any()))
        .thenAnswer((_) => futureBuilder<void>(null));

    final service = build();
    final ok = await service.updateProfilo(Utente(
      idUtente: 1,
      nome: 'A',
      cognome: 'B',
      email: 'a@b.it',
      ruoloUtente: RuoloUtente.driver,
    ));

    expect(ok, true);
  });

  test('updateProfilo ritorna false su errore', () async {
    when(() => mockQueryBuilder.update(any()))
        .thenThrow(Exception('fail'));

    final service = build();
    final ok = await service.updateProfilo(Utente(
      idUtente: 1,
      nome: 'A',
      cognome: 'B',
      email: 'a@b.it',
      ruoloUtente: RuoloUtente.driver,
    ));

    expect(ok, false);
  });

  test('createUtente ritorna true su successo', () async {
    when(() => mockQueryBuilder.insert(any()))
        .thenAnswer((_) => futureBuilder<void>(null));

    final service = build();
    final ok = await service.createUtente(Utente(
      idUtente: 1,
      nome: 'A',
      cognome: 'B',
      email: 'a@b.it',
      ruoloUtente: RuoloUtente.driver,
    ));

    expect(ok, true);
  });

  test('createUtente ritorna false su PostgrestException', () async {
    when(() => mockQueryBuilder.insert(any()))
        .thenThrow(PostgrestException(message: 'err'));

    final service = build();
    final ok = await service.createUtente(Utente(
      idUtente: 1,
      nome: 'A',
      cognome: 'B',
      email: 'a@b.it',
      ruoloUtente: RuoloUtente.driver,
    ));

    expect(ok, false);
  });

  test('eliminaUtente ritorna true su successo', () async {
    when(() => mockQueryBuilder.delete())
        .thenAnswer((_) => futureBuilder<void>(null));

    final service = build();
    final ok = await service.eliminaUtente(1);

    expect(ok, true);
  });

  test('eliminaUtente ritorna false su errore', () async {
    when(() => mockQueryBuilder.delete())
        .thenThrow(Exception('fail'));

    final service = build();
    final ok = await service.eliminaUtente(1);

    expect(ok, false);
  });
}
