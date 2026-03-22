import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/prenotazione.dart';
import '../models/enums/stato_prenotazione.dart';

class PrenotazioneService {
  final _supabase = Supabase.instance.client;

  /// Recupera le prenotazioni dal DB.
  /// Se [idUtente] è fornito, filtra per quel driver.
  Future<List<Prenotazione>> fetchPrenotazioni({int? idUtente}) async {
    try {
      var query = _supabase.from('prenotazioni').select();

      if (idUtente != null) {
        query = query.eq('id_utente', idUtente);
      }

      final response = await query.order('data_inizio', ascending: false);

      return (response as List)
          .map((json) => Prenotazione.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception("Errore nel recupero delle prenotazioni: $e");
    }
  }

  /// Inserisce una nuova prenotazione su Supabase.
  Future<void> creaPrenotazione(Prenotazione p) async {
    try {
      final data = p.toJson();
      // Rimuoviamo l'ID per lasciare che sia il database a generarlo (Serial/Identity)
      data.remove('id_prenotazione');

      await _supabase.from('prenotazioni').insert(data);
    } catch (e) {
      throw Exception("Errore durante la creazione della prenotazione: $e");
    }
  }

  /// Aggiorna lo stato di una prenotazione specifica.
  Future<void> _updateStato(int id, StatoPrenotazione nuovoStato) async {
    try {
      await _supabase
          .from('prenotazioni')
          .update({'stato': nuovoStato.name}).eq('id_prenotazione', id);
    } catch (e) {
      throw Exception(
          "Impossibile aggiornare lo stato a ${nuovoStato.name}: $e");
    }
  }

  Future<void> confermaPrenotazione(int id) =>
      _updateStato(id, StatoPrenotazione.confermata);
  Future<void> annullaPrenotazione(int id) =>
      _updateStato(id, StatoPrenotazione.annullata);
  Future<void> completaPrenotazione(int id) =>
      _updateStato(id, StatoPrenotazione.completata);

  /// Verifica se il veicolo è libero in un determinato intervallo temporale.
  /// Esclude le prenotazioni annullate dal controllo.
  Future<bool> validaDisponibilita(
      String targa, DateTime inizio, DateTime fine) async {
    try {
      final response = await _supabase
          .from('prenotazioni')
          .select()
          .eq('targa', targa)
          // Ignoriamo le annullate: non bloccano il veicolo
          .neq('stato', StatoPrenotazione.annullata.name);

      final esistenti = (response as List)
          .map((json) => Prenotazione.fromJson(json))
          .toList();

      for (var p in esistenti) {
        // Logica di sovrapposizione: (Inizio1 < Fine2) AND (Fine1 > Inizio2)
        if (inizio.isBefore(p.dataFine) && fine.isAfter(p.dataInizio)) {
          return false; // Sovrapposizione trovata
        }
      }
      return true; // Veicolo disponibile
    } catch (e) {
      throw Exception("Errore durante la verifica disponibilità: $e");
    }
  }

  /// Sincronizza gli stati in base al tempo corrente.
  /// Da chiamare preferibilmente all'avvio dell'app o al refresh.
  Future<void> aggiornaStatiPrenotazioni() async {
    try {
      final ora = DateTime.now().toIso8601String();

      // 1. Passa da 'confermata' ad 'attiva' se l'orario di inizio è passato o attuale
      await _supabase
          .from('prenotazioni')
          .update({'stato': StatoPrenotazione.attiva.name})
          .eq('stato', StatoPrenotazione.confermata.name)
          .lte('data_inizio', ora);

      // 2. Passa da 'attiva' a 'completata' se l'orario di fine è passato
      await _supabase
          .from('prenotazioni')
          .update({'stato': StatoPrenotazione.completata.name})
          .eq('stato', StatoPrenotazione.attiva.name)
          .lte('data_fine', ora);
    } catch (e) {
      print("Errore aggiornamento automatico stati: $e");
    }
  }
}
