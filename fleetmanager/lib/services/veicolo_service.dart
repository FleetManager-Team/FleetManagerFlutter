import 'package:dio/dio.dart';
import '../models/veicolo.dart';
import '../models/enums/stato_veicolo.dart';

class VeicoloService {
  // In un progetto serio, l'indirizzo base verrebbe da una configurazione globale
  final Dio _dio = Dio(BaseOptions(baseUrl: 'http://localhost:8080/api'));

  /// Recupera tutti i veicoli dal database (Backend)
  /// Restituisce un Future: la promessa di una lista di oggetti Veicolo
  Future<List<Veicolo>> fetchAllVeicoli() async {
    try {
      final response = await _dio.get('/veicoli');

      if (response.statusCode == 200) {
        // La risposta arriva come una lista di mappe JSON
        List<dynamic> data = response.data;
        // Convertiamo ogni mappa JSON in un oggetto Veicolo usando il factory .fromJson
        return data.map((json) => Veicolo.fromJson(json)).toList();
      } else {
        throw Exception('Errore del server: ${response.statusCode}');
      }
    } on DioException catch (e) {
      // Gestione professionale dell'errore di rete
      throw Exception('Errore di connessione: ${e.message}');
    }
  }

  /// Aggiorna lo stato di un veicolo (es. da Disponibile a In Manutenzione)
  /// Corrisponde al tuo setStatoVeicolo in Java
  Future<void> updateStatoVeicolo(String targa, StatoVeicolo nuovoStato) async {
    try {
      await _dio.patch('/veicoli/$targa', data: {
        'statoVeicolo': nuovoStato.name, // Usiamo .name per inviare la stringa dell'enum
      });
    } catch (e) {
      throw Exception('Impossibile aggiornare lo stato: $e');
    }
  }

  /// Crea un nuovo veicolo inviando l'oggetto completo come JSON
  Future<void> createVeicolo(Veicolo veicolo) async {
    try {
      await _dio.post('/veicoli', data: veicolo.toJson());
    } catch (e) {
      throw Exception('Errore durante la creazione del veicolo: $e');
    }
  }
}