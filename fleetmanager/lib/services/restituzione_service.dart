import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
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

    // --- 1. LOGICA CARICAMENTO FOTO ---
if (fotoScontrino != null) {
  final path = 'scontrini/pre_$idPrenotazione.jpg';
  if (kIsWeb) {
    final bytes = await fotoScontrino.readAsBytes();
    await _supabase.storage.from('restituzioni').uploadBinary(path, bytes,
        fileOptions: const FileOptions(cacheControl: '3600', upsert: true));
  } else {
    final file = File(fotoScontrino.path);
    if (await file.exists()) {
      await _supabase.storage.from('restituzioni').upload(
        path, 
        file,
        fileOptions: const FileOptions(upsert: true), // Upsert fondamentale per Windows
      );
    }
  }
  urlScontrino = _supabase.storage.from('restituzioni').getPublicUrl(path);
}

    if (fotoDanni != null) {
      final path = 'danni/pre_$idPrenotazione.jpg';
      if (kIsWeb) {
        final bytes = await fotoDanni.readAsBytes();
        await _supabase.storage.from('restituzioni').uploadBinary(path, bytes,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: true));
      } else {
        await _supabase.storage
            .from('restituzioni')
            .upload(path, File(fotoDanni.path));
      }
      urlDanni = _supabase.storage.from('restituzioni').getPublicUrl(path);
    }

    // --- 2. SALVATAGGIO DATI SU TABELLA 'restituzioni' ---
    await _supabase.from('restituzioni').insert({
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
      'data_restituzione':
          DateTime.now().toIso8601String(), // Salviamo l'istante reale
    });

    // --- 3. AGGIORNAMENTO VEICOLO ---
    await _supabase.from('veicoli').update({
      'km': kmFinali,
      'stato': 'disponibile',
    }).eq('targa', targa);

    // --- 4. CHIUSURA PRENOTAZIONE (IL PUNTO CRITICO) ---
    await _supabase.from('prenotazioni').update({
      'stato': 'completata',
      // Sovrascriviamo la data di fine prevista con quella reale
      // Questo "libera" lo slot temporale per il FleetProvider
      'data_fine': DateTime.now().toIso8601String(),
    }).eq('id_prenotazione', idPrenotazione);
  }
}
