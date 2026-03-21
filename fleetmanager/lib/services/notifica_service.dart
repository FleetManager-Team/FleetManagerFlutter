import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/notifica.dart';
import '../models/enums/tipo_notifica.dart';

class NotificaService {
  final _supabase = Supabase.instance.client;

  Future<List<Notifica>> fetchMieNotifiche(int idUtente) async {
    final response = await _supabase
        .from('notifiche')
        .select()
        .eq('id_utente', idUtente)
        .order('data_invio', ascending: false);
    
    return (response as List).map((json) => Notifica.fromJson(json)).toList();
  }

  Future<void> segnaLetta(int id) async {
    await _supabase
        .from('notifiche')
        .update({'letta': true})
        .eq('id_notifica', id);
  }

  // Metodo generico interno per creare notifiche (sostituisce i vari post del backend)
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

  Future<void> inviaNotificaScadenza(int idScadenza, String targa, String tipoScadenza, DateTime data) async {
    await _creaNotifica(
      idUtente: 1, // Nota: Qui andrebbe l'ID del Manager o del destinatario
      messaggio: 'Scadenza $tipoScadenza per il veicolo $targa il ${data.day}/${data.month}',
      tipo: TipoNotifica.scadenza,
      idScadenza: idScadenza,
    );
  }

  Future<void> notificaRichiestaPrenotazione(int idDriver, String targa, DateTime dataInizio, DateTime dataFine) async {
    await _creaNotifica(
      idUtente: 1, // Destinato al Manager
      messaggio: 'Nuova richiesta prenotazione: Driver $idDriver per $targa dal ${dataInizio.day}/${dataInizio.month}',
      tipo: TipoNotifica.info,
    );
  }

  Future<void> notificaConfermaPrenotazione(int idDriver, String targa, DateTime dataInizio, DateTime dataFine) async {
    await _creaNotifica(
      idUtente: idDriver,
      messaggio: 'La tua prenotazione per $targa è stata confermata.',
      tipo: TipoNotifica.info,
    );
  }

  Future<void> notificaRifiutoPrenotazione(int idDriver, String targa, DateTime dataInizio, DateTime dataFine) async {
    await _creaNotifica(
      idUtente: idDriver,
      messaggio: 'La tua prenotazione per $targa è stata rifiutata.',
      tipo: TipoNotifica.alert,
    );
  }

  Future<void> notificaManutenzioneProgrammata(int idUtente, String targa, DateTime data) async {
    await _creaNotifica(
      idUtente: idUtente,
      messaggio: 'Manutenzione programmata per $targa il ${data.day}/${data.month}.',
      tipo: TipoNotifica.manutenzione,
    );
  }

  Future<void> notificaAnnullamentoPrenotazioneDaDriver(int idDriver, String targa) async {
    await _creaNotifica(
      idUtente: 1, // Destinato al Manager
      messaggio: 'Il driver $idDriver ha annullato la prenotazione per $targa.',
      tipo: TipoNotifica.alert,
    );
  }

  Future<void> notificaInterventoStraordinario(int idUtente, String targa) async {
    await _creaNotifica(
      idUtente: 1, // Destinato al Manager
      messaggio: 'Segnalato intervento straordinario per il veicolo $targa.',
      tipo: TipoNotifica.manutenzione,
    );
  }
}