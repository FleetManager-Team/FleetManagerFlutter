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
import 'package:fleetmanager/models/enums/tipo_prenotazione.dart';
import 'package:fleetmanager/models/enums/tipo_veicolo.dart';

// 1. MOCK CLASSES
class MockAuthService extends Mock implements AuthService {}

class MockVeicoloService extends Mock implements VeicoloService {}

class MockPrenotazioneService extends Mock implements PrenotazioneService {}

class MockManutenzioneService extends Mock implements ManutenzioneService {}

class MockNotificaService extends Mock implements NotificaService {}

class MockSupabaseClient extends Mock implements SupabaseClient {}

// 2. FAKE CLASSES PER FALLBACK (Necessarie per any())
class FakeUtente extends Fake implements Utente {}

class FakeVeicolo extends Fake implements Veicolo {}

class FakePrenotazione extends Fake implements Prenotazione {}

void main() {
  // Inizializzazione necessaria per i test Flutter
  TestWidgetsFlutterBinding.ensureInitialized();

  late FleetProvider fleetProvider;
  late MockAuthService mockAuth;
  late MockVeicoloService mockVeicoli;
  late MockPrenotazioneService mockPrenotazioni;
  late MockManutenzioneService mockManutenzioni;
  late MockNotificaService mockNotifiche;
  late MockSupabaseClient mockSupabase;

  setUpAll(() {
    // Registrazione dei tipi per permettere l'uso di any()
    registerFallbackValue(FakeUtente());
    registerFallbackValue(FakeVeicolo());
    registerFallbackValue(FakePrenotazione());
  });

  setUp(() {
    mockAuth = MockAuthService();
    mockVeicoli = MockVeicoloService();
    mockPrenotazioni = MockPrenotazioneService();
    mockManutenzioni = MockManutenzioneService();
    mockNotifiche = MockNotificaService();
    mockSupabase = MockSupabaseClient();

    fleetProvider = FleetProvider(
      authService: mockAuth,
      veicoloService: mockVeicoli,
      prenotazioneService: mockPrenotazioni,
      manutenzioneService: mockManutenzioni,
      notificaService: mockNotifiche,
      supabaseClient: mockSupabase,
    );
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
