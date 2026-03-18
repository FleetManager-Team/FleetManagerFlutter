import 'package:dio/dio.dart';
import '../models/scadenza.dart';

class ScadenzaService {
  final Dio _dio = Dio(BaseOptions(baseUrl: 'http://localhost:8080/api'));

  // Sostituisce controllaScadenzeEntro
  Future<List<Scadenza>> fetchScadenzeInArrivo(int giorni) async {
    try {
      final response = await _dio.get('/scadenze/prossime', queryParameters: {'giorni': giorni});
      List<dynamic> data = response.data;
      return data.map((json) => Scadenza.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Errore controllo scadenze');
    }
  }

  // Sostituisce marcaComeNotificata
  Future<void> segnaNotificata(int id) async {
    await _dio.patch('/scadenze/$id/notificata');
  }

  // Da GestoreScadenzeImpl: controllaScadenzeEntro
  Future<Scadenza?> controllaScadenzeEntro(DateTime dataLimite) async {
    try {
      final response = await _dio.get('/scadenze/prossime', queryParameters: {
        'dataLimite': dataLimite.toIso8601String(),
      });
      List<dynamic> data = response.data;
      if (data.isNotEmpty) {
        return Scadenza.fromJson(data[0]);
      }
      return null;
    } catch (e) {
      throw Exception('Errore controllo scadenze');
    }
  }

  // Da GestoreScadenzeImpl: bloccaVeicoloSeScaduta
  Future<void> bloccaVeicoloSeScaduta(String targa) async {
    try {
      await _dio.post('/scadenze/blocca-veicolo/$targa');
    } catch (e) {
      throw Exception('Errore blocco veicolo');
    }
  }

  // Da GestoreScadenzeImpl: eseguiControlloPeriodico
  Future<void> eseguiControlloPeriodico() async {
    try {
      await _dio.post('/scadenze/controllo-periodico');
    } catch (e) {
      throw Exception('Errore controllo periodico');
    }
  }
}