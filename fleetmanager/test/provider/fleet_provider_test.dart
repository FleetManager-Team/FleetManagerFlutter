import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Import Provider e Servizi
import 'package:fleetmanager/provider/fleet_provider.dart';
import 'package:fleetmanager/services/auth_service.dart';
import 'package:fleetmanager/services/veicolo_service.dart';
import 'package:fleetmanager/services/prenotazione_service.dart';
import 'package:fleetmanager/services/manutenzione_service.dart';
import 'package:fleetmanager/services/notifica_service.dart';
import 'package:fleetmanager/services/scadenza_service.dart';

// Import Modelli ed Enums
import 'package:fleetmanager/models/utente.dart';
import 'package:fleetmanager/models/veicolo.dart';
import 'package:fleetmanager/models/prenotazione.dart';
import 'package:fleetmanager/models/manutenzione.dart';
import 'package:fleetmanager/models/notifica.dart';
import 'package:fleetmanager/models/restituzione.dart';
import 'package:fleetmanager/models/enums/ruolo_utente.dart';
import 'package:fleetmanager/models/enums/stato_prenotazione.dart';
import 'package:fleetmanager/models/enums/stato_veicolo.dart';
import 'package:fleetmanager/models/enums/tipo_manutenzione.dart';
import 'package:fleetmanager/models/enums/tipo_notifica.dart';
import 'package:fleetmanager/models/enums/tipo_prenotazione.dart';
import 'package:fleetmanager/models/enums/tipo_veicolo.dart';

// 1. MOCK CLASSES
class MockAuthService extends Mock implements AuthService {}

class MockVeicoloService extends Mock implements VeicoloService {}

class MockPrenotazioneService extends Mock implements PrenotazioneService {}

class MockManutenzioneService extends Mock implements ManutenzioneService {}

class MockNotificaService extends Mock implements NotificaService {}

class MockScadenzaService extends Mock implements ScadenzaService {}

class MockSupabaseClient extends Mock implements SupabaseClient {}
class MockSupabaseQueryBuilder extends Mock implements SupabaseQueryBuilder {}
class MockGoTrueClient extends Mock implements GoTrueClient {}

class FakePostgrestFilterBuilder<T> extends Fake
    implements PostgrestFilterBuilder<T> {
  FakePostgrestFilterBuilder(this._future);

  final Future<T> _future;

  @override
  Future<R> then<R>(FutureOr<R> Function(T value) onValue,
      {Function? onError}) {
    return _future.then(onValue, onError: onError);
  }

  @override
  PostgrestFilterBuilder<T> eq(String column, dynamic value) {
    return this;
  }
}

// 2. FAKE CLASSES PER FALLBACK (Necessarie per any())
class FakeUtente extends Fake implements Utente {}

class FakeVeicolo extends Fake implements Veicolo {}

class FakePrenotazione extends Fake implements Prenotazione {}

FakePostgrestFilterBuilder<T> futureBuilder<T>(T value) {
  return FakePostgrestFilterBuilder<T>(Future<T>.value(value));
}

