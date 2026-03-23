import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/veicolo.dart';
import '../models/prenotazione.dart';
import '../models/utente.dart';
import '../models/manutenzione.dart';
import '../models/enums/stato_veicolo.dart';
import '../models/enums/stato_prenotazione.dart';
import '../models/enums/tipo_manutenzione.dart';
import '../models/enums/tipo_prenotazione.dart';
import '../services/auth_service.dart';
import '../services/prenotazione_service.dart';
import '../services/manutenzione_service.dart';
import '../services/veicolo_service.dart';

class FleetProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  final VeicoloService _veicoloService = VeicoloService();
  final PrenotazioneService _prenotazioneService = PrenotazioneService();
  final ManutenzioneService _manutenzioneService = ManutenzioneService();

  List<Veicolo> _veicoli = [];
  List<Prenotazione> _prenotazioni = [];
  List<Manutenzione> _manutenzioni = [];
  List<Utente> _utenti = [];
  Utente? _utenteLoggato;
  bool _isLoading = false;

  // Getter
  List<Veicolo> get veicoli => _veicoli;
  List<Prenotazione> get prenotazioni => _prenotazioni;
  List<Manutenzione> get manutenzioni => _manutenzioni;
  Utente? get utenteLoggato => _utenteLoggato;
  List<Utente> get utenti => _utenti;
  bool get isLoading => _isLoading;

  /// CARICAMENTO DATI E SINCRONIZZAZIONE
  Future<void> inizializzaDati() async {
    _isLoading = true;
    notifyListeners();

    try {
      // 1. Sincronizza gli stati temporali (es. Passaggio da Confermata ad Attiva)
      await _prenotazioneService.aggiornaStatiPrenotazioni();

      // 2. Carica i dati aggiornati in parallelo per velocità
      final risultati = await Future.wait([
        _veicoloService.fetchAllVeicoli(),
        _prenotazioneService.fetchPrenotazioni(),
        _authService.getTuttiUtenti(),
        _manutenzioneService.fetchTutte(),
      ]);

      _veicoli = risultati[0] as List<Veicolo>;
      _prenotazioni = risultati[1] as List<Prenotazione>;
      _utenti = risultati[2] as List<Utente>;
      _manutenzioni = risultati[3] as List<Manutenzione>;

      debugPrint("✅ PROVIDER: Dati sincronizzati e caricati.");
    } catch (e) {
      debugPrint("❌ PROVIDER ERROR durante inizializzazione: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- LOGICA AUTENTICAZIONE ---

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
    _utenti = [];
    notifyListeners();
  }

  // --- LOGICA UTENTI (CRUD) ---

  Future<void> aggiungiNuovoUtente({
    required String email,
    required String passwordScelta,
    required String nome,
    required String cognome,
    required String ruolo,
    String? patente,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      final authRes = await Supabase.instance.client.auth.signUp(
        email: email.trim(),
        password: passwordScelta,
      );

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
    } catch (e) {
      debugPrint("❌ Errore aggiunta utente: $e");
      rethrow;
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
    } catch (e) {
      debugPrint("❌ Errore eliminazione utente: $e");
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> aggiornaUtente(Utente u) async {
    _isLoading = true;
    notifyListeners();
    try {
      await Supabase.instance.client.from('utenti').update({
        'nome': u.nome,
        'cognome': u.cognome,
        'ruolo': u.ruoloUtente.name,
        'patente': u.patente,
      }).eq('id_utente', u.idUtente);
      await inizializzaDati();
    } catch (e) {
      debugPrint("❌ Errore aggiornamento utente: $e");
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- LOGICA PRENOTAZIONI ---

  Future<void> creaPrenotazione(
      Utente driver, Veicolo veicolo, DateTime inizio, DateTime fine) async {
    if (driver.patente == null || driver.patente == 'Da inserire') {
      throw Exception('L\'utente non ha una patente valida registrata.');
    }

    _isLoading = true;
    notifyListeners();
    try {
      bool disponibile = await _prenotazioneService.validaDisponibilita(
          veicolo.targa, inizio, fine);
      if (!disponibile) {
        throw Exception('Il veicolo è già prenotato in questo periodo.');
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
      await _prenotazioneService.annullaPrenotazione(id);
      await inizializzaDati();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- LOGICA MANUTENZIONI ---

  Future<void> programmareManutenzione(Veicolo veicolo, DateTime inizio,
      TipoManutenzione tipo, String descrizione,
      {required String luogo}) async {
    _isLoading = true;
    notifyListeners();
    try {
      // 1. Registriamo l'intervento (questo va sempre fatto)
      await _manutenzioneService.registraIntervento(Manutenzione(
        idManutenzione: 0,
        data: inizio,
        tipoManutenzione: tipo,
        descrizione: descrizione,
        targa: veicolo.targa,
        luogo: luogo,
      ));

      // 2. LOGICA DI STATO (IL PUNTO CRITICO)
      // Cambiamo lo stato in 'inManutenzione' SOLO SE:
      // - È un'emergenza (Straordinaria)
      // - OPPURE l'appuntamento è ADESSO (o nel passato)
      bool deveBloccareSubito = 
          tipo == TipoManutenzione.straordinaria || 
          inizio.isBefore(DateTime.now().add(const Duration(minutes: 10)));

      if (deveBloccareSubito) {
        await _veicoloService.updateStatoVeicolo(
            veicolo.targa, StatoVeicolo.inManutenzione);
      } else {
        // Se è ordinaria e futura, lasciamo lo stato 'disponibile'!
        // Così il driver la vede nella lista, ma il nostro 'isVeicoloDisponibile'
        // la bloccherà solo per le ore del tagliando.
        debugPrint("Auto lasciata DISPONIBILE per prenotazioni pre-tagliando");
      }

      await inizializzaDati();
    } catch (e) {
      debugPrint("❌ Errore: $e");
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
      debugPrint("❌ Errore chiusura manutenzione: $e");
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- GESTIONE VEICOLI (CRUD) ---

  Future<void> aggiungiNuovoVeicolo({
    required String targa,
    required String marca,
    required String modello,
    required String tipo,
    required String anno,
    String? kmAttuali,
  }) async {
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
    } catch (e) {
      debugPrint("❌ Errore aggiunta veicolo: $e");
      rethrow;
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
    } catch (e) {
      debugPrint("❌ Errore eliminazione veicolo: $e");
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

bool isVeicoloDisponibile(String targa, DateTime inizioRichiesto, DateTime fineRichiesto) {
  // 1. Il veicolo è fisicamente in officina ADESSO? 
  // Se sì, è bloccato a prescindere dalle date future.
  final v = _veicoli.firstWhere((v) => v.targa == targa);
  if (v.statoVeicolo == StatoVeicolo.inManutenzione) return false;

  // 2. Controllo incrocio con MANUTENZIONI PROGRAMMATE
  final haConflittoManutenzione = _manutenzioni.any((m) {
    // Consideriamo solo manutenzioni della stessa auto e ancora "aperte" (senza oraFine)
    if (m.targa != targa || m.oraFine != null) return false;

    // Ipotizziamo che la manutenzione occupi l'auto dalla sua 'data' 
    // fino a poche ore dopo (es. 10 ore o fino a fine giornata)
    DateTime inizioM = m.data;
    DateTime fineM = m.data.add(const Duration(hours: 8)); 

    // Formula Magica della Sovrapposizione:
    // Un conflitto esiste SOLO SE (Inizio1 < Fine2) E (Fine1 > Inizio2)
    return inizioRichiesto.isBefore(fineM) && fineRichiesto.isAfter(inizioM);
  });

  if (haConflittoManutenzione) return false;

  // 3. Controllo incrocio con altre PRENOTAZIONI già confermate
  final haConflittoPrenotazione = _prenotazioni.any((p) {
    if (p.targa != targa || p.statoPrenotazione != StatoPrenotazione.confermata) return false;
    
    return inizioRichiesto.isBefore(p.dataFine) && fineRichiesto.isAfter(p.dataInizio);
  });

  return !haConflittoPrenotazione;
}
}
