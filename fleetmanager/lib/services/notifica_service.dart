import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/notifica.dart';
import '../models/enums/tipo_notifica.dart';

class NotificaService {
  final SupabaseClient _supabase;

  NotificaService({SupabaseClient? supabaseClient})
      : _supabase = supabaseClient ?? Supabase.instance.client;

  Future<List<Notifica>> fetchMieNotifiche(int idUtente) async {
    final response = await _supabase
        .from('notifiche')
        .select()
        .eq('id_utente', idUtente)
        .order('data_invio', ascending: false);

    final data = response as List<dynamic>;
    return data.map((json) => Notifica.fromJson(json)).toList();
  }

  Future<void> segnaLetta(int id) async {
    await _supabase
        .from('notifiche')
        .update({'letta': true}).eq('id_notifica', id);
  }

  Future<void> _creaNotifica({
    required int idUtente,
    required String messaggio,
    required TipoNotifica tipo,
    int? idScadenza,
  }) async {
    await _supabase.from('notifiche').insert({
      'id_utente': idUtente,
      'messaggio': messaggio,
      'tipo': tipo.name,
      'data_invio': DateTime.now().toIso8601String(),
      'letta': false,
      'id_scadenza': idScadenza,
    });
  }

  // --- ORA TUTTI I METODI ACCETTANO L'ID DEL DESTINATARIO ---

  Future<void> inviaNotificaScadenza(int idManager, int idScadenza,
      String targa, String tipoScadenza, DateTime data) async {
    await _creaNotifica(
      idUtente: idManager,
      messaggio:
          'Scadenza $tipoScadenza per il veicolo $targa il ${data.day}/${data.month}',
      tipo: TipoNotifica.scadenza,
      idScadenza: idScadenza,
    );
  }

  Future<void> notificaRichiestaPrenotazione(int idUtenteDestinatario,
      String nomeDriver, String targa, DateTime inizio, DateTime fine) async {
    await _creaNotifica(
      idUtente: idUtenteDestinatario,
      messaggio: "Nuova richiesta da $nomeDriver per l'auto $targa",
      tipo: TipoNotifica.info,
    );
  }

  Future<void> notificaConfermaPrenotazione(int idDriver, String targa,
      DateTime dataInizio, DateTime dataFine) async {
    await _creaNotifica(
      idUtente: idDriver,
      messaggio: 'La tua prenotazione per $targa è stata confermata.',
      tipo: TipoNotifica.info,
    );
  }

  Future<void> notificaPrenotazioneAttivata(int idDriver, String targa,
      DateTime dataInizio, DateTime dataFine) async {
    await _creaNotifica(
      idUtente: idDriver,
      messaggio: 'La tua prenotazione per $targa è ora attiva. Puoi ritirare il veicolo.',
      tipo: TipoNotifica.info,
    );
  }

  Future<void> notificaRifiutoPrenotazione(int idDriver, String targa,
      DateTime dataInizio, DateTime dataFine) async {
    await _creaNotifica(
      idUtente: idDriver,
      messaggio: 'La tua prenotazione per $targa è stata rifiutata.',
      tipo: TipoNotifica.alert,
    );
  }

  Future<void> notificaManutenzioneProgrammata(
      int idUtente, String targa, DateTime data) async {
    await _creaNotifica(
      idUtente: idUtente,
      messaggio:
          'Manutenzione programmata per $targa il ${data.day}/${data.month}.',
      tipo: TipoNotifica.manutenzione,
    );
  }

  Future<void> notificaManutenzioneCompletata(int idManager, String targa) async {
    await _creaNotifica(
      idUtente: idManager,
      messaggio: 'Manutenzione completata per il veicolo $targa.',
      tipo: TipoNotifica.info,
    );
  }

  Future<void> notificaPrenotazioneCompletata(int idDriver, String targa, bool isEmergenza) async {
    final tipo = isEmergenza ? 'segnalazione SOS' : 'restituzione';
    await _creaNotifica(
      idUtente: idDriver,
      messaggio: 'La $tipo per il veicolo $targa è stata completata con successo.',
      tipo: TipoNotifica.info,
    );
  }

  Future<void> notificaRestituzioneVeicolo(int idManager, String nomeDriver, String cognomeDriver, String targa, bool isEmergenza) async {
    final tipo = isEmergenza ? 'segnalazione SOS' : 'restituzione';
    await _creaNotifica(
      idUtente: idManager,
      messaggio: '$tipo ricevuta da $nomeDriver $cognomeDriver per il veicolo $targa.',
      tipo: TipoNotifica.info,
    );
  }

  Future<void> notificaCheckupRichiesto(int idDriver, String targa) async {
    await _creaNotifica(
      idUtente: idDriver,
      messaggio: 'È richiesto un check-up iniziale per il veicolo $targa prima del ritiro.',
      tipo: TipoNotifica.info,
    );
  }

  Future<void> notificaAnnullamentoPrenotazioneDaDriver(
      int idManager, int idDriver, String targa) async {
    await _creaNotifica(
      idUtente: idManager,
      messaggio: 'Il driver $idDriver ha annullato la prenotazione per $targa.',
      tipo: TipoNotifica.alert,
    );
  }

  Future<void> notificaInterventoStraordinario(
      int idManager, String targa) async {
    await _creaNotifica(
      idUtente: idManager,
      messaggio: 'Segnalato intervento straordinario per il veicolo $targa.',
      tipo: TipoNotifica.manutenzione,
    );
  }

  Future<void> eliminaNotifica(int id) async {
    await _supabase.from('notifiche').delete().eq('id_notifica', id);
  }

  Future<void> svuotaNotifiche(int idUtente) async {
    await _supabase.from('notifiche').delete().eq('id_utente', idUtente);
  }
}