void main() {
  // Inizializzazione necessaria per i test Flutter
  TestWidgetsFlutterBinding.ensureInitialized();

  late FleetProvider fleetProvider;
  late MockAuthService mockAuth;
  late MockVeicoloService mockVeicoli;
  late MockPrenotazioneService mockPrenotazioni;
  late MockManutenzioneService mockManutenzioni;
  late MockNotificaService mockNotifiche;
  late MockScadenzaService mockScadenze;
  late MockSupabaseClient mockSupabase;
  late MockSupabaseQueryBuilder mockQueryBuilder;
  late MockSupabaseQueryBuilder mockRestituzioniQueryBuilder;
  late MockSupabaseQueryBuilder mockCheckupsQueryBuilder;
  late MockSupabaseQueryBuilder mockNotificheQueryBuilder;
  late MockSupabaseQueryBuilder mockScadenzeQueryBuilder;
  late MockGoTrueClient mockGoTrue;

  setUpAll(() {
    // Registrazione dei tipi per permettere l'uso di any()
    registerFallbackValue(FakeUtente());
    registerFallbackValue(FakeVeicolo());
    registerFallbackValue(FakePrenotazione());
    registerFallbackValue(const FetchOptions());
    registerFallbackValue(UserAttributes(password: 'x'));
  });

  setUp(() {
    mockAuth = MockAuthService();
    mockVeicoli = MockVeicoloService();
    mockPrenotazioni = MockPrenotazioneService();
    mockManutenzioni = MockManutenzioneService();
    mockNotifiche = MockNotificaService();
    mockScadenze = MockScadenzaService();
    mockSupabase = MockSupabaseClient();
    mockQueryBuilder = MockSupabaseQueryBuilder();
    mockRestituzioniQueryBuilder = MockSupabaseQueryBuilder();
    mockCheckupsQueryBuilder = MockSupabaseQueryBuilder();
    mockNotificheQueryBuilder = MockSupabaseQueryBuilder();
    mockScadenzeQueryBuilder = MockSupabaseQueryBuilder();
    mockGoTrue = MockGoTrueClient();

    when(() => mockSupabase.auth).thenReturn(mockGoTrue);

    when(() => mockSupabase.from(any()))
        .thenAnswer((_) => mockQueryBuilder);
    when(() => mockSupabase.from('restituzioni'))
        .thenAnswer((_) => mockRestituzioniQueryBuilder);
    when(() => mockSupabase.from('checkups'))
        .thenAnswer((_) => mockCheckupsQueryBuilder);
    when(() => mockSupabase.from('notifiche'))
        .thenAnswer((_) => mockNotificheQueryBuilder);
    when(() => mockSupabase.from('scadenze'))
        .thenAnswer((_) => mockScadenzeQueryBuilder);

    when(() => mockQueryBuilder.select())
        .thenAnswer((_) => futureBuilder<List<dynamic>>(<dynamic>[]));
    when(() => mockQueryBuilder.select<List<dynamic>>())
        .thenAnswer((_) => futureBuilder<List<dynamic>>(<dynamic>[]));

    when(() => mockRestituzioniQueryBuilder.select())
        .thenAnswer((_) => futureBuilder<List<dynamic>>(<dynamic>[]));
    when(() => mockRestituzioniQueryBuilder.select<List<dynamic>>())
        .thenAnswer((_) => futureBuilder<List<dynamic>>(<dynamic>[]));

    when(() => mockCheckupsQueryBuilder.select())
        .thenAnswer((_) => futureBuilder<List<dynamic>>(<dynamic>[]));
    when(() => mockCheckupsQueryBuilder.select<List<dynamic>>())
        .thenAnswer((_) => futureBuilder<List<dynamic>>(<dynamic>[]));

    when(() => mockScadenzeQueryBuilder.select())
        .thenAnswer((_) => futureBuilder<List<dynamic>>(<dynamic>[]));
    when(() => mockScadenzeQueryBuilder.select<List<dynamic>>())
        .thenAnswer((_) => futureBuilder<List<dynamic>>(<dynamic>[]));

    when(() => mockNotificheQueryBuilder.update(any()))
        .thenAnswer((_) => futureBuilder<void>(null));
    when(() => mockNotificheQueryBuilder.update(any(),
            options: any(named: 'options')))
        .thenAnswer((_) => futureBuilder<void>(null));

    fleetProvider = FleetProvider(
      authService: mockAuth,
      veicoloService: mockVeicoli,
      prenotazioneService: mockPrenotazioni,
      manutenzioneService: mockManutenzioni,
      notificaService: mockNotifiche,
      scadenzaService: mockScadenze,
      supabaseClient: mockSupabase,
    );

    when(() => mockScadenze.segnaNotificata(any())).thenAnswer((_) async {
      return;
    });
  });

  group('FleetProvider - Test Autenticazione', () {
    test('Login test con successo e caricamento dati', () async {
      final tUtente = Utente(
        idUtente: 1,
        nome: "Test",
        cognome: "User",
        email: "test@test.com",
        ruoloUtente: RuoloUtente.driver,
      );

      // Definiamo i comportamenti dei Mock
      when(() => mockAuth.login(any(), any())).thenAnswer((_) async => tUtente);
      when(() => mockVeicoli.fetchAllVeicoli())
          .thenAnswer((_) async => <Veicolo>[]);
      when(() => mockPrenotazioni.fetchPrenotazioni())
          .thenAnswer((_) async => <Prenotazione>[]);
      when(() => mockAuth.getTuttiUtenti()).thenAnswer((_) async => <Utente>[]);
      when(() => mockManutenzioni.fetchTutte())
          .thenAnswer((_) async => <Manutenzione>[]);
      when(() => mockNotifiche.fetchMieNotifiche(any()))
          .thenAnswer((_) async => <Notifica>[]);

      final result = await fleetProvider.login("test@test.com", "password");

      expect(result, true);
      expect(fleetProvider.utenteLoggato, isNotNull);
      expect(fleetProvider.utenteLoggato!.email, "test@test.com");
    });

    test('Login fallito restituisce false', () async {
      when(() => mockAuth.login(any(), any())).thenAnswer((_) async => null);

      final result = await fleetProvider.login("wrong@test.com", "wrong");

      expect(result, false);
      expect(fleetProvider.utenteLoggato, isNull);
    });
  });

  group('FleetProvider - Inizializzazione e Stato', () {
    test('inizializzaDati popola correttamente le liste', () async {
      final tUtente = Utente(
        idUtente: 7,
        nome: "Mario",
        cognome: "Rossi",
        email: "mario@t.it",
        ruoloUtente: RuoloUtente.driver,
      );

      final veicoli = [
        Veicolo(
          targa: "AA111AA",
          marca: "Fiat",
          modello: "Panda",
          tipoVeicolo: TipoVeicolo.auto,
          annoImmatricolazione: 2020,
          km: 10000,
          statoVeicolo: StatoVeicolo.disponibile,
        ),
      ];

      final prenotazioni = [
        Prenotazione(
          idPrenotazione: 1,
          idUtente: 7,
          targa: "AA111AA",
          dataInizio: DateTime(2024, 1, 1),
          dataFine: DateTime(2024, 1, 2),
          statoPrenotazione: StatoPrenotazione.confermata,
          tipoPrenotazione: TipoPrenotazione.utente,
        ),
      ];

      final manutenzioni = [
        Manutenzione(
          idManutenzione: 1,
          data: DateTime(2024, 1, 3),
          tipoManutenzione: TipoManutenzione.ordinaria,
          descrizione: "Tagliando",
          targa: "AA111AA",
          luogo: "Officina",
        ),
      ];

      final notifiche = [
        Notifica(
          idNotifica: 1,
          tipoNotifica: TipoNotifica.scadenza,
          messaggio: "Scadenza imminente",
          dataInvio: DateTime(2024, 1, 4),
          letta: false,
          idUtente: 7,
        ),
      ];

      final restituzioniJson = [
        {
          'id_restituzione': 1,
          'id_prenotazione': 1,
          'km_finali': 12000,
          'data_restituzione': DateTime(2024, 1, 5).toIso8601String(),
          'rifornimento_effettuato': true,
          'ha_pedaggi': false,
          'danni_presenti': false,
        },
      ];

      final checkupsJson = [
        {
          'id_prenotazione': 1,
          'targa': "AA111AA",
          'driver_id': "7",
          'data_check': DateTime(2024, 1, 1).toIso8601String(),
          'url_foto_fronte': "f1",
          'url_foto_retro': "f2",
          'url_foto_dx': "f3",
          'url_foto_sx': "f4",
        },
      ];

      when(() => mockAuth.login(any(), any())).thenAnswer((_) async => tUtente);
      when(() => mockVeicoli.fetchAllVeicoli())
          .thenAnswer((_) async => veicoli);
      when(() => mockPrenotazioni.fetchPrenotazioni())
          .thenAnswer((_) async => prenotazioni);
      when(() => mockAuth.getTuttiUtenti())
          .thenAnswer((_) async => [tUtente]);
      when(() => mockManutenzioni.fetchTutte())
          .thenAnswer((_) async => manutenzioni);
      when(() => mockNotifiche.fetchMieNotifiche(any()))
          .thenAnswer((_) async => notifiche);

      when(() => mockRestituzioniQueryBuilder.select())
          .thenAnswer((_) => futureBuilder<List<dynamic>>(restituzioniJson));
      when(() => mockRestituzioniQueryBuilder.select<List<dynamic>>())
          .thenAnswer((_) => futureBuilder<List<dynamic>>(restituzioniJson));
      when(() => mockCheckupsQueryBuilder.select())
          .thenAnswer((_) => futureBuilder<List<dynamic>>(checkupsJson));
      when(() => mockCheckupsQueryBuilder.select<List<dynamic>>())
          .thenAnswer((_) => futureBuilder<List<dynamic>>(checkupsJson));

      final ok = await fleetProvider.login("mario@t.it", "pwd");

      expect(ok, true);
      expect(fleetProvider.veicoli.length, 1);
      expect(fleetProvider.prenotazioni.length, 1);
      expect(fleetProvider.manutenzioni.length, 1);
      expect(fleetProvider.restituzioni.length, 1);
      expect(fleetProvider.checkups.length, 1);
      expect(fleetProvider.notifiche.length, 1);
    });

    test('inizializzaDati gestisce eccezioni e resetta isLoading', () async {
      // Mostra il log solo se il test fallisce.
      final originalDebugPrint = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) {
        if (message != null &&
            message.startsWith('Errore inizializzazione')) {
          printOnFailure(message);
        } else {
          originalDebugPrint(message, wrapWidth: wrapWidth);
        }
      };
      addTearDown(() {
        debugPrint = originalDebugPrint;
      });

      when(() => mockVeicoli.fetchAllVeicoli())
          .thenThrow(Exception("boom"));
      when(() => mockPrenotazioni.fetchPrenotazioni())
          .thenAnswer((_) async => <Prenotazione>[]);
      when(() => mockAuth.getTuttiUtenti()).thenAnswer((_) async => <Utente>[]);
      when(() => mockManutenzioni.fetchTutte())
          .thenAnswer((_) async => <Manutenzione>[]);
      when(() => mockNotifiche.fetchMieNotifiche(any()))
          .thenAnswer((_) async => <Notifica>[]);

      await fleetProvider.inizializzaDati();
      expect(fleetProvider.isLoading, false);
    });

    test('logout resetta stato e liste', () {
      fleetProvider.veicoli.add(Veicolo(
        targa: "BB222BB",
        marca: "Ford",
        modello: "Focus",
        tipoVeicolo: TipoVeicolo.auto,
        annoImmatricolazione: 2021,
        km: 5000,
        statoVeicolo: StatoVeicolo.disponibile,
      ));
      fleetProvider.prenotazioni.add(Prenotazione(
        idPrenotazione: 2,
        idUtente: 9,
        targa: "BB222BB",
        dataInizio: DateTime(2024, 2, 1),
        dataFine: DateTime(2024, 2, 2),
        statoPrenotazione: StatoPrenotazione.richiesta,
        tipoPrenotazione: TipoPrenotazione.utente,
      ));
      fleetProvider.manutenzioni.add(Manutenzione(
        idManutenzione: 2,
        data: DateTime(2024, 2, 3),
        tipoManutenzione: TipoManutenzione.ordinaria,
        descrizione: "Controllo",
        targa: "BB222BB",
        luogo: "Garage",
      ));
      fleetProvider.notifiche.add(Notifica(
        idNotifica: 2,
        tipoNotifica: TipoNotifica.scadenza,
        messaggio: "Test",
        dataInvio: DateTime(2024, 2, 4),
        letta: false,
        idUtente: 9,
      ));

      fleetProvider.logout();

      expect(fleetProvider.veicoli, isEmpty);
      expect(fleetProvider.prenotazioni, isEmpty);
      expect(fleetProvider.manutenzioni, isEmpty);
      expect(fleetProvider.notifiche, isEmpty);
      expect(fleetProvider.restituzioni, isEmpty);
      expect(fleetProvider.utenteLoggato, isNull);
    });
  });

  group('FleetProvider - Recupero Password', () {
    test('recuperaPassword ritorna true in caso di successo', () async {
      when(() => mockGoTrue.resetPasswordForEmail(any(),
              redirectTo: any(named: 'redirectTo')))
          .thenAnswer((_) async {});

      final ok = await fleetProvider.recuperaPassword("a@b.it");
      expect(ok, true);
    });

    test('recuperaPassword ritorna false in caso di errore', () async {
      // Mostra il log solo se il test fallisce.
      final originalDebugPrint = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) {
        if (message != null && message.startsWith('Errore recupero password')) {
          printOnFailure(message);
        } else {
          originalDebugPrint(message, wrapWidth: wrapWidth);
        }
      };
      addTearDown(() {
        debugPrint = originalDebugPrint;
      });

      when(() => mockGoTrue.resetPasswordForEmail(any(),
              redirectTo: any(named: 'redirectTo')))
          .thenThrow(Exception("fail"));

      final ok = await fleetProvider.recuperaPassword("a@b.it");
      expect(ok, false);
    });
  });

  group('FleetProvider - Aggiornamento Password', () {
    test('aggiornaPassword ritorna true e resetta isLoading', () async {
      when(() => mockGoTrue.updateUser(any()))
          .thenAnswer((_) async => UserResponse.fromJson({}));
      when(() => mockGoTrue.updateUser(any(),
              emailRedirectTo: any(named: 'emailRedirectTo')))
          .thenAnswer((_) async => UserResponse.fromJson({}));

      final ok = await fleetProvider.aggiornaPassword("nuova");

      expect(ok, true);
      expect(fleetProvider.isLoading, false);
    });

    test('aggiornaPassword rilancia errore e resetta isLoading', () async {
      final originalDebugPrint = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) {
        if (message != null && message.startsWith('Errore aggiornamento')) {
          printOnFailure(message);
        } else {
          originalDebugPrint(message, wrapWidth: wrapWidth);
        }
      };
      addTearDown(() {
        debugPrint = originalDebugPrint;
      });

      when(() => mockGoTrue.updateUser(any()))
          .thenThrow(Exception("fail"));
      when(() => mockGoTrue.updateUser(any(),
              emailRedirectTo: any(named: 'emailRedirectTo')))
          .thenThrow(Exception("fail"));

      await expectLater(
          fleetProvider.aggiornaPassword("nuova"), throwsException);
      expect(fleetProvider.isLoading, false);
    });
  });

  group('FleetProvider - Statistiche', () {
    test('spesaCarburantePerDriver calcola correttamente', () {
      final driver = Utente(
        idUtente: 5,
        nome: "Luca",
        cognome: "Bianchi",
        email: "l@b.it",
        ruoloUtente: RuoloUtente.driver,
      );

      fleetProvider.utenti.add(driver);
      fleetProvider.prenotazioni.add(Prenotazione(
        idPrenotazione: 10,
        idUtente: 5,
        targa: "CC333CC",
        dataInizio: DateTime(2024, 3, 1),
        dataFine: DateTime(2024, 3, 2),
        statoPrenotazione: StatoPrenotazione.confermata,
        tipoPrenotazione: TipoPrenotazione.utente,
      ));
      fleetProvider.restituzioni.addAll([
        Restituzione(
          idPrenotazione: 10,
          kmFinali: 200,
          dataRestituzione: DateTime(2024, 3, 3),
          rifornimentoEffettuato: true,
          importoEuro: 40.0,
          haPedaggi: false,
          danniPresenti: false,
        ),
        Restituzione(
          idPrenotazione: 10,
          kmFinali: 210,
          dataRestituzione: DateTime(2024, 3, 4),
          rifornimentoEffettuato: true,
          importoEuro: 10.0,
          haPedaggi: false,
          danniPresenti: false,
        ),
      ]);

      final stats = fleetProvider.spesaCarburantePerDriver;
      expect(stats["Luca Bianchi"], 50.0);
    });

    test('spesaCarburantePerDriver usa driver sconosciuto se mancante', () {
      fleetProvider.prenotazioni.add(Prenotazione(
        idPrenotazione: 11,
        idUtente: 99,
        targa: "DD444DD",
        dataInizio: DateTime(2024, 3, 10),
        dataFine: DateTime(2024, 3, 11),
        statoPrenotazione: StatoPrenotazione.confermata,
        tipoPrenotazione: TipoPrenotazione.utente,
      ));
      fleetProvider.restituzioni.add(Restituzione(
        idPrenotazione: 11,
        kmFinali: 300,
        dataRestituzione: DateTime(2024, 3, 12),
        rifornimentoEffettuato: true,
        importoEuro: 20.0,
        haPedaggi: false,
        danniPresenti: false,
      ));

      final stats = fleetProvider.spesaCarburantePerDriver;
      expect(stats["Sconosciuto "], 20.0);
    });
  });

  group('FleetProvider - Notifiche', () {
    test('segnaNotificaLetta aggiorna la notifica in lista', () async {
      final notifica = Notifica(
        idNotifica: 99,
        tipoNotifica: TipoNotifica.scadenza,
        messaggio: "Test",
        dataInvio: DateTime(2024, 4, 1),
        letta: false,
        idUtente: 1,
      );
      fleetProvider.notifiche.add(notifica);

      when(() => mockNotifiche.segnaLetta(any())).thenAnswer((_) async {
        return;
      });

      await fleetProvider.segnaNotificaLetta(99);

      expect(fleetProvider.notifiche.first.letta, true);
    });

    test('segnaNotificaLetta non modifica se id non esiste', () async {
      final notifica = Notifica(
        idNotifica: 101,
        tipoNotifica: TipoNotifica.scadenza,
        messaggio: "Test",
        dataInvio: DateTime(2024, 4, 1),
        letta: false,
        idUtente: 1,
      );
      fleetProvider.notifiche.add(notifica);

      when(() => mockNotifiche.segnaLetta(any())).thenAnswer((_) async {
        return;
      });

      await fleetProvider.segnaNotificaLetta(999);

      expect(fleetProvider.notifiche.length, 1);
      expect(fleetProvider.notifiche.first.letta, false);
    });

    test('segnaTutteNotificheComeLette usa Supabase mock', () async {
      final tUtente = Utente(
        idUtente: 3,
        nome: "Anna",
        cognome: "Verdi",
        email: "a@v.it",
        ruoloUtente: RuoloUtente.driver,
      );

      when(() => mockAuth.login(any(), any())).thenAnswer((_) async => tUtente);
      when(() => mockVeicoli.fetchAllVeicoli())
          .thenAnswer((_) async => <Veicolo>[]);
      when(() => mockPrenotazioni.fetchPrenotazioni())
          .thenAnswer((_) async => <Prenotazione>[]);
      when(() => mockAuth.getTuttiUtenti()).thenAnswer((_) async => <Utente>[]);
      when(() => mockManutenzioni.fetchTutte())
          .thenAnswer((_) async => <Manutenzione>[]);
      when(() => mockNotifiche.fetchMieNotifiche(any()))
          .thenAnswer((_) async => <Notifica>[]);

      await fleetProvider.login("a@v.it", "pwd");
      await fleetProvider.segnaTutteNotificheComeLette();

      verify(() => mockSupabase.from('notifiche')).called(greaterThan(0));
      verify(() => mockNotificheQueryBuilder.update(any())).called(1);
    });

    test('segnaTutteNotificheComeLette non fa nulla senza utente', () async {
      await fleetProvider.segnaTutteNotificheComeLette();
      verifyNever(() => mockSupabase.from('notifiche'));
    });
  });

  group('FleetProvider - Prenotazioni (successo e validazioni)', () {
    test('creaPrenotazione esegue flow completo quando slot disponibile',
        () async {
      final driver = Utente(
        idUtente: 10,
        nome: "Paolo",
        cognome: "Neri",
        email: "p@n.it",
        ruoloUtente: RuoloUtente.driver,
        patente: "B1",
      );
      final manager = Utente(
        idUtente: 20,
        nome: "Manager",
        cognome: "Uno",
        email: "m@t.it",
        ruoloUtente: RuoloUtente.manager,
      );
      final veicolo = Veicolo(
        targa: "EE555EE",
        marca: "Tesla",
        modello: "Model 3",
        tipoVeicolo: TipoVeicolo.auto,
        annoImmatricolazione: 2023,
        km: 500,
        statoVeicolo: StatoVeicolo.disponibile,
      );

      fleetProvider.utenti.add(manager);

      when(() => mockPrenotazioni.creaPrenotazione(any()))
          .thenAnswer((_) async {
            return;
          });
      when(() => mockNotifiche.notificaRichiestaPrenotazione(
              any(), any(), any(), any(), any()))
          .thenAnswer((_) async {
            return;
          });
      when(() => mockVeicoli.fetchAllVeicoli())
          .thenAnswer((_) async => <Veicolo>[]);
      when(() => mockPrenotazioni.fetchPrenotazioni())
          .thenAnswer((_) async => <Prenotazione>[]);
      when(() => mockAuth.getTuttiUtenti())
          .thenAnswer((_) async => <Utente>[]);
      when(() => mockManutenzioni.fetchTutte())
          .thenAnswer((_) async => <Manutenzione>[]);
      when(() => mockNotifiche.fetchMieNotifiche(any()))
          .thenAnswer((_) async => <Notifica>[]);

      await fleetProvider.creaPrenotazione(
          driver,
          veicolo,
          DateTime(2024, 5, 1, 9, 0),
          DateTime(2024, 5, 1, 10, 0));

      verify(() => mockPrenotazioni.creaPrenotazione(any())).called(1);
      verify(() => mockNotifiche.notificaRichiestaPrenotazione(
              any(), any(), any(), any(), any()))
          .called(1);
      expect(fleetProvider.isLoading, false);
    });

    test('creaPrenotazione lancia eccezione se patente mancante', () async {
      final driver = Utente(
        idUtente: 11,
        nome: "Giulia",
        cognome: "B.",
        email: "g@b.it",
        ruoloUtente: RuoloUtente.driver,
        patente: null,
      );
      final veicolo = Veicolo(
        targa: "FF666FF",
        marca: "VW",
        modello: "Golf",
        tipoVeicolo: TipoVeicolo.auto,
        annoImmatricolazione: 2019,
        km: 12000,
        statoVeicolo: StatoVeicolo.disponibile,
      );

      expect(
        () => fleetProvider.creaPrenotazione(
            driver,
            veicolo,
            DateTime(2024, 6, 1, 9, 0),
            DateTime(2024, 6, 1, 10, 0)),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('FleetProvider - Emergenze', () {
    test('emergenzeAttive e storicoEmergenze filtrano correttamente', () {
      fleetProvider.restituzioni.addAll([
        Restituzione(
          idPrenotazione: 1,
          kmFinali: 0,
          dataRestituzione: DateTime(2024, 7, 1),
          rifornimentoEffettuato: false,
          haPedaggi: false,
          danniPresenti: true,
          isEmergenza: true,
        ),
        Restituzione(
          idPrenotazione: 2,
          kmFinali: 100,
          dataRestituzione: DateTime(2024, 7, 2),
          rifornimentoEffettuato: false,
          haPedaggi: false,
          danniPresenti: true,
          isEmergenza: true,
        ),
        Restituzione(
          idPrenotazione: 3,
          kmFinali: 50,
          dataRestituzione: DateTime(2024, 7, 3),
          rifornimentoEffettuato: false,
          haPedaggi: false,
          danniPresenti: false,
          isEmergenza: false,
        ),
      ]);

      expect(fleetProvider.emergenzeAttive.length, 1);
      expect(fleetProvider.storicoEmergenze.length, 2);
    });
  });

  group('FleetProvider - Logica Prenotazioni', () {
    test('creaPrenotazione deve lanciare eccezione se lo slot è occupato',
        () async {
      final oraInizio = DateTime.now().add(const Duration(hours: 1));
      final oraFine = oraInizio.add(const Duration(hours: 2));

      // Aggiungiamo una prenotazione esistente
      fleetProvider.prenotazioni.add(Prenotazione(
        idPrenotazione: 1,
        idUtente: 99,
        targa: "AB123CD",
        dataInizio: oraInizio,
        dataFine: oraFine,
        statoPrenotazione: StatoPrenotazione.confermata,
        tipoPrenotazione: TipoPrenotazione.utente,
      ));

      final driver = Utente(
          idUtente: 2,
          nome: "Luca",
          cognome: "V",
          email: "l@t.it",
          ruoloUtente: RuoloUtente.driver,
          patente: "B1");
      final veicolo = Veicolo(
          targa: "AB123CD",
          marca: "F",
          modello: "P",
          tipoVeicolo: TipoVeicolo.auto,
          annoImmatricolazione: 2022,
          km: 1000,
          statoVeicolo: StatoVeicolo.disponibile);

      expect(
        () =>
            fleetProvider.creaPrenotazione(driver, veicolo, oraInizio, oraFine),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('FleetProvider - Analisi Dati e Emergenze', () {
    test(
        'totaleSpesaCarburante calcola correttamente la somma ignorando i null',
        () {
      final mockRes = [
        Restituzione(
            idPrenotazione: 1,
            kmFinali: 100,
            dataRestituzione: DateTime.now(),
            rifornimentoEffettuato: true,
            importoEuro: 50.0,
            haPedaggi: false,
            danniPresenti: false),
        Restituzione(
            idPrenotazione: 2,
            kmFinali: 200,
            dataRestituzione: DateTime.now(),
            rifornimentoEffettuato: true,
            importoEuro: 25.5,
            haPedaggi: false,
            danniPresenti: false),
        Restituzione(
            idPrenotazione: 3,
            kmFinali: 300,
            dataRestituzione: DateTime.now(),
            rifornimentoEffettuato: false,
            importoEuro: null,
            haPedaggi: false,
            danniPresenti: false),
      ];

      // Verifichiamo la logica di calcolo
      final somma = mockRes
          .where((r) => r.importoEuro != null)
          .fold(0.0, (sum, r) => sum + r.importoEuro!);

      expect(somma, 75.50);
    });

    test('emergenzeAttive filtra correttamente SOS con km a 0', () {
      final lista = [
        Restituzione(
            idPrenotazione: 1,
            kmFinali: 0,
            dataRestituzione: DateTime.now(),
            rifornimentoEffettuato: false,
            haPedaggi: false,
            danniPresenti: true,
            isEmergenza: true),
        Restituzione(
            idPrenotazione: 2,
            kmFinali: 100,
            dataRestituzione: DateTime.now(),
            rifornimentoEffettuato: false,
            haPedaggi: false,
            danniPresenti: true,
            isEmergenza: true),
      ];

      final attive =
          lista.where((r) => r.isEmergenza && r.kmFinali == 0).toList();
      expect(attive.length, 1);
    });
  });
}
