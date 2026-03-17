import 'package:dio/dio.dart';
import 'package:fleetmanager/mock/mock_data.dart';
import '../models/prenotazione.dart';

class PrenotazioneService {
  final Dio _dio = Dio(BaseOptions(baseUrl: 'http://localhost:8080/api'));

  // Sostituisce getPrenotazioniVisibiliOrdinare
  Future<List<Prenotazione>> fetchPrenotazioni({int? idUtente}) async {
    try {
      // Se idUtente è fornito, filtriamo (logica driver), altrimenti prendiamo tutte (logica admin)
      final path = idUtente != null ? '/prenotazioni/driver/$idUtente' : '/prenotazioni';
      final response = await _dio.get(path);
      List<dynamic> data = response.data;
      return data.map((json) => Prenotazione.fromJson(json)).toList();
    } catch (_) {
      // Fallback mock per sviluppo/offline
      return MockData.prenotazioniPerUtente(idUtente);
    }
  }

  // Sostituisce confermaPrenotazione e prenotaVeicolo
  Future<void> creaPrenotazione(Prenotazione p) async {
    try {
      await _dio.post('/prenotazioni', data: p.toJson());
    } catch (e) {
      throw Exception('Errore: Veicolo non disponibile o dati non validi');
    }
  }

  // Sostituisce completaPrenotazione (con controllo data fine)
  Future<void> completaPrenotazione(int id) async {
    try {
      await _dio.post('/prenotazioni/$id/completa');
    } catch (e) {
      // Qui il backend restituirà l'errore se LocalDateTime.now() < dataFine
      throw Exception('Non puoi completare la prenotazione prima della fine prevista');
    }
  }
}
