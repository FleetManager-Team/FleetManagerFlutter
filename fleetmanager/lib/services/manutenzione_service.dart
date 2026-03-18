import 'package:dio/dio.dart';
import '../models/manutenzione.dart';
import '../models/enums/tipo_manutenzione.dart';

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

  // Da GestoreManutenzioniImpl: programmareManutenzione
  Future<Manutenzione> programmareManutenzione(String targa, DateTime dataInizio, TipoManutenzione tipo, String descrizione) async {
    try {
      final response = await _dio.post('/manutenzioni/programmata', data: {
        'targa': targa,
        'dataInizio': dataInizio.toIso8601String(),
        'tipo': tipo.name,
        'descrizione': descrizione,
      });
      return Manutenzione.fromJson(response.data);
    } catch (e) {
      throw Exception('Errore nella programmazione manutenzione');
    }
  }

  // Da GestoreManutenzioniImpl: segnalareInterventoStraordinario
  Future<Manutenzione> segnalareInterventoStraordinario(String targa, String descrizione) async {
    try {
      final response = await _dio.post('/manutenzioni/straordinaria', data: {
        'targa': targa,
        'descrizione': descrizione,
      });
      return Manutenzione.fromJson(response.data);
    } catch (e) {
      throw Exception('Errore nella segnalazione intervento straordinario');
    }
  }

  // Da GestoreManutenzioniImpl: chiudiManutenzione
  Future<void> chiudiManutenzione(int idManutenzione) async {
    try {
      await _dio.post('/manutenzioni/$idManutenzione/chiudi');
    } catch (e) {
      throw Exception('Errore nella chiusura manutenzione');
    }
  }
}