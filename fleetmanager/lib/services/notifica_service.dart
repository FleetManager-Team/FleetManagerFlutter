import 'package:dio/dio.dart';
import '../models/notifica.dart';

class NotificaService {
  final Dio _dio = Dio(BaseOptions(baseUrl: 'http://localhost:8080/api'));

  Future<List<Notifica>> fetchMieNotifiche(int idUtente) async {
    final response = await _dio.get('/notifiche/utente/$idUtente');
    List<dynamic> data = response.data;
    return data.map((json) => Notifica.fromJson(json)).toList();
  }

  Future<void> segnaLetta(int id) async {
    await _dio.patch('/notifiche/$id/leggi');
  }

  // Da SistemaNotifiche: inviaNotificaScadenza
  Future<void> inviaNotificaScadenza(int idScadenza, String targa, String tipoScadenza, DateTime data) async {
    try {
      await _dio.post('/notifiche/scadenza', data: {
        'idScadenza': idScadenza,
        'targa': targa,
        'tipoScadenza': tipoScadenza,
        'data': data.toIso8601String(),
      });
    } catch (e) {
      throw Exception('Errore invio notifica scadenza');
    }
  }

  // Da SistemaNotifiche: notificaRichiestaPrenotazione
  Future<void> notificaRichiestaPrenotazione(int idDriver, String targa, DateTime dataInizio, DateTime dataFine) async {
    try {
      await _dio.post('/notifiche/prenotazione/richiesta', data: {
        'idDriver': idDriver,
        'targa': targa,
        'dataInizio': dataInizio.toIso8601String(),
        'dataFine': dataFine.toIso8601String(),
      });
    } catch (e) {
      throw Exception('Errore notifica richiesta prenotazione');
    }
  }

  // Altri metodi simili per conferme, rifiuti, manutenzioni, ecc.
  Future<void> notificaConfermaPrenotazione(int idDriver, String targa, DateTime dataInizio, DateTime dataFine) async {
    try {
      await _dio.post('/notifiche/prenotazione/conferma', data: {
        'idDriver': idDriver,
        'targa': targa,
        'dataInizio': dataInizio.toIso8601String(),
        'dataFine': dataFine.toIso8601String(),
      });
    } catch (e) {
      throw Exception('Errore notifica conferma prenotazione');
    }
  }

  Future<void> notificaRifiutoPrenotazione(int idDriver, String targa, DateTime dataInizio, DateTime dataFine) async {
    try {
      await _dio.post('/notifiche/prenotazione/rifiuto', data: {
        'idDriver': idDriver,
        'targa': targa,
        'dataInizio': dataInizio.toIso8601String(),
        'dataFine': dataFine.toIso8601String(),
      });
    } catch (e) {
      throw Exception('Errore notifica rifiuto prenotazione');
    }
  }

  Future<void> notificaManutenzioneProgrammata(int idUtente, String targa, DateTime data) async {
    try {
      await _dio.post('/notifiche/manutenzione/programmata', data: {
        'idUtente': idUtente,
        'targa': targa,
        'data': data.toIso8601String(),
      });
    } catch (e) {
      throw Exception('Errore notifica manutenzione programmata');
    }
  }

  Future<void> notificaAnnullamentoPrenotazioneDaDriver(int idDriver, String targa) async {
    try {
      await _dio.post('/notifiche/prenotazione/annullamento-driver', data: {
        'idDriver': idDriver,
        'targa': targa,
      });
    } catch (e) {
      throw Exception('Errore notifica annullamento da driver');
    }
  }

  Future<void> notificaInterventoStraordinario(int idUtente, String targa) async {
    try {
      await _dio.post('/notifiche/manutenzione/straordinaria', data: {
        'idUtente': idUtente,
        'targa': targa,
      });
    } catch (e) {
      throw Exception('Errore notifica intervento straordinario');
    }
  }
}