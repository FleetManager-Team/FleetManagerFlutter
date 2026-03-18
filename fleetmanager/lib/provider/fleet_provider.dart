import 'package:flutter/material.dart';
import '../models/veicolo.dart';
import '../models/prenotazione.dart';
import '../models/utente.dart';
import '../models/scadenza.dart';
import '../models/notifica.dart';
import '../models/enums/stato_veicolo.dart';
import '../models/enums/stato_prenotazione.dart';
import '../models/enums/tipo_notifica.dart';
import '../services/auth_service.dart';
import '../mock/mock_data.dart';

class FleetProvider with ChangeNotifier {
  // Service (Simulati o Reali)
  final AuthService _authService = AuthService();
  // final _service = MockService(); // Esempio

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

  void verificaE_BloccaVeicoliScaduti() {
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

  // --- METODI ESISTENTI (Inizializzazione e Login) ---

  Future<void> inizializzaDati() async {
    _isLoading = true;
    notifyListeners();
    try {
      // Carica dati mock per sviluppo
      _veicoli = MockData.veicoli;
      _prenotazioni = MockData.prenotazioni;
      // _scadenze = await _scadenzaService.fetchAll();
      
      // Dopo il caricamento, eseguiamo subito il controllo scadenze (come facevi nel main Java)
      verificaE_BloccaVeicoliScaduti();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void logout() {
    _utenteLoggato = null;
    _veicoli = [];
    _prenotazioni = [];
    notifyListeners();
  }
}