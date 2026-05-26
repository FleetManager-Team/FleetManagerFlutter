import 'package:fleetmanager/models/checkup.dart';
import 'package:fleetmanager/models/enums/tipo_prenotazione.dart';
import 'package:fleetmanager/models/enums/tipo_scadenza.dart';
import 'package:fleetmanager/models/manutenzione.dart';
import 'package:fleetmanager/models/enums/ruolo_utente.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/veicolo.dart';
import '../models/prenotazione.dart';
import '../models/utente.dart';
import '../models/notifica.dart';
import '../models/restituzione.dart';
import '../models/scadenza.dart';
import '../models/enums/stato_veicolo.dart';
import '../models/enums/stato_prenotazione.dart';
import '../models/enums/tipo_manutenzione.dart';
import '../services/auth_service.dart';
import '../services/prenotazione_service.dart';
import '../services/manutenzione_service.dart';
import '../services/notifica_service.dart';
import '../services/veicolo_service.dart';
import '../services/restituzione_service.dart';
import '../services/scadenza_service.dart';

class SpesaDriver {
  int idUtente;
  double carburante = 0;
  double pedaggi = 0;

  SpesaDriver({this.idUtente = 0, this.carburante = 0, this.pedaggi = 0});

  double get totale => carburante + pedaggi;
}

class FleetProvider with ChangeNotifier {
  late final AuthService _authService;
  late final VeicoloService _veicoloService;
  late final PrenotazioneService _prenotazioneService;
  late final ManutenzioneService _manutenzioneService;
  late final NotificaService _notificaService;
  late final ScadenzaService _scadenzaService;

  // Questa variabile permette di iniettare un client finto nei test
  final SupabaseClient? _supabaseClient;

  FleetProvider({
    AuthService? authService,
    VeicoloService? veicoloService,
    PrenotazioneService? prenotazioneService,
    ManutenzioneService? manutenzioneService,
    NotificaService? notificaService,
    ScadenzaService? scadenzaService,
    SupabaseClient? supabaseClient,
  }) : _supabaseClient = supabaseClient {
    _authService = authService ?? AuthService();
    _veicoloService = veicoloService ?? VeicoloService();
    _prenotazioneService = prenotazioneService ?? PrenotazioneService();
    _manutenzioneService = manutenzioneService ?? ManutenzioneService();
    _notificaService = notificaService ?? NotificaService();
    _scadenzaService =
        scadenzaService ?? ScadenzaService(supabaseClient: supabaseClient);
  }

  // Il getter usa il client passato (test) o quello reale (app)
  SupabaseClient get supabase => _supabaseClient ?? Supabase.instance.client;
  List<Veicolo> _veicoli = [];
  List<Prenotazione> _prenotazioni = [];
  List<Manutenzione> _manutenzioni = [];
  List<Utente> _utenti = [];
  List<Notifica> _notifiche = [];
  List<Restituzione> _restituzioni = [];
  List<CheckupVeicolo> _checkups = [];
  List<Scadenza> _scadenze = [];
  Utente? _utenteLoggato;
  bool _isLoading = false;

  // Getter
  List<Veicolo> get veicoli => _veicoli;
  List<Prenotazione> get prenotazioni => _prenotazioni;
  List<Manutenzione> get manutenzioni => _manutenzioni;
  List<Notifica> get notifiche => _notifiche;
  List<Restituzione> get restituzioni => _restituzioni;
  Utente? get utenteLoggato => _utenteLoggato;
  List<Utente> get utenti => _utenti;
  List<CheckupVeicolo> get checkups => _checkups;
  List<Scadenza> get scadenze => _scadenze;
  bool get isLoading => _isLoading;

  /// EMERGENZE ATTIVE: segnalate ma con km non ancora inseriti (ancora a 0 o uguali ai km di partenza)
  List<Restituzione> get emergenzeAttive => _restituzioni.where((r) {
        // Usiamo solo == 0 se kmFinali è int non-nullable e di default è 0
        return r.isEmergenza == true && r.kmFinali == 0;
      }).toList();

