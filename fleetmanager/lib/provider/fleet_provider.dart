import 'package:flutter/material.dart';
import '../models/veicolo.dart';
import '../models/prenotazione.dart';
import '../models/utente.dart';
import '../models/scadenza.dart';
import '../models/notifica.dart';
import '../models/enums/stato_veicolo.dart';
import '../models/enums/stato_prenotazione.dart';
import '../models/enums/tipo_notifica.dart';
import '../models/enums/tipo_prenotazione.dart';
import '../models/enums/tipo_manutenzione.dart';
import '../models/enums/ruolo_utente.dart';
import '../services/auth_service.dart';
import '../services/prenotazione_service.dart';
import '../services/manutenzione_service.dart';
import '../services/scadenza_service.dart';
import '../services/notifica_service.dart';
import '../mock/mock_data.dart';

class FleetProvider with ChangeNotifier {
  // Service
  final AuthService _authService = AuthService();
  final PrenotazioneService _prenotazioneService = PrenotazioneService();
  final ManutenzioneService _manutenzioneService = ManutenzioneService();
  final ScadenzaService _scadenzaService = ScadenzaService();
  final NotificaService _notificaService = NotificaService();

  List<Veicolo> _veicoli = [];
  List<Prenotazione> _prenotazioni = [];
  List<Scadenza> _scadenze = [];
  List<Notifica> _notifiche = [];
  Utente? _utenteLoggato;
  bool _isLoading = false;

  // Getter
  List<Veicolo> get veicoli => _veicoli;
  List<Prenotazione> get prenotazioni => _prenotazioni;
  List<Notifica> get notifiche => _notifiche;
  Utente? get utenteLoggato => _utenteLoggato;
  bool get isLoading => _isLoading;

