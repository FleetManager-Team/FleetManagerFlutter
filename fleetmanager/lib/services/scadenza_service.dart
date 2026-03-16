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
}