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
    required bool haPedaggi,
    // --- Nuovi campi per segnalazione straordinaria ---
    bool isEmergenza = false,
    String? noteEmergenza,
    String? posizioneEmergenza,
    // --------------------------------------------------
    double? litri,
    double? euro,
    double? euroPedaggi,
    String? descDanni,
    XFile? fotoScontrino,
    XFile? fotoDanni,
    XFile? fotoPedaggio,
  }) async {
    // 1. Caricamento immagini (usando una funzione helper per pulizia)
    String? urlScontrino =
        await _uploadImage(fotoScontrino, 'scontrini', idPrenotazione);
    String? urlDanni = await _uploadImage(fotoDanni, 'danni', idPrenotazione);
    String? urlPedaggio =
        await _uploadImage(fotoPedaggio, 'pedaggi', idPrenotazione);

    final oraAttuale = DateTime.now().toIso8601String();

    // 2. Aggiornamento Database Restituzioni
    await _supabase.from('restituzioni').upsert({
      'id_prenotazione': idPrenotazione,
      'km_finali': kmFinali,
      'data_restituzione': oraAttuale,
      'livello_carburante': livelloCarburante,
      'rifornimento_effettuato': rifornimento,
      'litri_carburante': litri,
      'importo_euro': euro,
      'url_scontrino': urlScontrino,
      'ha_pedaggi': haPedaggi,
      'importo_pedaggi': euroPedaggi,
      'url_foto_pedaggio': urlPedaggio,
      'danni_presenti': haDanni,
      'descrizione_danni': descDanni,
      'url_foto_danni': urlDanni,
      // Campi emergenza
      'is_emergenza': isEmergenza,
      'note_emergenza': noteEmergenza,
      'posizione_emergenza': posizioneEmergenza,
    });

    // 3. Aggiornamento Veicolo
    // Se è un'emergenza, lo stato diventa 'manutenzione', altrimenti 'disponibile'
    await _supabase.from('veicoli').update({
      'km': kmFinali,
      'stato': isEmergenza ? 'manutenzione' : 'disponibile',
    }).eq('targa', targa);

    // 4. Chiusura Prenotazione
    await _supabase.from('prenotazioni').update({
      'stato_prenotazione':
          'completata', // Verifica se nel tuo DB è 'stato' o 'stato_prenotazione'
      'data_fine': oraAttuale,
    }).eq('id_prenotazione', idPrenotazione);
  }

  /// Funzione di supporto per evitare duplicazione codice nel caricamento immagini
  Future<String?> _uploadImage(
      XFile? file, String folder, int idPrenotazione) async {
    if (file == null) return null;

    try {
      final String fileName = 'pre_$idPrenotazione.jpg';
      final String path = '$folder/$fileName';
      final bytes = await file.readAsBytes();

      await _supabase.storage.from('restituzioni').uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
          );

      return _supabase.storage.from('restituzioni').getPublicUrl(path);
    } catch (e) {
      print("Errore caricamento immagine ($folder): $e");
      return null;
    }
  }
}
