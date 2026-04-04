import 'package:fleetmanager/models/enums/tipo_prenotazione.dart';
import 'package:fleetmanager/models/manutenzione.dart';
import 'package:fleetmanager/models/enums/ruolo_utente.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/veicolo.dart';
import '../models/prenotazione.dart';
import '../models/utente.dart';
import '../models/notifica.dart';
import '../models/restituzione.dart'; // <--- Assicurati che il path sia corretto
import '../models/enums/stato_veicolo.dart';
import '../models/enums/stato_prenotazione.dart';
import '../models/enums/tipo_manutenzione.dart';
import '../services/auth_service.dart';
import '../services/prenotazione_service.dart';
import '../services/manutenzione_service.dart';
import '../services/notifica_service.dart';
import '../services/veicolo_service.dart';

class SpesaDriver {
  int idUtente;
  double carburante = 0;
  double pedaggi = 0;

  SpesaDriver({this.idUtente = 0, this.carburante = 0, this.pedaggi = 0});

  double get totale => carburante + pedaggi;
}

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
  List<Restituzione> _restituzioni = []; // <--- AGGIUNTO
  Utente? _utenteLoggato;
  bool _isLoading = false;

  // Getter
  List<Veicolo> get veicoli => _veicoli;
  List<Prenotazione> get prenotazioni => _prenotazioni;
  List<Manutenzione> get manutenzioni => _manutenzioni;
  List<Notifica> get notifiche => _notifiche;
  List<Restituzione> get restituzioni => _restituzioni; // <--- AGGIUNTO
  Utente? get utenteLoggato => _utenteLoggato;
  List<Utente> get utenti => _utenti;
  bool get isLoading => _isLoading;

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
        Supabase.instance.client.from('restituzioni').select(),
        _utenteLoggato != null
            ? _notificaService.fetchMieNotifiche(_utenteLoggato!.idUtente)
            : Future.value(<Notifica>[]), // Forza il tipo Notifica qui
      ]);

      _veicoli = List<Veicolo>.from(risultati[0]);
      _prenotazioni = List<Prenotazione>.from(risultati[1]);
      _utenti = List<Utente>.from(risultati[2]);
      _manutenzioni = List<Manutenzione>.from(risultati[3]);

      // Gestione sicura per le Restituzioni
      final datiRestituzioni = risultati[4] as List<dynamic>;
      _restituzioni =
          datiRestituzioni.map((json) => Restituzione.fromJson(json)).toList();

      final datiNotifiche = risultati[5] as List<dynamic>;
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
      final user = await _authService.login(email.trim(), password);

      if (user != null) {
        _utenteLoggato = user;
        await inizializzaDati();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("Errore login nel Provider: $e");
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

  Future<bool> recuperaPassword(String email) async {
    _isLoading = true;
    _safeNotify();

    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(
        email.trim(),
      );

      return true;
    } catch (e) {
      debugPrint("Errore recupero password: $e");
      return false;
    } finally {
      _isLoading = false;
      _safeNotify();
    }
  }

  Future<bool> aggiornaPassword(String nuovaPassword) async {
    _isLoading = true;
    notifyListeners();
    try {
      await Supabase.instance.client.auth.updateUser(
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
    _safeNotify();
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
        dataInizio: inizio.toUtc(),
        dataFine: fine.toUtc(),
        statoPrenotazione: StatoPrenotazione.richiesta,
        tipoPrenotazione: TipoPrenotazione.utente,
        idUtente: driver.idUtente,
        targa: veicolo.targa,
      );
      await _prenotazioneService.creaPrenotazione(p);

      for (var idManager in _tuttiManagerIds) {
        await _notificaService.notificaRichiestaPrenotazione(idManager,
            "${driver.nome} ${driver.cognome}", veicolo.targa, inizio, fine);
      }
      await inizializzaDati();
    } finally {
      _isLoading = false;
      _safeNotify();
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
      if (idDaEscludere != null && p.idPrenotazione == idDaEscludere) {
        return false;
      }
      if (p.statoPrenotazione == StatoPrenotazione.annullata ||
          p.statoPrenotazione == StatoPrenotazione.completata) {
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
    if (WidgetsBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) => notifyListeners());
    } else {
      notifyListeners();
    }
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
}
