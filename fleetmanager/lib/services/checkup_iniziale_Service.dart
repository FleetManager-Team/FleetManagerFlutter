import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';

class CheckupService {
  final SupabaseClient _supabase;

  CheckupService({SupabaseClient? supabaseClient})
      : _supabase = supabaseClient ?? Supabase.instance.client;

  Future<void> inviaCheckupCompleto({
    required int idPrenotazione,
    required String targa,
    required List<XFile?> fotoPerimetrali, // [Fronte, Retro, Dx, Sx]
    required bool luci,
    required bool gomme,
    required bool interni,
    String? note,
    required Uint8List? firmaBytes,
  }) async {
    // 1. Verifica autenticazione
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception("Utente non autenticato. Effettua il login.");
    }

    try {
      // 2. Caricamento Immagini Perimetrali (in parallelo come nel RestituzioneService)
      // Usiamo nomi specifici per le sottocartelle per tenere ordinato lo storage
      final immagini = await Future.wait([
        _uploadImage(fotoPerimetrali[0], 'fronte', idPrenotazione, targa),
        _uploadImage(fotoPerimetrali[1], 'retro', idPrenotazione, targa),
        _uploadImage(fotoPerimetrali[2], 'dx', idPrenotazione, targa),
        _uploadImage(fotoPerimetrali[3], 'sx', idPrenotazione, targa),
      ]);

      final String? urlFronte = immagini[0];
      final String? urlRetro = immagini[1];
      final String? urlDx = immagini[2];
      final String? urlSx = immagini[3];

      // 3. Upload della Firma (gestita separatamente perché sono già bytes)
      String? urlFirma;
      if (firmaBytes != null && firmaBytes.isNotEmpty) {
        final String timestamp =
            DateTime.now().millisecondsSinceEpoch.toString();
        final String firmaPath =
            '$targa/firma_${idPrenotazione}_$timestamp.png';

        await _supabase.storage.from('veicoli_checkups').uploadBinary(
              firmaPath,
              firmaBytes,
              fileOptions:
                  const FileOptions(contentType: 'image/png', upsert: true),
            );
        urlFirma =
            _supabase.storage.from('veicoli_checkups').getPublicUrl(firmaPath);
      }

      // 4. Inserimento record nel Database (Tabella 'checkups')
      // Utilizziamo l'upsert come nel tuo esempio per evitare errori di duplicazione
      await _supabase.from('checkups').upsert({
        'id_prenotazione': idPrenotazione,
        'targa': targa,
        'driver_id': user.id,
        'url_foto_fronte': urlFronte,
        'url_foto_retro': urlRetro,
        'url_foto_dx': urlDx,
        'url_foto_sx': urlSx,
        'luci_ok': luci,
        'gomme_ok': gomme,
        'interni_ok': interni,
        'note_danni': note,
        'url_firma': urlFirma,
      }, onConflict: 'id_prenotazione');
    } catch (e) {
      rethrow;
    }
  }

  Future<String?> _uploadImage(
      XFile? file, String folder, int idPrenotazione, String targa) async {
    if (file == null) return null;

    try {
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      // Organizziamo per targa/cartella/file per un database ordinato
      final String fileName = '${folder}_${idPrenotazione}_$timestamp.jpg';
      final String path = '$targa/$fileName';

      // Leggiamo i bytes (Metodo universale Web/Mobile)
      final bytes = await file.readAsBytes();

      await _supabase.storage.from('veicoli_checkups').uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
          );

      return _supabase.storage.from('veicoli_checkups').getPublicUrl(path);
    } catch (e) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getStoricoCheckup({String? targa}) async {
    try {
      var query = _supabase.from('checkups').select('*, prenotazioni(targa)');

      if (targa != null && targa.isNotEmpty) {
        query = query.eq('targa', targa);
      }

      final response = await query.order('data_check', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint("Errore query: $e");
      return [];
    }
  }
}
