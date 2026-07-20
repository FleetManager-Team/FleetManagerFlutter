import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:fleetmanager/models/enums/ruolo_utente.dart';
import 'package:fleetmanager/models/manutenzione.dart';
import 'package:fleetmanager/models/notifica.dart';
import 'package:fleetmanager/models/prenotazione.dart';
import 'package:fleetmanager/models/utente.dart';
import 'package:fleetmanager/models/veicolo.dart';
import 'package:fleetmanager/provider/fleet_provider.dart';
import 'package:fleetmanager/provider/impostazioni_provider.dart';
import 'package:fleetmanager/services/auth_service.dart';
import 'package:fleetmanager/services/impostazioni_service.dart';
import 'package:fleetmanager/services/manutenzione_service.dart';
import 'package:fleetmanager/services/notifica_service.dart';
import 'package:fleetmanager/services/prenotazione_service.dart';
import 'package:fleetmanager/services/scadenza_service.dart';
import 'package:fleetmanager/services/veicolo_service.dart';

export 'package:mocktail/mocktail.dart';

// --- Mock dei service, sullo stesso modello di test/provider/fleet_provider_test.dart ---
class MockAuthService extends Mock implements AuthService {}

class MockVeicoloService extends Mock implements VeicoloService {}

class MockPrenotazioneService extends Mock implements PrenotazioneService {}

class MockManutenzioneService extends Mock implements ManutenzioneService {}

class MockNotificaService extends Mock implements NotificaService {}

class MockScadenzaService extends Mock implements ScadenzaService {}

class MockImpostazioniService extends Mock implements ImpostazioniService {}

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockSupabaseQueryBuilder extends Mock implements SupabaseQueryBuilder {}

class MockGoTrueClient extends Mock implements GoTrueClient {}

class FakeUtente extends Fake implements Utente {}

class FakeVeicolo extends Fake implements Veicolo {}

class FakePrenotazione extends Fake implements Prenotazione {}

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
  PostgrestFilterBuilder<T> eq(String column, dynamic value) => this;
}

FakePostgrestFilterBuilder<T> futureBuilder<T>(T value) {
  return FakePostgrestFilterBuilder<T>(Future<T>.value(value));
}

/// Raggruppa un [FleetProvider] pronto all'uso con tutti i suoi service
/// sostituiti da mock Mocktail, cosi le schermate si possono testare senza
/// toccare Supabase reale (stesso approccio di test/provider/fleet_provider_test.dart).
class WidgetTestHarness {
  WidgetTestHarness._({
    required this.provider,
    required this.authService,
    required this.veicoloService,
    required this.prenotazioneService,
    required this.manutenzioneService,
    required this.notificaService,
    required this.scadenzaService,
    required this.supabase,
    required this.queryBuilder,
  });

  final FleetProvider provider;
  final MockAuthService authService;
  final MockVeicoloService veicoloService;
  final MockPrenotazioneService prenotazioneService;
  final MockManutenzioneService manutenzioneService;
  final MockNotificaService notificaService;
  final MockScadenzaService scadenzaService;
  final MockSupabaseClient supabase;
  final MockSupabaseQueryBuilder queryBuilder;

  /// Da chiamare una sola volta per file di test, dentro un setUpAll().
  static void registerFallbacks() {
    registerFallbackValue(FakeUtente());
    registerFallbackValue(FakeVeicolo());
    registerFallbackValue(FakePrenotazione());
    registerFallbackValue(const FetchOptions());
  }

