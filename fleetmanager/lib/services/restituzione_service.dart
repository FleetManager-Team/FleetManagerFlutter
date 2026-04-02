import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';

class RestituzioneService {
  final _supabase = Supabase.instance.client;

  Future<void> completaRestituzione({
    required int idPrenotazione,
    required String targa,
    required int kmFinali,
    required double livelloCarburante,
    required bool rifornimento,
    required bool haDanni,
    double? litri,
    double? euro,
    String? descDanni,
    XFile? fotoScontrino,
    XFile? fotoDanni,
  }) async {
    String? urlScontrino;
    String? urlDanni;

    // --- 1. LOGICA CARICAMENTO FOTO SCONTRINO ---
    if (fotoScontrino != null) {
      final path = 'scontrini/pre_$idPrenotazione.jpg';

      // Leggiamo i bytes: questo metodo funziona su TUTTE le piattaforme
      final bytes = await fotoScontrino.readAsBytes();

      // Usiamo uploadBinary o upload passandogli i bytes direttamente
      await _supabase.storage.from('restituzioni').uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
          );

      urlScontrino = _supabase.storage.from('restituzioni').getPublicUrl(path);
    }

    // --- 2. LOGICA CARICAMENTO FOTO DANNI ---
    if (fotoDanni != null) {
      final path = 'danni/pre_$idPrenotazione.jpg';

      final bytes = await fotoDanni.readAsBytes();

      await _supabase.storage.from('restituzioni').uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
          );

      urlDanni = _supabase.storage.from('restituzioni').getPublicUrl(path);
    }

    // --- 3. AGGIORNAMENTO DATABASE ---
    await _supabase.from('restituzioni').upsert({
      'id_prenotazione': idPrenotazione,
      'km_finali': kmFinali,
      'rifornimento_effettuato': rifornimento,
      'litri_carburante': litri,
      'importo_euro': euro,
      'url_scontrino': urlScontrino,
      'livello_carburante': livelloCarburante,
      'danni_presenti': haDanni,
      'descrizione_danni': descDanni,
      'url_foto_danni': urlDanni,
      'data_restituzione': DateTime.now().toIso8601String(),
    });

    // --- 4. AGGIORNAMENTO VEICOLO ---
    await _supabase.from('veicoli').update({
      'km': kmFinali,
      'stato': 'disponibile',
    }).eq('targa', targa);

    // --- 5. CHIUSURA PRENOTAZIONE ---
    await _supabase.from('prenotazioni').update({
      'stato': 'completata',
      'data_fine': DateTime.now().toIso8601String(),
    }).eq('id_prenotazione', idPrenotazione);
  }
}
