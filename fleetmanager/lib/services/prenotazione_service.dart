import 'package:dio/dio.dart';
import 'package:fleetmanager/mock/mock_data.dart';
import '../models/prenotazione.dart';
import '../models/enums/stato_prenotazione.dart';
import '../models/enums/ruolo_utente.dart';
import '../models/utente.dart';

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

  // Da GestorePrenotazioniImpl: validaDisponibilita
  Future<bool> validaDisponibilita(String targa, DateTime dataInizio, DateTime dataFine) async {
    try {
      final response = await _dio.get('/prenotazioni/veicolo/$targa');
      List<Prenotazione> prenotazioni = (response.data as List)
          .map((json) => Prenotazione.fromJson(json))
          .toList();

      for (var p in prenotazioni) {
        bool overlap = dataInizio.isBefore(p.dataFine) && dataFine.isAfter(p.dataInizio);
        if (overlap && p.statoPrenotazione != StatoPrenotazione.annullata) {
          return false;
        }
      }
      return true;
    } catch (e) {
      // Fallback mock
      return MockData.validaDisponibilita(targa, dataInizio, dataFine);
    }
  }

  // Da GestorePrenotazioniImpl: confermaPrenotazione
  Future<void> confermaPrenotazione(int idPrenotazione) async {
    try {
      await _dio.post('/prenotazioni/$idPrenotazione/conferma');
    } catch (e) {
      throw Exception('Errore nella conferma prenotazione');
    }
  }

  // Da GestorePrenotazioniImpl: annullaPrenotazione
  Future<void> annullaPrenotazione(int idPrenotazione) async {
    try {
      await _dio.post('/prenotazioni/$idPrenotazione/annulla');
    } catch (e) {
      throw Exception('Errore nell\'annullamento prenotazione');
    }
  }

  // Da GestorePrenotazioniImpl: aggiornaStatiPrenotazioni
  Future<void> aggiornaStatiPrenotazioni() async {
    try {
      await _dio.post('/prenotazioni/aggiorna-stati');
    } catch (e) {
      // Fallback locale se necessario
      throw Exception('Errore nell\'aggiornamento stati');
    }
  }

  // Da GestorePrenotazioniImpl: getPrenotazioniVisibiliOrdinare
  Future<List<Prenotazione>> getPrenotazioniVisibiliOrdinare(Utente utenteLoggato) async {
    List<Prenotazione> tutte = await fetchPrenotazioni();

    if (utenteLoggato.ruoloUtente != RuoloUtente.manager) {
      tutte = tutte.where((p) => p.idUtente == utenteLoggato.idUtente).toList();
    }

    // Ordinamento come in Java
    tutte.sort((a, b) {
      int prioritaA = _priorita(a, utenteLoggato);
      int prioritaB = _priorita(b, utenteLoggato);
      int cmp = prioritaA.compareTo(prioritaB);
      if (cmp != 0) return cmp;
      return _confrontoTemporale(a, b);
    });

    return tutte;
  }

  int _priorita(Prenotazione p, Utente utenteLoggato) {
    StatoPrenotazione s = p.statoPrenotazione;
    bool isManager = utenteLoggato.ruoloUtente == RuoloUtente.manager;

    if (isManager) {
      return switch (s) {
        StatoPrenotazione.richiesta => 1,
        StatoPrenotazione.attiva => 2,
        StatoPrenotazione.confermata => 3,
        StatoPrenotazione.completata => 4,
        StatoPrenotazione.annullata => 5,
      };
    } else {
      return switch (s) {
        StatoPrenotazione.attiva => 1,
        StatoPrenotazione.richiesta => 2,
        StatoPrenotazione.confermata => 3,
        StatoPrenotazione.completata => 4,
        StatoPrenotazione.annullata => 5,
      };
    }
  }

  int _confrontoTemporale(Prenotazione a, Prenotazione b) {
    DateTime now = DateTime.now();
    DateTime ta = a.dataInizio.isAfter(now) ? a.dataInizio : a.dataFine;
    DateTime tb = b.dataInizio.isAfter(now) ? b.dataInizio : b.dataFine;
    return ta.compareTo(tb);
  }
}
