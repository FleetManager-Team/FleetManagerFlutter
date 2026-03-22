import 'package:fleetmanager/models/enums/tipo_manutenzione.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/manutenzione.dart';

class ManutenzioneService {
  final _supabase = Supabase.instance.client;

  Future<void> registraIntervento(Manutenzione m) async {
    final data = m.toJson();
    data.remove('id_manutenzione');
    await _supabase.from('manutenzioni').insert(data);
  }

  Future<void> chiudiIntervento(int id, int kmFinali, String targa) async {
    // 1. Aggiorna la riga della manutenzione mettendo la data di fine
    await _supabase.from('manutenzioni').update({
      'ora_fine': DateTime.now().toIso8601String(),
      'km_uscita': kmFinali,
    }).eq('id_manutenzione', id);

    // 2. Aggiorna il veicolo: torna disponibile e ha i nuovi KM
    await _supabase.from('veicoli').update({
      'stato': 'disponibile',
      'km': kmFinali,
    }).eq('targa', targa);
  }

  Future<List<Manutenzione>> fetchTutte() async {
    try {
      final response = await _supabase
          .from('manutenzioni')
          .select()
          .order('data', ascending: false); // Ordina dalle più recenti

      // Trasforma la lista di Map in una lista di oggetti Manutenzione
      final List<dynamic> data = response;
      return data.map((json) => Manutenzione.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Errore nel recupero delle manutenzioni: $e');
    }
  }

  Future<void> segnalareInterventoStraordinario(
      String targa, String descrizione) async {
    try {
      // A. Crea il record dell'intervento
      await _supabase.from('manutenzioni').insert({
        'targa': targa,
        'descrizione': descrizione,
        'data': DateTime.now().toIso8601String(),
        'tipo_manutenzione': TipoManutenzione.straordinaria.name,
        'ora_inizio': DateTime.now().toIso8601String(),
        // ora_fine resta null finché non viene chiusa
      });

      // B. Cambia lo stato del veicolo in 'in_manutenzione'
      await _supabase.from('veicoli').update({
        'stato_veicolo': 'inManutenzione'
      }) // Assicurati che il nome colonna sia corretto
          .eq('targa', targa);
    } catch (e) {
      throw Exception('Errore nel database durante la segnalazione: $e');
    }
  }
}
