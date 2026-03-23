import 'package:fleetmanager/models/enums/tipo_prenotazione.dart';
import 'package:fleetmanager/models/manutenzione.dart';
import 'package:fleetmanager/models/enums/ruolo_utente.dart'; // Assicurati che sia importato
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/veicolo.dart';
import '../models/prenotazione.dart';
import '../models/utente.dart';
import '../models/notifica.dart';
import '../models/enums/stato_veicolo.dart';
import '../models/enums/stato_prenotazione.dart';
import '../models/enums/tipo_manutenzione.dart';
import '../services/auth_service.dart';
import '../services/prenotazione_service.dart';
import '../services/manutenzione_service.dart';
import '../services/notifica_service.dart';
import '../services/veicolo_service.dart';

class FleetProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  final VeicoloService _veicoloService = VeicoloService();
  final PrenotazioneService _prenotazioneService = PrenotazioneService();
  final ManutenzioneService _manutenzioneService = ManutenzioneService();
  final NotificaService _notificaService = NotificaService();

  List<Veicolo> _veicoli = [];
  List<Prenotazione> _prenotazioni = [];
  List<Manutenzione> _manutenzioni = [];
  List<Utente> _utenti = [];
  List<Notifica> _notifiche = [];
  Utente? _utenteLoggato;
  bool _isLoading = false;

  // Getter
  List<Veicolo> get veicoli => _veicoli;
  List<Prenotazione> get prenotazioni => _prenotazioni;
  List<Manutenzione> get manutenzioni => _manutenzioni;
  List<Notifica> get notifiche => _notifiche;
  Utente? get utenteLoggato => _utenteLoggato;
  List<Utente> get utenti => _utenti;
  bool get isLoading => _isLoading;

  /// HELPER: Recupera l'ID del Manager dinamicamente
  int get _managerId {
    try {
      return _utenti
          .firstWhere((u) => u.ruoloUtente == RuoloUtente.manager)
          .idUtente;
    } catch (e) {
      // Fallback: Se non trova un manager, usa l'ID dell'utente loggato o un default sicuro
      return _utenteLoggato?.idUtente ?? 1;
    }
  }

  /// --- INIZIALIZZAZIONE ---
  Future<void> inizializzaDati() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _prenotazioneService.aggiornaStatiPrenotazioni();

      final risultati = await Future.wait([
        _veicoloService.fetchAllVeicoli(),
        _prenotazioneService.fetchPrenotazioni(),
        _authService.getTuttiUtenti(),
        _manutenzioneService.fetchTutte(),
        if (_utenteLoggato != null)
          _notificaService.fetchMieNotifiche(_utenteLoggato!.idUtente)
        else
          Future.value(<Notifica>[]),
      ]);

      _veicoli = risultati[0] as List<Veicolo>;
      _prenotazioni = risultati[1] as List<Prenotazione>;
      _utenti = risultati[2] as List<Utente>;
      _manutenzioni = risultati[3] as List<Manutenzione>;
      _notifiche = risultati[4] as List<Notifica>;

      debugPrint("✅ PROVIDER: Dati e Notifiche sincronizzati.");
    } catch (e) {
      debugPrint("❌ PROVIDER ERROR: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// --- LOGICA AUTENTICAZIONE ---
  Future<bool> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();
    try {
      final user = await _authService.login(email, password);
      if (user != null) {
        _utenteLoggato = user;
        await inizializzaDati();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("❌ Errore login: $e");
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void logout() {
    _utenteLoggato = null;
    _veicoli = [];
    _prenotazioni = [];
    _manutenzioni = [];
    _notifiche = [];
    notifyListeners();
  }

  /// --- LOGICA NOTIFICHE ---
  Future<void> segnaNotificaLetta(int id) async {
    try {
      await _notificaService.segnaLetta(id);
      _notifiche.removeWhere((n) => n.idNotifica == id);
      notifyListeners();
    } catch (e) {
      debugPrint("❌ Errore segna letta: $e");
    }
  }

  Future<void> segnaTutteNotificheComeLette() async {
    if (_utenteLoggato == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      // 1. Aggiorna Supabase: setta letta = true per tutte le notifiche dell'utente loggato
      await Supabase.instance.client
          .from('notifiche')
          .update({'letta': true})
          .eq('id_utente', _utenteLoggato!.idUtente)
          .eq('letta', false); // Solo quelle non ancora lette

      // 2. Aggiorna la lista locale (puoi ricaricare i dati o modificarli in memoria)
      await inizializzaDati();

      debugPrint("✅ Tutte le notifiche segnate come lette.");
    } catch (e) {
      debugPrint("❌ Errore segna tutte come lette: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> eliminaNotifica(int id) async {
    try {
      await _notificaService.eliminaNotifica(id);
      _notifiche.removeWhere((n) => n.idNotifica == id);
      notifyListeners();
    } catch (e) {
      debugPrint("❌ Errore eliminazione notifica: $e");
    }
  }

  Future<void> eliminaTutteLeNotifiche() async {
    if (_utenteLoggato == null) return;
    try {
      await _notificaService.svuotaNotifiche(_utenteLoggato!.idUtente);
      _notifiche.clear();
      notifyListeners();
    } catch (e) {
      debugPrint("❌ Errore svuota notifiche: $e");
    }
  }

  /// --- LOGICA PRENOTAZIONI ---
  Future<void> creaPrenotazione(
      Utente driver, Veicolo veicolo, DateTime inizio, DateTime fine) async {
    if (driver.patente == null || driver.patente == 'Da inserire') {
      throw Exception('L\'utente non ha una patente valida registrata.');
    }

    _isLoading = true;
    notifyListeners();
    try {
      if (!isVeicoloDisponibile(veicolo.targa, inizio, fine)) {
        throw Exception(
            'Il veicolo è già impegnato (Manutenzione o Prenotazione).');
      }

      Prenotazione p = Prenotazione(
        idPrenotazione: 0,
        dataInizio: inizio,
        dataFine: fine,
        statoPrenotazione: StatoPrenotazione.richiesta,
        tipoPrenotazione: TipoPrenotazione.utente,
        idUtente: driver.idUtente,
        targa: veicolo.targa,
      );

      await _prenotazioneService.creaPrenotazione(p);

      // NOTIFICA AL MANAGER (ID Recuperato dinamicamente)
      await _notificaService.notificaRichiestaPrenotazione(_managerId,
          "${driver.nome} ${driver.cognome}", veicolo.targa, inizio, fine);
      await inizializzaDati();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> confermaPrenotazione(int id) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _prenotazioneService.confermaPrenotazione(id);

      final p =
          _prenotazioni.firstWhere((element) => element.idPrenotazione == id);
      await _notificaService.notificaConfermaPrenotazione(
          p.idUtente, p.targa, p.dataInizio, p.dataFine);

      await inizializzaDati();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> annullaPrenotazione(int id) async {
    _isLoading = true;
    notifyListeners();
    try {
      final p =
          _prenotazioni.firstWhere((element) => element.idPrenotazione == id);
      await _prenotazioneService.annullaPrenotazione(id);

      if (_utenteLoggato?.ruoloUtente == RuoloUtente.manager) {
        // Il manager rifiuta -> notifica al driver
        await _notificaService.notificaRifiutoPrenotazione(
            p.idUtente, p.targa, p.dataInizio, p.dataFine);
      } else {
        // Il driver annulla -> notifica al manager
        await _notificaService.notificaAnnullamentoPrenotazioneDaDriver(
            _managerId, p.idUtente, p.targa);
      }

      await inizializzaDati();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// --- LOGICA MANUTENZIONI ---
  Future<void> programmareManutenzione(Veicolo veicolo, DateTime inizio,
      TipoManutenzione tipo, String descrizione,
      {required String luogo}) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _manutenzioneService.registraIntervento(Manutenzione(
        idManutenzione: 0,
        data: inizio,
        tipoManutenzione: tipo,
        descrizione: descrizione,
        targa: veicolo.targa,
        luogo: luogo,
      ));

      bool deveBloccareSubito = tipo == TipoManutenzione.straordinaria ||
          inizio.isBefore(DateTime.now().add(const Duration(minutes: 10)));

      if (deveBloccareSubito) {
        await _veicoloService.updateStatoVeicolo(
            veicolo.targa, StatoVeicolo.inManutenzione);

        // Notifica il manager dell'intervento avviato
        await _notificaService.notificaInterventoStraordinario(
            _managerId, veicolo.targa);
      }

      final colpite = _prenotazioni.where((p) =>
          p.targa == veicolo.targa &&
          p.statoPrenotazione == StatoPrenotazione.confermata &&
          p.dataInizio.isAfter(inizio.subtract(const Duration(minutes: 30))));

      for (var pr in colpite) {
        await _notificaService.notificaRifiutoPrenotazione(
            pr.idUtente, veicolo.targa, pr.dataInizio, pr.dataFine);
      }

      await inizializzaDati();
    } catch (e) {
      debugPrint("❌ Errore manutenzione: $e");
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> chiudiManutenzione(int idManutenzione, String targa,
      {int? nuoviKm}) async {
    _isLoading = true;
    notifyListeners();
    try {
      int kmFinali = nuoviKm ?? _veicoli.firstWhere((v) => v.targa == targa).km;
      await _manutenzioneService.chiudiIntervento(
          idManutenzione, kmFinali, targa);
      await inizializzaDati();
    } catch (e) {
      debugPrint("❌ Errore chiusura: $e");
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// --- DISPONIBILITÀ INTELLIGENTE ---
  bool isVeicoloDisponibile(
      String targa, DateTime inizioReq, DateTime fineReq) {
    final v = _veicoli.firstWhere((v) => v.targa == targa);
    if (v.statoVeicolo == StatoVeicolo.inManutenzione) return false;

    final haM = _manutenzioni.any((m) {
      if (m.targa != targa || m.oraFine != null) return false;
      DateTime fineM = m.data.add(const Duration(hours: 8));
      return inizioReq.isBefore(fineM) && fineReq.isAfter(m.data);
    });
    if (haM) return false;

    return !_prenotazioni.any((p) =>
        p.targa == targa &&
        p.statoPrenotazione == StatoPrenotazione.confermata &&
        inizioReq.isBefore(p.dataFine) &&
        fineReq.isAfter(p.dataInizio));
  }

  /// --- LOGICA UTENTI E VEICOLI (CRUD) ---
  Future<void> aggiungiNuovoUtente(
      {required String email,
      required String passwordScelta,
      required String nome,
      required String cognome,
      required String ruolo,
      String? patente}) async {
    _isLoading = true;
    notifyListeners();
    try {
      final authRes = await Supabase.instance.client.auth
          .signUp(email: email.trim(), password: passwordScelta);
      if (authRes.user != null) {
        await Supabase.instance.client.from('utenti').insert({
          'email': email.trim().toLowerCase(),
          'nome': nome.trim(),
          'cognome': cognome.trim(),
          'ruolo': ruolo,
          'patente': patente ?? 'Da inserire',
        });
        await inizializzaDati();
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> aggiungiNuovoVeicolo(
      {required String targa,
      required String marca,
      required String modello,
      required String tipo,
      required String anno,
      String? kmAttuali}) async {
    _isLoading = true;
    notifyListeners();
    try {
      await Supabase.instance.client.from('veicoli').insert({
        'targa': targa.trim().toUpperCase(),
        'marca': marca.trim(),
        'modello': modello.trim(),
        'tipo': tipo,
        'stato': 'disponibile',
        'km': int.tryParse(kmAttuali ?? '0') ?? 0,
        'anno_immatricolazione': int.tryParse(anno) ?? DateTime.now().year,
      });
      await inizializzaDati();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> eliminaUtente(int id) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _authService.eliminaUtente(id);
      await inizializzaDati();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> eliminaVeicolo(String targa) async {
    _isLoading = true;
    notifyListeners();
    try {
      await Supabase.instance.client
          .from('veicoli')
          .delete()
          .eq('targa', targa);
      await inizializzaDati();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> modificaPrenotazione(
      int idPrenotazione, DateTime nuovoInizio, DateTime nuovaFine) async {
    _isLoading = true;
    notifyListeners();

    try {
      // 1. Recuperiamo la prenotazione attuale
      final p = _prenotazioni
          .firstWhere((element) => element.idPrenotazione == idPrenotazione);

      // --- AGGIUNTA: Recuperiamo l'oggetto Utente per avere il Nome ---
      final driver = _utenti.firstWhere((u) => u.idUtente == p.idUtente);
      final String nomeCompleto = "${driver.nome} ${driver.cognome}";

      // 2. Controllo disponibilità
      if (!isVeicoloDisponibilePerModifica(
          p.targa, nuovoInizio, nuovaFine, idPrenotazione)) {
        throw Exception(
            'Il veicolo non è disponibile per queste nuove date/orari.');
      }

      // 3. Update su Supabase
      await Supabase.instance.client.from('prenotazioni').update({
        'data_inizio': nuovoInizio.toIso8601String(),
        'data_fine': nuovaFine.toIso8601String(),
        'stato': 'richiesta',
      }).eq('id_prenotazione', idPrenotazione);

      // 4. Notifica al Manager
      // USIAMO nomeCompleto (String) invece di p.idUtente (int)
      await _notificaService.notificaRichiestaPrenotazione(
          _managerId, nomeCompleto, p.targa, nuovoInizio, nuovaFine);

      await inizializzaDati();
    } catch (e) {
      debugPrint("❌ Errore durante la modifica: $e");
      rethrow; // Importante per far vedere l'errore nella UI
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

// Helper necessario per non andare in conflitto con la prenotazione che stiamo modificando
  bool isVeicoloDisponibilePerModifica(
      String targa, DateTime inizio, DateTime fine, int idDaEscludere) {
    // Simile a isVeicoloDisponibile ma aggiunge .where((p) => p.idPrenotazione != idDaEscludere)
    return !_prenotazioni.any((p) =>
        p.targa == targa &&
        p.idPrenotazione != idDaEscludere &&
        p.statoPrenotazione != StatoPrenotazione.annullata &&
        inizio.isBefore(p.dataFine) &&
        fine.isAfter(p.dataInizio));
  }
}
