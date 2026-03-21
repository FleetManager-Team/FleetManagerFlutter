import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/prenotazione.dart';
import '../models/enums/stato_prenotazione.dart';

class PrenotazioneService {
  final _supabase = Supabase.instance.client;

  Future<List<Prenotazione>> fetchPrenotazioni({int? idUtente}) async {
    var query = _supabase.from('prenotazioni').select();
    if (idUtente != null) {
      query = query.eq('id_utente', idUtente);
    }
    final response = await query.order('data_inizio', ascending: false);
    return (response as List).map((json) => Prenotazione.fromJson(json)).toList();
  }

  Future<void> creaPrenotazione(Prenotazione p) async {
    final data = p.toJson();
    data.remove('id_prenotazione'); 
    await _supabase.from('prenotazioni').insert(data);
  }

  Future<void> confermaPrenotazione(int id) async {
    await _supabase
        .from('prenotazioni')
        .update({'stato': StatoPrenotazione.confermata.name})
        .eq('id_prenotazione', id);
  }

  Future<void> annullaPrenotazione(int id) async {
    await _supabase
        .from('prenotazioni')
        .update({'stato': StatoPrenotazione.annullata.name})
        .eq('id_prenotazione', id);
  }

  Future<void> completaPrenotazione(int id) async {
    await _supabase
        .from('prenotazioni')
        .update({'stato': StatoPrenotazione.completata.name})
        .eq('id_prenotazione', id);
  }

  // Sostituisce la logica di controllo sovrapposizioni
  Future<bool> validaDisponibilita(String targa, DateTime inizio, DateTime fine) async {
    final response = await _supabase
        .from('prenotazioni')
        .select()
        .eq('targa', targa)
        .neq('stato', StatoPrenotazione.annullata.name);

    final esistenti = (response as List).map((json) => Prenotazione.fromJson(json)).toList();

    for (var p in esistenti) {
      if (inizio.isBefore(p.dataFine) && fine.isAfter(p.dataInizio)) {
        return false; // C'è sovrapposizione
      }
    }
    return true;
  }

  // Metodo per aggiornare automaticamente gli stati (es. da confermata ad attiva se oggi è la data d'inizio)
  Future<void> aggiornaStatiPrenotazioni() async {
    final ora = DateTime.now().toIso8601String();
    
    // Attiva quelle confermate che iniziano ora
    await _supabase
        .from('prenotazioni')
        .update({'stato': StatoPrenotazione.attiva.name})
        .eq('stato', StatoPrenotazione.confermata.name)
        .lte('data_inizio', ora);

    // Potresti aggiungere logica per completare quelle passate
  }
}