  /// STORICO EMERGENZE: tutto ciò che è stato marcato come SOS
  List<Restituzione> get storicoEmergenze => _restituzioni.where((r) {
        return r.isEmergenza == true;
      }).toList();

  /// Calcola il totale speso in carburante da tutte le restituzioni
  double get totaleSpesaCarburante {
    return _restituzioni
        .where((r) => r.importoEuro != null)
        .fold(0.0, (sum, r) => sum + r.importoEuro!);
  }

  /// Mappa la spesa carburante per ogni Driver: {"Nome Cognome": 120.50}
  Map<String, double> get spesaCarburantePerDriver {
    Map<String, double> stats = {};
    for (var res in _restituzioni) {
      if (res.importoEuro == null || res.importoEuro! <= 0) continue;

      // Trova la prenotazione collegata alla restituzione
      final preno = _prenotazioni.firstWhere(
        (p) => p.idPrenotazione == res.idPrenotazione,
        orElse: () => Prenotazione(
            idPrenotazione: -1,
            idUtente: -1,
            dataInizio: DateTime.now(),
            dataFine: DateTime.now(),
            statoPrenotazione: StatoPrenotazione.annullata,
            tipoPrenotazione: TipoPrenotazione.utente,
            targa: ''),
      );

      if (preno.idUtente != -1) {
        // Trova il driver
        final driver = _utenti.firstWhere(
          (u) => u.idUtente == preno.idUtente,
          orElse: () => Utente(
              idUtente: -1,
              nome: "Sconosciuto",
              cognome: "",
              email: "",
              ruoloUtente: RuoloUtente.driver),
        );

        String nomeCompleto = "${driver.nome} ${driver.cognome}";
        stats[nomeCompleto] = (stats[nomeCompleto] ?? 0.0) + res.importoEuro!;
      }
    }
    return stats;
  }

  /// Restituisce la spesa carburante filtrata per un range di date specifico
  Map<String, double> getSpesaCarburanteFiltrata(
      DateTime inizio, DateTime fine) {
    Map<String, double> stats = {};

    // Filtriamo le restituzioni che rientrano nel periodo (inclusivo)
    final restituzioniFiltrate = _restituzioni.where((r) {
      return r.importoEuro != null &&
          r.dataRestituzione
              .isAfter(inizio.subtract(const Duration(seconds: 1))) &&
          r.dataRestituzione.isBefore(fine.add(const Duration(days: 1)));
    });

    for (var res in restituzioniFiltrate) {
      final preno = _prenotazioni.firstWhere(
        (p) => p.idPrenotazione == res.idPrenotazione,
        orElse: () => _prenoVuota(), // Helper per evitare crash
      );

      if (preno.idUtente != -1) {
        final driver = _utenti.firstWhere(
          (u) => u.idUtente == preno.idUtente,
          orElse: () => _utenteVuoto(),
        );

        String nomeCompleto = "${driver.nome} ${driver.cognome}";
        stats[nomeCompleto] = (stats[nomeCompleto] ?? 0.0) + res.importoEuro!;
      }
    }
    return stats;
  }

// Helper rapidi per i casi "orElse"
  Prenotazione _prenoVuota() => Prenotazione(
      idPrenotazione: -1,
      idUtente: -1,
      dataInizio: DateTime.now(),
      dataFine: DateTime.now(),
      statoPrenotazione: StatoPrenotazione.annullata,
      tipoPrenotazione: TipoPrenotazione.utente,
      targa: '');
  Utente _utenteVuoto() => Utente(
      idUtente: -1,
      nome: "Sconosciuto",
      cognome: "",
      email: "",
      ruoloUtente: RuoloUtente.driver);

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
    _safeNotify();

