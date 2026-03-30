
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/prenotazione.dart';
import '../models/enums/stato_prenotazione.dart';

class PrenotazioneService {
  final _supabase = Supabase.instance.client;

  /// Recupera TUTTE le prenotazioni dal DB.
  /// Rimosso il filtro idUtente obbligatorio per garantire che il Provider
  /// abbia la visione completa della flotta e prevenire sovrapposizioni.
  Future<List<Prenotazione>> fetchPrenotazioni() async {
    try {
      // Prendiamo tutto e ordiniamo per data decrescente
      final response = await _supabase
          .from('prenotazioni')
          .select()
          .order('data_inizio', ascending: false);

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
      // Rimuoviamo l'ID per lasciare che sia il database a generarlo
      data.remove('id_prenotazione');

      await _supabase.from('prenotazioni').insert(data);
    } catch (e) {
      throw Exception("Errore durante la creazione della prenotazione: $e");
    }
  }

  /// Metodo generico per aggiornare lo stato
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

  /// Verifica se il veicolo è libero (Metodo di backup lato Server)
  Future<bool> validaDisponibilita(
      String targa, DateTime inizio, DateTime fine) async {
    try {
      final response = await _supabase
          .from('prenotazioni')
          .select()
          .eq('targa', targa)
          .neq('stato', StatoPrenotazione.annullata.name);

      final esistenti = (response as List)
          .map((json) => Prenotazione.fromJson(json))
          .toList();

      for (var p in esistenti) {
        if (inizio.isBefore(p.dataFine) && fine.isAfter(p.dataInizio)) {
          return false;
        }
      }
      return true;
    } catch (e) {
      throw Exception("Errore durante la verifica disponibilità: $e");
    }
  }

  /// Sincronizza gli stati in base al tempo corrente.
  /*Future<void> aggiornaStatiPrenotazioni() async {
    try {
      final ora = DateTime.now().toIso8601String();

      // 1. Da 'confermata' ad 'attiva'
      await _supabase
          .from('prenotazioni')
          .update({'stato': StatoPrenotazione.attiva.name})
          .eq('stato', StatoPrenotazione.confermata.name)
          .lte('data_inizio', ora);

      // 2. Da 'attiva' a 'completata'
      await _supabase
          .from('prenotazioni')
          .update({'stato': StatoPrenotazione.completata.name})
          .eq('stato', StatoPrenotazione.attiva.name)
          .lte('data_fine', ora);

      debugPrint("Stati prenotazioni aggiornati correttamente.");
    } catch (e) {
      print("Errore aggiornamento automatico stati: $e");
    }
  }*/
}
