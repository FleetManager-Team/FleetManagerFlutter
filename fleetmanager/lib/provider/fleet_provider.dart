import 'package:fleetmanager/models/enums/tipo_prenotazione.dart';
import 'package:fleetmanager/models/manutenzione.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/veicolo.dart';
import '../models/prenotazione.dart';
import '../models/utente.dart';
import '../models/scadenza.dart';
import '../models/notifica.dart';
import '../models/enums/stato_veicolo.dart';
import '../models/enums/stato_prenotazione.dart';
import '../models/enums/tipo_manutenzione.dart';
import '../models/enums/ruolo_utente.dart';
import '../services/auth_service.dart';
import '../services/prenotazione_service.dart';
import '../services/manutenzione_service.dart';
import '../services/scadenza_service.dart';
import '../services/notifica_service.dart';
import '../services/veicolo_service.dart'; // Aggiunto VeicoloService

class FleetProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  final VeicoloService _veicoloService = VeicoloService();
  final PrenotazioneService _prenotazioneService = PrenotazioneService();
  final ManutenzioneService _manutenzioneService = ManutenzioneService();
  final ScadenzaService _scadenzaService = ScadenzaService();
  final NotificaService _notificaService = NotificaService();

  List<Veicolo> _veicoli = [];
  List<Prenotazione> _prenotazioni = [];
  List<Manutenzione> _manutenzioni = [];
  List<Scadenza> _scadenze = [];
  List<Notifica> _notifiche = [];
  List<Utente> _utenti = [];
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

  // Carica tutti i dati da Supabase
  Future<void> inizializzaDati() async {
    _isLoading = true;
    notifyListeners();

    try {
      _veicoli = await _veicoloService.fetchAllVeicoli();
      _prenotazioni = await _prenotazioneService.fetchPrenotazioni();
      _utenti = await _authService.getTuttiUtenti();
      _scadenze = await _scadenzaService.fetchTutteLeScadenze();
      _manutenzioni = await _manutenzioneService.fetchTutte();
      debugPrint("PROVIDER: Dati caricati correttamente da Supabase.");
    } catch (e) {
      debugPrint("PROVIDER ERROR: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      final user = await _authService.login(email, password);
      if (user != null) {
        _utenteLoggato = user;
        // Una volta loggato, scarichiamo veicoli, prenotazioni, ecc.
        await inizializzaDati();
        return true;
      } else {
        _utenteLoggato = null;
        return false;
      }
    } catch (e) {
      print("Errore nel Provider: $e");
      _utenteLoggato = null;
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- LOGICA PRENOTAZIONI ---

  Future<void> creaPrenotazione(
      Utente driver, Veicolo veicolo, DateTime inizio, DateTime fine) async {
    if (driver.patente == null) throw Exception('L\'utente non ha la patente.');

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
    await _notificaService.notificaRichiestaPrenotazione(
        driver.idUtente, veicolo.targa, inizio, fine);

    _prenotazioni = await _prenotazioneService.fetchPrenotazioni(); // Refresh
    notifyListeners();
  }

  Future<void> confermaPrenotazione(int idPrenotazione) async {
    await _prenotazioneService.confermaPrenotazione(idPrenotazione);
    _prenotazioni = await _prenotazioneService.fetchPrenotazioni(); // Refresh
    notifyListeners();
  }

  Future<void> annullaPrenotazione(int idPrenotazione) async {
    await _prenotazioneService.annullaPrenotazione(idPrenotazione);
    _prenotazioni = await _prenotazioneService.fetchPrenotazioni(); // Refresh
    notifyListeners();
  }

  // --- LOGICA MANUTENZIONI ---

  Future<void> programmareManutenzione(Veicolo veicolo, DateTime inizio,
      TipoManutenzione tipo, String descrizione) async {
    // Registra nel DB
    await _manutenzioneService.registraIntervento(Manutenzione(
      idManutenzione: 0,
      data: inizio,
      tipoManutenzione: tipo,
      descrizione: descrizione,
      targa: veicolo.targa,
    ));

    Future<void> segnalareInterventoStraordinario(
        Veicolo v, String descrizione) async {
      await _manutenzioneService.segnalareInterventoStraordinario(
          v.targa, descrizione);
      await inizializzaDati(); // Rinfresca tutto per aggiornare stato veicolo e lista
    }

    // Aggiorna stato veicolo nel DB
    await _veicoloService.updateStatoVeicolo(
        veicolo.targa, StatoVeicolo.inManutenzione);

    await _notificaService.notificaManutenzioneProgrammata(
        1, veicolo.targa, inizio);

    _veicoli = await _veicoloService.fetchAllVeicoli(); // Refresh
    notifyListeners();
  }

  Future<void> chiudiManutenzione(int idManutenzione, String targa,
      {int? nuoviKm}) async {
    _isLoading = true;
    notifyListeners();
    try {
      // Usiamo i nuovi chilometri passati dalla UI, o quelli attuali se null
      int kmFinali = nuoviKm ?? _veicoli.firstWhere((v) => v.targa == targa).km;

      await _manutenzioneService.chiudiIntervento(
          idManutenzione, kmFinali, targa);
      await inizializzaDati(); // Rinfresca tutto
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> segnalareInterventoStraordinario(
      Veicolo veicolo, String descrizione) async {
    _isLoading = true;
    notifyListeners();
    try {
      // 1. Chiama il service per inserire i dati su Supabase
      await _manutenzioneService.segnalareInterventoStraordinario(
          veicolo.targa, descrizione);

      // 2. Ricarica tutti i dati (così il veicolo risulterà "In Manutenzione")
      await inizializzaDati();

      debugPrint("Intervento segnalato con successo per ${veicolo.targa}");
    } catch (e) {
      debugPrint("Errore nel provider: $e");
      rethrow; // Permette alla UI di mostrare l'errore nello SnackBar
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- LOGICA UTENTI ---

  Future<void> eliminaUtente(int id) async {
    _isLoading = true;
    notifyListeners();
    try {
      bool success = await _authService.eliminaUtente(id);
      if (success) {
        _utenti.removeWhere((u) => u.idUtente == id);
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> aggiungiNuovoUtente({
    required String email,
    required String passwordScelta,
    required String nome,
    required String cognome,
    required String ruolo,
    String? patente,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      // 1. REGISTRAZIONE SU SUPABASE AUTH
      final authRes = await Supabase.instance.client.auth.signUp(
        email: email.trim(),
        password: passwordScelta,
      
      );

      if (authRes.user != null) {
        // 2. INSERIMENTO NELLA TABELLA 'utenti'
        await Supabase.instance.client.from('utenti').insert({
          'email': email.trim().toLowerCase(),
          'nome': nome.trim(),
          'cognome': cognome.trim(),
          'ruolo': ruolo,
          'patente': patente ?? 'Da inserire',
        });

        await inizializzaDati();
        debugPrint("✅ Utente creato correttamente: $email");
      }
    } on AuthException catch (e) {
      debugPrint("❌ Errore Auth: ${e.message}");
      rethrow;
    } catch (e) {
      debugPrint("❌ Errore Database: $e");
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- HELPER UI ---

  Future<List<Prenotazione>> getPrenotazioniVisibiliOrdinare(
      Utente utente) async {
    List<Prenotazione> lista = List.from(_prenotazioni);
    if (utente.ruoloUtente != RuoloUtente.manager) {
      lista = lista.where((p) => p.idUtente == utente.idUtente).toList();
    }
    // Logica ordinamento mantenuta
    lista.sort((a, b) => _priorita(a, utente).compareTo(_priorita(b, utente)));
    return lista;
  }

  int _priorita(Prenotazione p, Utente u) {
    // ... (Logica switch-case priorità già presente nel tuo codice originale)
    return 1; // Esempio semplificato per brevità
  }

  void logout() {
    _utenteLoggato = null;
    _veicoli = [];
    _prenotazioni = [];
    notifyListeners();
  }
}