  // Login method
  Future<bool> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();
    try {
      final user = await _authService.login(email, password);
      if (user != null) {
        _utenteLoggato = user;
        return true;
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    return false;
  }

  // Carica dati iniziali (mock/back-end)
  Future<void> inizializzaDati() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Caricamento mock / placeholder
      _veicoli = MockData.veicoli;
      _prenotazioni = MockData.prenotazioni;
      _scadenze = []; // Implementa se hai mock per le scadenze
      _notifiche = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<List<Prenotazione>> getPrenotazioniVisibiliOrdinare(Utente utenteLoggato) async {
    List<Prenotazione> tutte = List.from(_prenotazioni);

    if (utenteLoggato.ruoloUtente != RuoloUtente.manager) {
      tutte = tutte.where((p) => p.idUtente == utenteLoggato.idUtente).toList();
    }

    tutte.sort((a, b) {
      int cmp = _priorita(a, utenteLoggato).compareTo(_priorita(b, utenteLoggato));
      return cmp != 0 ? cmp : _confrontoTemporale(a, b);
    });

    return tutte;
  }

  int _priorita(Prenotazione p, Utente utenteLoggato) {
    final s = p.statoPrenotazione;
    final isManager = utenteLoggato.ruoloUtente == RuoloUtente.manager;

    if (isManager) {
      switch (s) {
        case StatoPrenotazione.richiesta:
          return 1;
        case StatoPrenotazione.attiva:
          return 2;
        case StatoPrenotazione.confermata:
          return 3;
        case StatoPrenotazione.completata:
          return 4;
        case StatoPrenotazione.annullata:
          return 5;
      }
    }

    switch (s) {
      case StatoPrenotazione.attiva:
        return 1;
      case StatoPrenotazione.richiesta:
        return 2;
      case StatoPrenotazione.confermata:
        return 3;
      case StatoPrenotazione.completata:
        return 4;
      case StatoPrenotazione.annullata:
        return 5;
    }
  }

  int _confrontoTemporale(Prenotazione a, Prenotazione b) {
    final now = DateTime.now();
    final ta = a.dataInizio.isAfter(now) ? a.dataInizio : a.dataFine;
    final tb = b.dataInizio.isAfter(now) ? b.dataInizio : b.dataFine;
    return ta.compareTo(tb);
  }

  // --- 1. LOGICA GESTORE PRENOTAZIONI (da GestorePrenotazioniImpl.java) ---
  
  Future<void> aggiungiPrenotazione(Prenotazione nuova) async {
    // Check Overlap: La stessa logica che avevi in Java
    bool occupato = _prenotazioni.any((p) =>
        p.targa == nuova.targa &&
        p.statoPrenotazione != StatoPrenotazione.annullata &&
        nuova.dataInizio.isBefore(p.dataFine) &&
        nuova.dataFine.isAfter(p.dataInizio));

    if (occupato) {
      throw Exception("Veicolo già occupato in queste date!");
    }

    // In Java facevi: prenotazioneDAO.save(p)
    _prenotazioni.add(nuova);
    notifyListeners();
  }

  // --- 2. LOGICA GESTORE SCADENZE (da GestoreScadenzeImpl.java) ---

  void verificaEbloccaVeicoliScaduti() {
    final oggi = DateTime.now();
    bool cambiamenti = false;

    for (var veicolo in _veicoli) {
      // Cerchiamo le scadenze per questa targa
      var scadenzeVeicolo = _scadenze.where((s) => s.targa == veicolo.targa);
      
      for (var s in scadenzeVeicolo) {
        if (s.data.isBefore(oggi) && veicolo.statoVeicolo != StatoVeicolo.fuoriServizio) {
          // Logica Java: veicolo.setStatoVeicolo(StatoVeicolo.NON_DISPONIBILE)
          _aggiornaStatoLocaleVeicolo(veicolo.targa, StatoVeicolo.fuoriServizio);
          cambiamenti = true;
          debugPrint("Veicolo ${veicolo.targa} bloccato per scadenza ${s.tipoScadenza}");
        }
      }
    }
    if (cambiamenti) notifyListeners();
  }

  // --- 3. LOGICA GESTORE MANUTENZIONI (da GestoreManutenzioniImpl.java) ---

  void segnalaGuasto(String targa, String descrizione) {
    // 1. Cambia stato veicolo
    _aggiornaStatoLocaleVeicolo(targa, StatoVeicolo.inManutenzione);
    
    // 2. Crea notifica per il Manager (ID 1 come nel tuo Java)
    _notifiche.add(Notifica(
      idNotifica: _notifiche.length + 1,
      tipoNotifica: TipoNotifica.manutenzione,
      messaggio: "GUASTO su $targa: $descrizione",
      dataInvio: DateTime.now(),
      letta: false,
      idUtente: 1, // Manager
    ));
    
    notifyListeners();
  }

  // Helper per aggiornare lo stato di un veicolo nella lista locale
  void _aggiornaStatoLocaleVeicolo(String targa, StatoVeicolo nuovoStato) {
    int index = _veicoli.indexWhere((v) => v.targa == targa);
    if (index != -1) {
      // In Flutter/Dart gli oggetti sono spesso final, ne creiamo uno nuovo (Immutabilità)
      var v = _veicoli[index];
      _veicoli[index] = Veicolo(
        targa: v.targa,
        marca: v.marca,
        modello: v.modello,
        tipoVeicolo: v.tipoVeicolo,
        annoImmatricolazione: v.annoImmatricolazione,
        km: v.km,
        statoVeicolo: nuovoStato,
      );
    }
  }

  // --- METODI DA UIFACADEIMPL ---

  // Prenotazioni
  Future<void> creaPrenotazione(Utente driver, Veicolo veicolo, DateTime dataInizio, DateTime dataFine) async {
    if (driver.patente == null) {
      throw Exception('L\'utente non ha la patente.');
    }
    bool disponibile = await _prenotazioneService.validaDisponibilita(veicolo.targa, dataInizio, dataFine);
    if (!disponibile) {
      throw Exception('Veicolo non disponibile.');
    }
    // Crea prenotazione
    Prenotazione p = Prenotazione(
      idPrenotazione: 0, // Backend assegna ID
      dataInizio: dataInizio,
      dataFine: dataFine,
      statoPrenotazione: StatoPrenotazione.richiesta,
      tipoPrenotazione: TipoPrenotazione.utente, // Da enum
      idUtente: driver.idUtente,
      targa: veicolo.targa,
    );
    await _prenotazioneService.creaPrenotazione(p);
    // Notifica richiesta
    await _notificaService.notificaRichiestaPrenotazione(driver.idUtente, veicolo.targa, dataInizio, dataFine);
    notifyListeners();
  }

  Future<void> confermaPrenotazione(int idPrenotazione) async {
    if (_utenteLoggato?.ruoloUtente != RuoloUtente.manager) {
      throw Exception('Solo manager può confermare.');
    }
    await _prenotazioneService.confermaPrenotazione(idPrenotazione);
    // Trova prenotazione e notifica driver
    Prenotazione? p = _prenotazioni.cast<Prenotazione?>().firstWhere((pr) => pr?.idPrenotazione == idPrenotazione, orElse: () => null);
    if (p != null) {
      await _notificaService.notificaConfermaPrenotazione(p.idUtente, p.targa, p.dataInizio, p.dataFine);
    }
    notifyListeners();
  }

  Future<void> annullaPrenotazione(int idPrenotazione) async {
    await _prenotazioneService.annullaPrenotazione(idPrenotazione);
    // Trova prenotazione e notifica
    Prenotazione? p = _prenotazioni.cast<Prenotazione?>().firstWhere((pr) => pr?.idPrenotazione == idPrenotazione, orElse: () => null);
    if (p != null) {
      if (_utenteLoggato?.ruoloUtente == RuoloUtente.manager) {
        await _notificaService.notificaRifiutoPrenotazione(p.idUtente, p.targa, p.dataInizio, p.dataFine);
      } else {
        await _notificaService.notificaAnnullamentoPrenotazioneDaDriver(p.idUtente, p.targa);
      }
    }
    notifyListeners();
  }

  Future<void> completaPrenotazione(int idPrenotazione) async {
    await _prenotazioneService.completaPrenotazione(idPrenotazione);
    notifyListeners();
  }

  Future<void> aggiornaStatiPrenotazioni() async {
    await _prenotazioneService.aggiornaStatiPrenotazioni();
    notifyListeners();
  }

  // Manutenzioni
  Future<void> programmareManutenzione(Veicolo veicolo, DateTime inizio, TipoManutenzione tipo, String descrizione) async {
    await _manutenzioneService.programmareManutenzione(veicolo.targa, inizio, tipo, descrizione);
    _aggiornaStatoLocaleVeicolo(veicolo.targa, StatoVeicolo.inManutenzione);
    await _notificaService.notificaManutenzioneProgrammata(1, veicolo.targa, inizio); // ID Manager
    notifyListeners();
  }

  Future<void> segnalareInterventoStraordinario(Veicolo veicolo, String descrizione) async {
    await _manutenzioneService.segnalareInterventoStraordinario(veicolo.targa, descrizione);
    _aggiornaStatoLocaleVeicolo(veicolo.targa, StatoVeicolo.inManutenzione);
    await _notificaService.notificaInterventoStraordinario(1, veicolo.targa);
    notifyListeners();
  }

  Future<void> chiudiManutenzione(int idManutenzione) async {
    await _manutenzioneService.chiudiManutenzione(idManutenzione);
    // Trova manutenzione e aggiorna veicolo
    // Per semplicità, assumiamo che il backend gestisca
    notifyListeners();
  }

  // Scadenze
  Future<void> controllaScadenzeENotifica() async {
    List<Scadenza> scadenze = _scadenze; // O fetch da service
    DateTime oggi = DateTime.now();
    DateTime limite = oggi.add(Duration(days: 7));

    for (Scadenza s in scadenze) {
      if (!s.notificata && !s.data.isAfter(limite)) {
        await _notificaService.inviaNotificaScadenza(s.idScadenza, s.targa, s.tipoScadenza.name, s.data);
        // Crea nuova Scadenza con notificata true
        Scadenza aggiornata = Scadenza(
          idScadenza: s.idScadenza,
          tipoScadenza: s.tipoScadenza,
          data: s.data,
          notificata: true,
          targa: s.targa,
        );
        // Aggiorna lista
        int index = _scadenze.indexOf(s);
        if (index != -1) _scadenze[index] = aggiornata;
        await _scadenzaService.segnaNotificata(s.idScadenza);
      }
    }
    notifyListeners();
  }

  // Utenti
  Future<List<Utente>> getTuttiDriver() async {
    List<Utente> tutti = await _authService.getTuttiUtenti();
    return tutti.where((u) => u.ruoloUtente == RuoloUtente.driver).toList();
  }

  Future<void> creaUtente(Utente u) async {
    bool success = await _authService.createUtente(u);
    if (!success) throw Exception('Errore creazione utente');
    notifyListeners();
  }

  Future<void> aggiornaUtente(Utente u) async {
    bool success = await _authService.updateProfilo(u);
    if (!success) throw Exception('Errore aggiornamento utente');
    notifyListeners();
  }

  Future<void> eliminaUtente(int idUtente) async {
    bool success = await _authService.eliminaUtente(idUtente);
    if (!success) throw Exception('Errore eliminazione utente');
    notifyListeners();
  }

  // Notifiche
  Future<List<Notifica>> getNotifichePerUtente() async {
    if (_utenteLoggato?.ruoloUtente == RuoloUtente.manager) {
      return await _notificaService.fetchMieNotifiche(_utenteLoggato!.idUtente); // Tutti per manager
    }
    return await _notificaService.fetchMieNotifiche(_utenteLoggato!.idUtente);
  }

  void logout() {
    _utenteLoggato = null;
    _veicoli = [];
    _prenotazioni = [];
    _scadenze = [];
    _notifiche = [];
    notifyListeners();
  }
}