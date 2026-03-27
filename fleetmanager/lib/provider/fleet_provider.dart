import 'package:fleetmanager/models/enums/tipo_prenotazione.dart';
import 'package:fleetmanager/models/manutenzione.dart';
import 'package:fleetmanager/models/enums/ruolo_utente.dart';
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

  /// HELPER: Recupera gli ID di TUTTI i Manager (senza duplicati)
  List<int> get _tuttiManagerIds {
    return _utenti
        .where((u) => u.ruoloUtente == RuoloUtente.manager)
        .map((u) => u.idUtente)
        .toSet()
        .toList();
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

  /// --- LOGICA NOTIFICHE (CORRETTA) ---
  Future<void> segnaNotificaLetta(int id) async {
    try {
      await _notificaService.segnaLetta(id);
      // Invece di rimuovere, aggiorniamo l'oggetto in lista
      final index = _notifiche.indexWhere((n) => n.idNotifica == id);
      if (index != -1) {
        final n = _notifiche[index];
        _notifiche[index] = Notifica(
          idNotifica: n.idNotifica,
          tipoNotifica: n.tipoNotifica,
          messaggio: n.messaggio,
          dataInvio: n.dataInvio,
          letta: true, // Ora resta visibile ma come "letta"
          idUtente: n.idUtente,
          idScadenza: n.idScadenza,
        );
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Errore segna letta: $e");
    }
  }

  Future<void> segnaTutteNotificheComeLette() async {
    if (_utenteLoggato == null) return;
    try {
      await Supabase.instance.client
          .from('notifiche')
          .update({'letta': true})
          .eq('id_utente', _utenteLoggato!.idUtente)
          .eq('letta', false);
      await inizializzaDati();
    } catch (e) {
      debugPrint("Errore: $e");
    }
  }

  Future<void> eliminaNotifica(int id) async {
    try {
      await _notificaService.eliminaNotifica(id);
      _notifiche.removeWhere((n) => n.idNotifica == id);
      notifyListeners();
    } catch (e) {
      debugPrint("Errore eliminazione: $e");
    }
  }

  Future<void> eliminaTutteLeNotifiche() async {
    if (_utenteLoggato == null) return;
    try {
      await _notificaService.svuotaNotifiche(_utenteLoggato!.idUtente);
      _notifiche.clear();
      notifyListeners();
    } catch (e) {
      debugPrint("Errore svuota: $e");
    }
  }

  /// --- LOGICA PRENOTAZIONI ---
  Future<void> creaPrenotazione(
      Utente driver, Veicolo veicolo, DateTime inizio, DateTime fine) async {
    if (driver.patente == null || driver.patente == 'Da inserire') {
      throw Exception('Patente mancante.');
    }
    _isLoading = true;
    notifyListeners();
    try {
      if (!_isSlotDisponibile(
          targa: veicolo.targa,
          idUtente: driver.idUtente,
          inizio: inizio,
          fine: fine)) {
        throw Exception('Auto o Driver occupati.');
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

      // CICLO NOTIFICHE CORRETTO
      for (var idManager in _tuttiManagerIds) {
        await _notificaService.notificaRichiestaPrenotazione(idManager,
            "${driver.nome} ${driver.cognome}", veicolo.targa, inizio, fine);
      }
      await inizializzaDati();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> confermaPrenotazione(int id) async {
    try {
      await _prenotazioneService.confermaPrenotazione(id);
      final p =
          _prenotazioni.firstWhere((element) => element.idPrenotazione == id);
      await _notificaService.notificaConfermaPrenotazione(
          p.idUtente, p.targa, p.dataInizio, p.dataFine);
      await inizializzaDati();
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  Future<void> annullaPrenotazione(int id) async {
    try {
      final p =
          _prenotazioni.firstWhere((element) => element.idPrenotazione == id);
      await _prenotazioneService.annullaPrenotazione(id);
      if (_utenteLoggato?.ruoloUtente == RuoloUtente.manager) {
        await _notificaService.notificaRifiutoPrenotazione(
            p.idUtente, p.targa, p.dataInizio, p.dataFine);
      } else {
        for (var idMan in _tuttiManagerIds) {
          await _notificaService.notificaAnnullamentoPrenotazioneDaDriver(
              idMan, p.idUtente, p.targa);
        }
      }
      await inizializzaDati();
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  /// --- MANUTENZIONI & CRUD (MANTENUTI ORIGINALI) ---
  Future<void> programmareManutenzione(Veicolo veicolo, DateTime inizio,
      TipoManutenzione tipo, String descrizione,
      {required String luogo}) async {
    try {
      await _manutenzioneService.registraIntervento(Manutenzione(
          idManutenzione: 0,
          data: inizio,
          tipoManutenzione: tipo,
          descrizione: descrizione,
          targa: veicolo.targa,
          luogo: luogo));
      if (tipo == TipoManutenzione.straordinaria ||
          inizio.isBefore(DateTime.now().add(const Duration(minutes: 10)))) {
        await _veicoloService.updateStatoVeicolo(
            veicolo.targa, StatoVeicolo.inManutenzione);
        for (var idMan in _tuttiManagerIds) {
          await _notificaService.notificaInterventoStraordinario(
              idMan, veicolo.targa);
        }
      }
      await inizializzaDati();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> chiudiManutenzione(int idManutenzione, String targa,
      {int? nuoviKm}) async {
    try {
      int kmFinali = nuoviKm ?? _veicoli.firstWhere((v) => v.targa == targa).km;
      await _manutenzioneService.chiudiIntervento(
          idManutenzione, kmFinali, targa);
      await inizializzaDati();
    } catch (e) {
      rethrow;
    }
  }

  bool isVeicoloDisponibile(
          String targa, DateTime inizioReq, DateTime fineReq) =>
      _isSlotDisponibile(
          targa: targa, idUtente: 0, inizio: inizioReq, fine: fineReq);

  Future<void> aggiungiNuovoUtente(
      {required String email,
      required String passwordScelta,
      required String nome,
      required String cognome,
      required String ruolo,
      String? patente}) async {
    try {
      final authRes = await Supabase.instance.client.auth
          .signUp(email: email.trim(), password: passwordScelta);
      if (authRes.user != null) {
        await Supabase.instance.client.from('utenti').insert({
          'email': email.trim().toLowerCase(),
          'nome': nome.trim(),
          'cognome': cognome.trim(),
          'ruolo': ruolo,
          'patente': patente ?? 'Da inserire'
        });
        await inizializzaDati();
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> aggiungiNuovoVeicolo(
      {required String targa,
      required String marca,
      required String modello,
      required String tipo,
      required String anno,
      String? kmAttuali}) async {
    try {
      await Supabase.instance.client.from('veicoli').insert({
        'targa': targa.trim().toUpperCase(),
        'marca': marca.trim(),
        'modello': modello.trim(),
        'tipo': tipo,
        'stato': 'disponibile',
        'km': int.tryParse(kmAttuali ?? '0') ?? 0,
        'anno_immatricolazione': int.tryParse(anno) ?? DateTime.now().year
      });
      await inizializzaDati();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> eliminaUtente(int id) async {
    await _authService.eliminaUtente(id);
    await inizializzaDati();
  }

  Future<void> eliminaVeicolo(String targa) async {
    await Supabase.instance.client.from('veicoli').delete().eq('targa', targa);
    await inizializzaDati();
  }

  Future<void> modificaPrenotazione(
      int idPrenotazione, DateTime nuovoInizio, DateTime nuovaFine) async {
    try {
      final p = _prenotazioni
          .firstWhere((element) => element.idPrenotazione == idPrenotazione);
      final driver = _utenti.firstWhere((u) => u.idUtente == p.idUtente);
      if (!_isSlotDisponibile(
          targa: p.targa,
          idUtente: p.idUtente,
          inizio: nuovoInizio,
          fine: nuovaFine,
          idDaEscludere: idPrenotazione)) {
        throw Exception('Sovrapposizione.');
      }
      await Supabase.instance.client.from('prenotazioni').update({
        'data_inizio': nuovoInizio.toIso8601String(),
        'data_fine': nuovaFine.toIso8601String(),
        'stato': 'richiesta'
      }).eq('id_prenotazione', idPrenotazione);
      for (var idMan in _tuttiManagerIds) {
        await _notificaService.notificaRichiestaPrenotazione(
            idMan,
            "${driver.nome} ${driver.cognome}",
            p.targa,
            nuovoInizio,
            nuovaFine);
      }
      await inizializzaDati();
    } catch (e) {
      rethrow;
    }
  }

bool _isSlotDisponibile({
  required String targa,
  required int idUtente,
  required DateTime inizio,
  required DateTime fine,
  int? idDaEscludere,
}) {
  // 1. Controllo Manutenzioni (rimane uguale)
  final veicoloInOfficina = _manutenzioni.any((m) =>
      m.targa == targa &&
      m.oraFine == null &&
      inizio.isBefore(m.data.add(const Duration(hours: 8))) &&
      fine.isAfter(m.data));
  if (veicoloInOfficina) return false;

  // 2. Controllo Prenotazioni
  return !_prenotazioni.any((p) {
    if (idDaEscludere != null && p.idPrenotazione == idDaEscludere) return false;

    if (p.statoPrenotazione == StatoPrenotazione.annullata || 
        p.statoPrenotazione == StatoPrenotazione.completata) {
      return false;
    }
    // --------------------

    final haSovrapposizioneOraria =
        inizio.isBefore(p.dataFine) && fine.isAfter(p.dataInizio);

    return haSovrapposizioneOraria &&
        (p.targa == targa || (idUtente != 0 && p.idUtente == idUtente));
  });
}

  Future<Veicolo?> getVeicoloDallaTarga(String targa) async {
    final targaPulita = targa.trim().toUpperCase();

    // 1. Cerchiamo nella lista locale che abbiamo già nel Provider
    try {
      return _veicoli.firstWhere(
        (v) => v.targa.trim().toUpperCase() == targaPulita,
      );
    } catch (_) {
      // 2. Se non lo trova in locale, interroga il database tramite il service
      debugPrint("Veicolo non in memoria, lo cerco sul DB...");
      return await _veicoloService.getVeicoloByTarga(targaPulita);
    }
  }

}
