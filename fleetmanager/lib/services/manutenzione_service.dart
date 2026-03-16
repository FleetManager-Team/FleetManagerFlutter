import 'package:dio/dio.dart';
import '../models/manutenzione.dart';

class ManutenzioneService {
  final Dio _dio = Dio(BaseOptions(baseUrl: 'http://localhost:8080/api'));

  // Sostituisce programmareManutenzione e segnalareInterventoStraordinario
  Future<void> registraIntervento(Manutenzione m) async {
    try {
      await _dio.post('/manutenzioni', data: {
        ...m.toJson(),
        // Il backend si occuperà di settare lo stato del veicolo su IN_MANUTENZIONE
      });
    } catch (e) {
      throw Exception('Errore nella registrazione manutenzione');
    }
  }

  // Sostituisce chiudiManutenzione
  Future<void> chiudiIntervento(int id, int nuoviKm) async {
    try {
      await _dio.patch('/manutenzioni/$id/chiudi', data: {'km': nuoviKm});
    } catch (e) {
      throw Exception('Errore nella chiusura manutenzione');
    }
  }
}