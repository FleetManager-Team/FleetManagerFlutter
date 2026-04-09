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
    // --- Campi Emergenza ---
    bool isEmergenza = false,
    String? noteEmergenza,
    String? posizioneEmergenza,
    // --- Dati Economici/Danni ---
    double? litri,
    double? euro,
    double? euroPedaggi,
    String? descDanni,
    XFile? fotoScontrino,
    XFile? fotoDanni,
    XFile? fotoPedaggio,
  }) async {
    try {
      // 1. Caricamento Immagini (in parallelo per velocizzare)
      final immagini = await Future.wait([
        _uploadImage(fotoScontrino, 'scontrini', idPrenotazione),
        _uploadImage(fotoDanni, 'danni', idPrenotazione),
        _uploadImage(fotoPedaggio, 'pedaggi', idPrenotazione),
      ]);

      final String? urlScontrino = immagini[0];
      final String? urlDanni = immagini[1];
      final String? urlPedaggio = immagini[2];

      final oraAttuale = DateTime.now().toUtc().toIso8601String();

      // 2. Aggiornamento Tabella Restituzioni (con UPSERT)
      // Qui salviamo kmFinali (che sarà 0 in caso di emergenza) per lo storico
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
        'is_emergenza': isEmergenza,
        'note_emergenza': noteEmergenza,
        'posizione_emergenza': posizioneEmergenza,
      }, onConflict: 'id_prenotazione');

      // 3. Aggiornamento Stato Veicolo (LOGICA CONDIZIONALE)
      // Se c'è un'emergenza o danni gravi, lo stato va in manutenzione
      final nuovoStatoVeicolo =
          (isEmergenza || haDanni) ? 'fuoriServizio' : 'disponibile';

      final Map<String, dynamic> updateVeicolo = {
        'stato': nuovoStatoVeicolo,
      };

      // CRITICO: Aggiorniamo i km del veicolo solo se NON è un'emergenza.
      // Se è un'emergenza, il veicolo mantiene i suoi chilometri attuali nel DB.
      if (!isEmergenza) {
        updateVeicolo['km'] = kmFinali;
      }

      await _supabase.from('veicoli').update(updateVeicolo).eq('targa', targa);

      // 4. Chiusura Prenotazione
      await _supabase.from('prenotazioni').update({
        'stato': 'completata',
        'data_fine': oraAttuale,
      }).eq('id_prenotazione', idPrenotazione);
    } catch (e) {
      print("Errore durante completaRestituzione: $e");
      rethrow;
    }
  }

  /// Funzione helper per il caricamento immagini su Storage
  Future<String?> _uploadImage(
      XFile? file, String folder, int idPrenotazione) async {
    if (file == null) return null;

    try {
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final String fileName = 'res_${idPrenotazione}_$timestamp.jpg';
      final String path = '$folder/$fileName';

      final bytes = await file.readAsBytes();

      await _supabase.storage.from('restituzioni').uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
          );

      return _supabase.storage.from('restituzioni').getPublicUrl(path);
    } catch (e) {
      print("Errore caricamento immagine in $folder: $e");
      return null;
    }
  }
}