    try {
      final risultati = await Future.wait<dynamic>([
        _veicoloService.fetchAllVeicoli(),
        _prenotazioneService.fetchPrenotazioni(),
        _authService.getTuttiUtenti(),
        _manutenzioneService.fetchTutte(),
        supabase.from('restituzioni').select(),
        // Carichiamo i checkup tecnici
        supabase.from('checkups').select(),
        // Carichiamo le scadenze
        supabase.from('scadenze').select(),
        _utenteLoggato != null
            ? _notificaService.fetchMieNotifiche(_utenteLoggato!.idUtente)
            : Future.value(<Notifica>[]),
      ]);

      _veicoli = List<Veicolo>.from(risultati[0]);
      _prenotazioni = List<Prenotazione>.from(risultati[1]);
      _utenti = List<Utente>.from(risultati[2]);
      _manutenzioni = List<Manutenzione>.from(risultati[3]);

      // Gestione Restituzioni (indice 4)
      final datiRestituzioni = risultati[4] as List<dynamic>;
      _restituzioni =
          datiRestituzioni.map((json) => Restituzione.fromJson(json)).toList();

      // Gestione Checkups (indice 5)
      final datiCheckups = risultati[5] as List<dynamic>;
      _checkups =
          datiCheckups.map((json) => CheckupVeicolo.fromJson(json)).toList();

      // Gestione Scadenze (indice 6)
      final datiScadenze = risultati[6] as List<dynamic>;
      _scadenze = datiScadenze.map((json) => Scadenza.fromJson(json)).toList();

      // Controlla scadenze imminenti e invia notifiche
      await _controllaScadenzeImminenti();

      // Gestione Notifiche (indice 7)
      final datiNotifiche = risultati[7] as List<dynamic>;
      _notifiche = datiNotifiche
          .map((json) => json is Notifica ? json : Notifica.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint("Errore inizializzazione: $e");
    } finally {
      _isLoading = false;
      _safeNotify();
    }
  }