  factory WidgetTestHarness.create() {
    final mockAuth = MockAuthService();
    final mockVeicoli = MockVeicoloService();
    final mockPrenotazioni = MockPrenotazioneService();
    final mockManutenzioni = MockManutenzioneService();
    final mockNotifiche = MockNotificaService();
    final mockScadenze = MockScadenzaService();
    final mockSupabase = MockSupabaseClient();
    final mockQueryBuilder = MockSupabaseQueryBuilder();
    final mockGoTrue = MockGoTrueClient();

    when(() => mockSupabase.auth).thenReturn(mockGoTrue);
    when(() => mockSupabase.from(any())).thenAnswer((_) => mockQueryBuilder);

    when(() => mockQueryBuilder.select())
        .thenAnswer((_) => futureBuilder<List<dynamic>>(<dynamic>[]));
    when(() => mockQueryBuilder.select<List<dynamic>>())
        .thenAnswer((_) => futureBuilder<List<dynamic>>(<dynamic>[]));
    when(() => mockQueryBuilder.insert(any()))
        .thenAnswer((_) => futureBuilder<void>(null));

    // Default: liste vuote finche' un test non le popola direttamente
    // tramite i getter mutabili di FleetProvider (provider.veicoli.add(...)).
    when(() => mockVeicoli.fetchAllVeicoli())
        .thenAnswer((_) async => <Veicolo>[]);
    when(() => mockPrenotazioni.fetchPrenotazioni())
        .thenAnswer((_) async => <Prenotazione>[]);
    when(() => mockAuth.getTuttiUtenti()).thenAnswer((_) async => <Utente>[]);
    when(() => mockManutenzioni.fetchTutte())
        .thenAnswer((_) async => <Manutenzione>[]);
    when(() => mockNotifiche.fetchMieNotifiche(any()))
        .thenAnswer((_) async => <Notifica>[]);

    final provider = FleetProvider(
      authService: mockAuth,
      veicoloService: mockVeicoli,
      prenotazioneService: mockPrenotazioni,
      manutenzioneService: mockManutenzioni,
      notificaService: mockNotifiche,
      scadenzaService: mockScadenze,
      supabaseClient: mockSupabase,
    );

    return WidgetTestHarness._(
      provider: provider,
      authService: mockAuth,
      veicoloService: mockVeicoli,
      prenotazioneService: mockPrenotazioni,
      manutenzioneService: mockManutenzioni,
      notificaService: mockNotifiche,
      scadenzaService: mockScadenze,
      supabase: mockSupabase,
      queryBuilder: mockQueryBuilder,
    );
  }

  /// Simula un login riuscito cosi' che `provider.utenteLoggato` risulti
  /// valorizzato (unica via pubblica per popolare quel campo privato).
  Future<void> loginAs(
    RuoloUtente ruolo, {
    int idUtente = 1,
    String? patente,
  }) async {
    final utente = Utente(
      idUtente: idUtente,
      nome: "Test",
      cognome: "User",
      email: "test@fleetmanager.it",
      ruoloUtente: ruolo,
      patente: patente,
    );
    when(() => authService.login(any(), any()))
        .thenAnswer((_) async => utente);
    await provider.login("test@fleetmanager.it", "password123");
  }
}

/// Costruisce un [ImpostazioniProvider] gia' "caricato" con un
/// [ImpostazioniService] mockato, evitando di toccare SharedPreferences reali.
Future<ImpostazioniProvider> buildImpostazioniProvider({
  bool approvazioneRichiesta = true,
  bool checkupObbligatorio = true,
}) async {
  final mockService = MockImpostazioniService();
  when(() => mockService.getFotoScontrinoObbligatoria())
      .thenAnswer((_) async => true);
  when(() => mockService.getFotoDanniObbligatoria())
      .thenAnswer((_) async => false);
  when(() => mockService.getFotoPedaggiObbligatoria())
      .thenAnswer((_) async => false);
  when(() => mockService.getCheckupObbligatorio())
      .thenAnswer((_) async => checkupObbligatorio);
  when(() => mockService.getApprovazioneRichiesta())
      .thenAnswer((_) async => approvazioneRichiesta);
  when(() => mockService.getModuloPedaggiAbilitato())
      .thenAnswer((_) async => true);

  final provider = ImpostazioniProvider(service: mockService);
  await provider.ensureLoaded();
  return provider;
}

/// Monta una schermata avvolta nel solo FleetProvider.
Widget wrapWithFleetProvider(FleetProvider provider, Widget child) {
  return ChangeNotifierProvider<FleetProvider>.value(
    value: provider,
    child: MaterialApp(home: child),
  );
}

/// Monta una schermata avvolta in FleetProvider + ImpostazioniProvider.
Widget wrapWithProviders(
  FleetProvider fleetProvider,
  ImpostazioniProvider impostazioniProvider,
  Widget child,
) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<FleetProvider>.value(value: fleetProvider),
      ChangeNotifierProvider<ImpostazioniProvider>.value(
          value: impostazioniProvider),
    ],
    child: MaterialApp(home: child),
  );
}

/// Alcune schermate chiamano `Navigator.pop()` dopo un'azione (es. dopo aver
/// confermato una prenotazione): se sono l'unica route in stack l'operazione
/// fallisce. Questo helper le "push-a" sopra una route fittizia, come
/// avviene davvero nell'app quando si naviga da una lista di dettaglio.
Future<void> pumpPushedScreen(
  WidgetTester tester, {
  required Widget screen,
  required List<ChangeNotifierProvider<dynamic>> providers,
}) async {
  await tester.pumpWidget(
    MultiProvider(
      providers: providers,
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => screen),
                ),
                child: const Text('Apri'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Apri'));
  await tester.pumpAndSettle();
}
