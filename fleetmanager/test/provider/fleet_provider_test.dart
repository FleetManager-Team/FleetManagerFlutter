import 'package:fleetmanager/models/enums/tipo_veicolo.dart';
import 'package:fleetmanager/provider/fleet_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fleetmanager/services/auth_service.dart';
import 'package:fleetmanager/services/veicolo_service.dart';
import 'package:fleetmanager/services/prenotazione_service.dart';
import 'package:fleetmanager/services/manutenzione_service.dart';
import 'package:fleetmanager/services/notifica_service.dart';
import 'package:fleetmanager/models/veicolo.dart';
import 'package:fleetmanager/models/enums/stato_veicolo.dart';

/*
// Generiamo i Mock inclusi SupabaseClient
@GenerateNiceMocks([
  MockSpec<AuthService>(),
  MockSpec<VeicoloService>(),
  MockSpec<PrenotazioneService>(),
  MockSpec<ManutenzioneService>(),
  MockSpec<NotificaService>(),
  MockSpec<SupabaseClient>(),
])
import 'fleet_provider_test.mocks.dart';

void main() {
   late FleetProvider fleetProvider;
  late MockAuthService mockAuthService;
  late MockVeicoloService mockVeicoloService;
  late MockPrenotazioneService mockPrenotazioneService;
  late MockManutenzioneService mockManutenzioneService;
  late MockNotificaService mockNotificaService;
  late MockSupabaseClient mockSupabaseClient;

  setUp(() {
    mockAuthService = MockAuthService();
    mockVeicoloService = MockVeicoloService();
    mockPrenotazioneService = MockPrenotazioneService();
    mockManutenzioneService = MockManutenzioneService();
    mockNotificaService = MockNotificaService();
    mockSupabaseClient = MockSupabaseClient();


    // Iniezione di TUTTI i mock nel provider
    fleetProvider = FleetProvider(
      authService: mockAuthService,
      veicoloService: mockVeicoloService,
      prenotazioneService: mockPrenotazioneService,
      manutenzioneService: mockManutenzioneService,
      notificaService: mockNotificaService,
      supabaseClient: mockSupabaseClient, // <--- Passiamo il mock
    );
  });

 TestWidgetsFlutterBinding.ensureInitialized();
  group('FleetProvider - Mocked Tests', () {
    test('inizializzaDati popola i veicoli correttamente', () async {
      final fintiVeicoli = [
        Veicolo(
            targa: 'AB123CD',
            marca: 'Fiat',
            modello: 'Panda',
            km: 100,
            statoVeicolo: StatoVeicolo.disponibile,
            tipoVeicolo: TipoVeicolo.auto,
            annoImmatricolazione: 2022),
      ];

      // Definiamo cosa rispondono i mock
      when(mockVeicoloService.fetchAllVeicoli())
          .thenAnswer((_) async => fintiVeicoli);
      when(mockPrenotazioneService.fetchPrenotazioni())
          .thenAnswer((_) async => []);
      when(mockAuthService.getTuttiUtenti()).thenAnswer((_) async => []);
      when(mockManutenzioneService.fetchTutte()).thenAnswer((_) async => []);

      // Serve simulare anche la chiamata diretta a supabase.from('restituzioni').select()
      // Se inizializzaDati la usa, altrimenti questo basterà.

      await fleetProvider.inizializzaDati();

      expect(fleetProvider.veicoli.length, 1);
      expect(fleetProvider.veicoli.first.targa, 'AB123CD');
    });

    test('Il logout resetta l\'utente loggato', () {
      fleetProvider.logout();
      expect(fleetProvider.utenteLoggato, isNull);
      expect(fleetProvider.veicoli, isEmpty);
    });
  });
}
*/