  /// --- LOGICA AUTENTICAZIONE ---
  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _safeNotify();
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
      _safeNotify();
    }
  }

  void logout() {
    _utenteLoggato = null;
    _veicoli = [];
    _prenotazioni = [];
    _manutenzioni = [];
    _notifiche = [];
    _restituzioni = [];
    notifyListeners();
  }

  // Aggiungi {String? redirectTo} tra le graffe per renderlo opzionale
  Future<bool> recuperaPassword(String email, {String? redirectTo}) async {
    try {
      await supabase.auth.resetPasswordForEmail(
        email,
        redirectTo: redirectTo, // Ora lo passerà correttamente a Supabase
      );
      return true;
    } catch (e) {
      debugPrint("Errore recupero password: $e");
      return false;
    }
  }

  Future<bool> aggiornaPassword(String nuovaPassword) async {
    _isLoading = true;
    notifyListeners();
    try {
      await supabase.auth.updateUser(
        UserAttributes(password: nuovaPassword),
      );
      return true;
    } catch (e) {
      debugPrint("Errore aggiornamento: $e");
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// --- LOGICA NOTIFICHE ---
  Future<void> segnaNotificaLetta(int id) async {
    try {
      await _notificaService.segnaLetta(id);
      final index = _notifiche.indexWhere((n) => n.idNotifica == id);
      if (index != -1) {
        final n = _notifiche[index];
        _notifiche[index] = Notifica(
          idNotifica: n.idNotifica,
          tipoNotifica: n.tipoNotifica,
          messaggio: n.messaggio,
          dataInvio: n.dataInvio,
          letta: true,
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
      await supabase
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
  /// [autoConferma]: se true, la prenotazione è approvata automaticamente.
  /// [checkupObbligatorio]: se true (e autoConferma=true), va in `attesaCheckup`; altrimenti `confermata`.
  Future<void> creaPrenotazione(
      Utente driver, Veicolo veicolo, DateTime inizio, DateTime fine,
      {bool autoConferma = false, bool checkupObbligatorio = true}) async {
    if (driver.patente == null || driver.patente == 'Da inserire') {
      throw Exception('Patente mancante.');
    }
    _isLoading = true;
    _safeNotify();
    try {
      if (!_isSlotDisponibile(
          targa: veicolo.targa,
          idUtente: driver.idUtente,
          inizio: inizio,
          fine: fine)) {
        throw Exception('Auto o Driver occupati.');
      }

      // Con auto-approvazione saltiamo lo stato "richiesta"
      final StatoPrenotazione statoIniziale = autoConferma
          ? (checkupObbligatorio
              ? StatoPrenotazione.attesaCheckup
              : StatoPrenotazione.confermata)
          : StatoPrenotazione.richiesta;

      Prenotazione p = Prenotazione(
        idPrenotazione: 0,
        dataInizio: inizio.toUtc(),
        dataFine: fine.toUtc(),
        statoPrenotazione: statoIniziale,
        tipoPrenotazione: TipoPrenotazione.utente,
        idUtente: driver.idUtente,
        targa: veicolo.targa,
      );
      await _prenotazioneService.creaPrenotazione(p);

      if (autoConferma) {
        // Informiamo comunque i manager dell'avvenuta prenotazione
        for (var idManager in _tuttiManagerIds) {
          await _notificaService.notificaRichiestaPrenotazione(idManager,
              "${driver.nome} ${driver.cognome}", veicolo.targa, inizio, fine);
        }
        // Notifichiamo il driver della conferma immediata
        await _notificaService.notificaConfermaPrenotazione(
            driver.idUtente, veicolo.targa, inizio, fine);
        if (checkupObbligatorio) {
          await _notificaService.notificaCheckupRichiesto(
              driver.idUtente, veicolo.targa);
        }
      } else {
        for (var idManager in _tuttiManagerIds) {
          await _notificaService.notificaRichiestaPrenotazione(idManager,
              "${driver.nome} ${driver.cognome}", veicolo.targa, inizio, fine);
        }
      }

      await inizializzaDati();
    } finally {
      _isLoading = false;
      _safeNotify();
    }
  }

  /// [checkupObbligatorio]: se true → stato diventa `attesaCheckup`, altrimenti `confermata`
  Future<void> confermaPrenotazione(int id,
      {bool checkupObbligatorio = true}) async {
    try {
      final pApprovata =
          _prenotazioni.firstWhere((element) => element.idPrenotazione == id);

      final conflitti = _prenotazioni
          .where((p) =>
              p.idPrenotazione != id &&
              p.targa == pApprovata.targa &&
              p.statoPrenotazione == StatoPrenotazione.richiesta &&
              pApprovata.dataInizio.isBefore(p.dataFine) &&
              pApprovata.dataFine.isAfter(p.dataInizio))
          .toList();

      final statoTarget =
          checkupObbligatorio ? 'attesa_checkup' : 'confermata';
      await _prenotazioneService.confermaPrenotazione(id, stato: statoTarget);

      if (conflitti.isNotEmpty) {
        for (var conf in conflitti) {
          await _prenotazioneService.annullaPrenotazione(conf.idPrenotazione);
          await _notificaService.notificaRifiutoPrenotazione(
              conf.idUtente, conf.targa, conf.dataInizio, conf.dataFine);
        }
      }

      await _notificaService.notificaConfermaPrenotazione(pApprovata.idUtente,
          pApprovata.targa, pApprovata.dataInizio, pApprovata.dataFine);

      if (checkupObbligatorio) {
        final checkupEsistente = _checkups.any((c) => c.idPrenotazione == id);
        if (!checkupEsistente) {
          await _notificaService.notificaCheckupRichiesto(
              pApprovata.idUtente, pApprovata.targa);
        }
      }

      await inizializzaDati();
    } catch (e) {
      debugPrint("Errore in confermaPrenotazione: ${e.toString()}");
      rethrow;
    }
  }

  /// Attiva direttamente la prenotazione senza richiedere il checkup.
  Future<void> attivaPrenotazioneSenzaCheckup(int idPrenotazione) async {
    try {
      await supabase
          .from('prenotazioni')
          .update({'stato': 'attiva'}).eq('id_prenotazione', idPrenotazione);
      await inizializzaDati();
    } catch (e) {
      debugPrint("Errore attivazione senza checkup: $e");
      rethrow;
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

  /// --- MANUTENZIONI ---
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

      // Aggiungi scadenza tagliando (es. ogni 6 mesi)
      await _scadenzaService.aggiungiScadenzaTagliando(
          targa, null, 6, DateTime.now());

      // Notifica ai manager che la manutenzione è completata
      for (var idMan in _tuttiManagerIds) {
        await _notificaService.notificaManutenzioneCompletata(idMan, targa);
      }

      await inizializzaDati();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> modificaManutenzione({
    required int idManutenzione,
    required String descrizione,
    required String luogo,
    required DateTime data,
    required TipoManutenzione tipo,
  }) async {
    try {
      await _manutenzioneService.updateManutenzione(idManutenzione, {
        'descrizione': descrizione,
        'luogo': luogo,
        'data': data.toIso8601String(),
        'tipo': tipo.name,
      });
      await inizializzaDati();
    } catch (e) {
      debugPrint("Errore in modificaManutenzione: $e");
      rethrow;
    }
  }

  /// --- UTENTI & VEICOLI ---
  Future<void> aggiungiNuovoUtente(
      {required String email,
      required String passwordScelta,
      required String nome,
      required String cognome,
      required String ruolo,
      String? patente}) async {
    try {
      final authRes = await supabase.auth
          .signUp(email: email.trim(), password: passwordScelta);
      if (authRes.user != null) {
        await supabase.from('utenti').insert({
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
      await supabase.from('veicoli').insert({
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
    await supabase.from('veicoli').delete().eq('targa', targa);
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
      await supabase.from('prenotazioni').update({
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

  Future<void> segnaScadenzaNotificata(int idScadenza) async {
    await _scadenzaService.segnaNotificata(idScadenza);
    await inizializzaDati();
  }

  /// --- LOGICA ATTIVAZIONE (CHECK-UP) ---
  Future<void> completaRestituzioneConNotifiche({
    required int idPrenotazione,
    required String targa,
    required int kmFinali,
    required double livelloCarburante,
    required bool rifornimento,
    required bool haDanni,
    required bool haPedaggi,
    bool isEmergenza = false,
    String? noteEmergenza,
    String? posizioneEmergenza,
    double? litri,
    double? euro,
    double? euroPedaggi,
    String? descDanni,
    XFile? fotoScontrino,
    XFile? fotoDanni,
    XFile? fotoPedaggio,
  }) async {
    try {
      // Completa la restituzione tramite il service
      await RestituzioneService().completaRestituzione(
        idPrenotazione: idPrenotazione,
        targa: targa,
        kmFinali: kmFinali,
        livelloCarburante: livelloCarburante,
        rifornimento: rifornimento,
        haDanni: haDanni,
        haPedaggi: haPedaggi,
        isEmergenza: isEmergenza,
        noteEmergenza: noteEmergenza,
        posizioneEmergenza: posizioneEmergenza,
        litri: litri,
        euro: euro,
        euroPedaggi: euroPedaggi,
        descDanni: descDanni,
        fotoScontrino: fotoScontrino,
        fotoDanni: fotoDanni,
        fotoPedaggio: fotoPedaggio,
      );

      // Trova il driver della prenotazione
      final prenotazione =
          _prenotazioni.firstWhere((p) => p.idPrenotazione == idPrenotazione);
      final driver =
          _utenti.firstWhere((u) => u.idUtente == prenotazione.idUtente);

      // Notifica al driver che la prenotazione è completata
      await _notificaService.notificaPrenotazioneCompletata(
          prenotazione.idUtente, targa, isEmergenza);

      // Notifica ai manager che il veicolo è stato restituito
      for (var idMan in _tuttiManagerIds) {
        await _notificaService.notificaRestituzioneVeicolo(
            idMan, driver.nome, driver.cognome, targa, isEmergenza);
      }

      await inizializzaDati();
    } catch (e) {
      debugPrint("Errore in completaRestituzioneConNotifiche: $e");
      rethrow;
    }
  }

  /// --- HELPER METHODS ---
  bool isVeicoloDisponibile(
          String targa, DateTime inizioReq, DateTime fineReq) =>
      _isSlotDisponibile(
          targa: targa, idUtente: 0, inizio: inizioReq, fine: fineReq);

  bool _isSlotDisponibile({
    required String targa,
    required int idUtente,
    required DateTime inizio,
    required DateTime fine,
    int? idDaEscludere,
  }) {
    final veicoloInOfficina = _manutenzioni.any((m) =>
        m.targa == targa &&
        m.oraFine == null &&
        inizio.isBefore(m.data.add(const Duration(hours: 8))) &&
        fine.isAfter(m.data));
    if (veicoloInOfficina) return false;

    return !_prenotazioni.any((p) {
      // Escludi la prenotazione che stiamo eventualmente modificando
      if (idDaEscludere != null && p.idPrenotazione == idDaEscludere) {
        return false;
      }

      if (p.statoPrenotazione == StatoPrenotazione.annullata ||
          p.statoPrenotazione == StatoPrenotazione.completata ||
          p.statoPrenotazione == StatoPrenotazione.richiesta) {
        return false;
      }

      final haSovrapposizioneOraria =
          inizio.isBefore(p.dataFine) && fine.isAfter(p.dataInizio);
      return haSovrapposizioneOraria &&
          (p.targa == targa || (idUtente != 0 && p.idUtente == idUtente));
    });
  }

  Future<Veicolo?> getVeicoloDallaTarga(String targa) async {
    final targaPulita = targa.trim().toUpperCase();
    try {
      return _veicoli
          .firstWhere((v) => v.targa.trim().toUpperCase() == targaPulita);
    } catch (_) {
      return await _veicoloService.getVeicoloByTarga(targaPulita);
    }
  }

  void _safeNotify() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
  }

  Utente getDriverDallaPrenotazione(Prenotazione prenotazione) {
    return _utenti.firstWhere(
      (u) => u.idUtente == prenotazione.idUtente,
      orElse: () => Utente(
          idUtente: -1,
          nome: "Driver",
          cognome: "Non Trovato",
          email: "",
          ruoloUtente: RuoloUtente.driver),
    );
  }

  Map<String, SpesaDriver> getSpesaFiltrata({
    required DateTime inizio,
    required DateTime fine,
  }) {
    final Map<String, SpesaDriver> res = {};

    for (var r in restituzioni) {
      if (r.dataRestituzione.isAfter(inizio) &&
          r.dataRestituzione.isBefore(fine.add(const Duration(days: 1)))) {
        String nome = "Sconosciuto";
        int idTrovato = 0; // <--- Aggiungiamo questa variabile d'appoggio

        try {
          final p = prenotazioni
              .firstWhere((p) => p.idPrenotazione == r.idPrenotazione);
          final u = utenti.firstWhere((u) => u.idUtente == p.idUtente);

          nome = "${u.nome} ${u.cognome}";
          idTrovato = u.idUtente; // <--- Salviamo l'ID dell'utente!
        } catch (_) {}

        if (!res.containsKey(nome)) {
          res[nome] = SpesaDriver(idUtente: idTrovato);
        }

        res[nome]!.carburante += (r.importoEuro ?? 0.0);
        res[nome]!.pedaggi += (r.importoPedaggi ?? 0.0);
      }
    }
    return res;
  }

  Map<String, SpesaDriver> getDatiAnalisiCompleta({
    required DateTime inizio,
    required DateTime fine,
  }) {
    Map<String, SpesaDriver> res = {};

    for (var r in restituzioni) {
      // 1. Filtro data (concorde con quanto visto prima)
      if (r.dataRestituzione.isAfter(inizio) &&
          r.dataRestituzione.isBefore(fine.add(const Duration(days: 1)))) {
        // 2. TROVIAMO IL NOME DEL DRIVER
        String nomeDriver = "Sconosciuto";

        try {
          // Cerchiamo la prenotazione corrispondente alla restituzione
          final preno = prenotazioni
              .firstWhere((p) => p.idPrenotazione == r.idPrenotazione);

          // Cerchiamo l'utente (il driver) che ha fatto quella prenotazione
          final utente = utenti.firstWhere((u) => u.idUtente == preno.idUtente);

          nomeDriver = utente.nome; // o utente.cognome, o entrambi
        } catch (e) {
          // Se non trova corrispondenze, rimane "Sconosciuto"
        }

        // 3. RAGGRUPPAMENTO DATI
        if (!res.containsKey(nomeDriver)) {
          res[nomeDriver] = SpesaDriver();
        }

        res[nomeDriver]!.carburante += (r.importoEuro ?? 0.0);
        res[nomeDriver]!.pedaggi += (r.importoPedaggi ?? 0.0);
      }
    }
    return res;
  }

  Map<DateTime, SpesaDriver> getSpesaTemporaleDriver({
    required int idDriver, // Usiamo l'ID come richiesto
    required DateTime inizio,
    required DateTime fine,
  }) {
    final Map<DateTime, SpesaDriver> reportTemporale = {};
    final fineGiorno = DateTime(fine.year, fine.month, fine.day, 23, 59, 59);

    for (var r in _restituzioni) {
      final prenotazioniTrovate =
          _prenotazioni.where((p) => p.idPrenotazione == r.idPrenotazione);

      if (prenotazioniTrovate.isNotEmpty) {
        final prenotazione = prenotazioniTrovate.first;

        // 2. Filtriamo per ID Utente (ho visto dallo screenshot che usi idUtente)
        if (prenotazione.idUtente == idDriver &&
            r.dataRestituzione
                .isAfter(inizio.subtract(const Duration(seconds: 1))) &&
            r.dataRestituzione.isBefore(fineGiorno)) {
          // ... resto della logica per aggiungere i dati a reportTemporale ...
          DateTime soloGiorno = DateTime(r.dataRestituzione.year,
              r.dataRestituzione.month, r.dataRestituzione.day);

          if (!reportTemporale.containsKey(soloGiorno)) {
            reportTemporale[soloGiorno] = SpesaDriver();
          }

          reportTemporale[soloGiorno]!.carburante += r.importoEuro ?? 0.0;
          reportTemporale[soloGiorno]!.pedaggi += r.importoPedaggi ?? 0.0;
        }
      }
    }

    return reportTemporale;
  }

  /// --- NUOVO METODO PER IL MANAGER ---
  /// Permette di cambiare manualmente lo stato di un veicolo (es. Disponibile <-> Manutenzione)
  Future<void> aggiornaStatoVeicolo(
      String targa, StatoVeicolo nuovoStato) async {
    _isLoading = true;
    notifyListeners();
    try {
      // 1. Aggiorna sul database (Supabase)
      await supabase.from('veicoli').update({
        'stato': nuovoStato.name
      }) // Assicurati che nel DB la colonna si chiami 'stato'
          .eq('targa', targa);

      // 2. Aggiorna la lista locale per riflettere il cambiamento immediatamente
      final index = _veicoli.indexWhere((v) => v.targa == targa);
      if (index != -1) {
        final v = _veicoli[index];
        _veicoli[index] = Veicolo(
          targa: v.targa,
          marca: v.marca,
          modello: v.modello,
          tipoVeicolo: v.tipoVeicolo,
          annoImmatricolazione: v.annoImmatricolazione,
          km: v.km,
          statoVeicolo: nuovoStato, // Nuovo stato applicato
        );
      }

      // Opzionale: Se metti in Fuori Servizio, potresti voler inviare una notifica automatica ai manager
      if (nuovoStato == StatoVeicolo.fuoriServizio) {
        for (var idMan in _tuttiManagerIds) {
          await _notificaService.notificaInterventoStraordinario(idMan, targa);
        }
      }
    } catch (e) {
      debugPrint("Errore aggiornamento stato veicolo: $e");
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _controllaScadenzeImminenti() async {
    final ora = DateTime.now();
    final tra30Giorni = ora.add(const Duration(days: 30));

    for (final scadenza in _scadenze) {
      if (!scadenza.notificata &&
          scadenza.data.isBefore(tra30Giorni) &&
          scadenza.data.isAfter(ora)) {
        // Invia notifica ai manager
        for (var idMan in _tuttiManagerIds) {
          await _notificaService.inviaNotificaScadenza(
              idMan,
              scadenza.idScadenza,
              scadenza.targa,
              scadenza.tipoScadenza.name,
              scadenza.data);
        }
        // Marca come notificata
        await _scadenzaService.segnaNotificata(scadenza.idScadenza);
      }
    }
  }

  /// --- LOGICA SCADENZE ---
  Future<void> creaScadenza({
    required String targa,
    required TipoScadenza tipoScadenza,
    required DateTime data,
    int? kmScadenza,
    int? mesiScadenza,
    String? descrizione,
  }) async {
    _isLoading = true;
    _safeNotify();
    try {
      final scadenza = Scadenza(
        idScadenza: 0, // ID temporaneo, il DB genererà quello reale
        tipoScadenza: tipoScadenza,
        data: data,
        notificata: false,
        targa: targa,
        kmScadenza: kmScadenza,
        mesiScadenza: mesiScadenza,
        descrizione: descrizione,
      );

      // Crea la scadenza nel DB
      await _scadenzaService.creaScadenza(scadenza);

      // Refresh dei dati per ottenere l'ID corretto dal DB
      await inizializzaDati();

      // Trova la scadenza appena creata per ottenere l'ID corretto
      final scadenzaCreata = _scadenze.firstWhere(
        (s) =>
            s.targa == targa &&
            s.tipoScadenza == tipoScadenza &&
            s.data == data &&
            !s.notificata,
        orElse: () => scadenza,
      );

      // Notifica ai manager della nuova scadenza con l'ID giusto
      for (var idMan in _tuttiManagerIds) {
        await _notificaService.inviaNotificaScadenza(
            idMan, scadenzaCreata.idScadenza, targa, tipoScadenza.name, data);
      }
    } catch (e) {
      debugPrint("Errore nella creazione della scadenza: $e");
      rethrow;
    } finally {
      _isLoading = false;
      _safeNotify();
    }
  }

  Future<void> modificaScadenza({
    required int idScadenza,
    required String targa,
    required TipoScadenza tipoScadenza,
    required DateTime data,
    int? kmScadenza,
    int? mesiScadenza,
    String? descrizione,
  }) async {
    _isLoading = true;
    _safeNotify();
    try {
      final scadenza = Scadenza(
        idScadenza: idScadenza,
        tipoScadenza: tipoScadenza,
        data: data,
        notificata: false,
        targa: targa,
        kmScadenza: kmScadenza,
        mesiScadenza: mesiScadenza,
        descrizione: descrizione,
      );
      await _scadenzaService.modificaScadenza(idScadenza, scadenza);
      await inizializzaDati();
    } catch (e) {
      debugPrint("Errore nella modifica della scadenza: $e");
      rethrow;
    } finally {
      _isLoading = false;
      _safeNotify();
    }
  }

  Future<void> eliminaScadenza(int idScadenza) async {
    _isLoading = true;
    _safeNotify();
    try {
      await _scadenzaService.eliminaScadenza(idScadenza);
      await inizializzaDati();
    } catch (e) {
      debugPrint("Errore nell'eliminazione della scadenza: $e");
      rethrow;
    } finally {
      _isLoading = false;
      _safeNotify();
    }
  }

  Future<void> chiudiScadenza({
    required int idScadenza,
    required double costo,
    required String dettagli,
  }) async {
    _isLoading = true;
    _safeNotify();
    try {
      await _scadenzaService.chiudiScadenza(idScadenza, costo, dettagli);

      // Notifica ai manager che l'intervento è stato completato
      final scadenza = _scadenze.firstWhere((s) => s.idScadenza == idScadenza);
      for (var idMan in _tuttiManagerIds) {
        await _notificaService.notificaManutenzioneCompletata(
            idMan, scadenza.targa);
      }

      await inizializzaDati();
    } catch (e) {
      debugPrint("Errore nella chiusura della scadenza: $e");
      rethrow;
    } finally {
      _isLoading = false;
      _safeNotify();
    }
  }
}
