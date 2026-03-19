import 'package:fleetmanager/models/enums/ruolo_utente.dart';
import 'package:fleetmanager/models/enums/stato_prenotazione.dart';
import 'package:fleetmanager/models/enums/stato_veicolo.dart';
import 'package:fleetmanager/models/enums/tipo_prenotazione.dart';
import 'package:fleetmanager/models/enums/tipo_veicolo.dart';
import 'package:fleetmanager/models/prenotazione.dart';
import 'package:fleetmanager/models/utente.dart';
import 'package:fleetmanager/models/veicolo.dart';

/// Dati fittizi utili per sviluppare e testare l'app senza un backend.
class MockData {
  static final List<Utente> utenti = [
    // Credenziali semplici per test rapido (a/a e b/b)
    Utente(
      idUtente: 1,
      nome: 'Test Admin',
      cognome: 'Mock',
      email: 'a',
      password: 'a',
      ruoloUtente: RuoloUtente.manager,
      patente: 'B',
    ),
    Utente(
      idUtente: 2,
      nome: 'Test Driver',
      cognome: 'Mock',
      email: 'b',
      password: 'b',
      ruoloUtente: RuoloUtente.driver,
      patente: 'B',
    ),
    Utente(
      idUtente: 5,
      nome: 'Giulia',
      cognome: 'Verdi',
      email: 'giulia@fleet.it',
      password: 'b',
      ruoloUtente: RuoloUtente.driver,
      patente: 'B',
    ),
    Utente(
      idUtente: 6,
      nome: 'Marco',
      cognome: 'Rossi',
      email: 'marco@manager.it',
      password: 'a',
      ruoloUtente: RuoloUtente.manager,
      patente: 'B',
    ),

    // Credenziali più realistiche per test avanzato
    Utente(
      idUtente: 3,
      nome: 'Pietro',
      cognome: 'Plati',
      email: 'admin@fleetmanager.com',
      password: 'Password1',
      ruoloUtente: RuoloUtente.manager,
      patente: 'B',
    ),
    Utente(
      idUtente: 4,
      nome: 'Francesco',
      cognome: 'Basis',
      email: 'driver@fleetmanager.com',
      password: 'Password1',
      ruoloUtente: RuoloUtente.driver,
      patente: 'B',
    ),
  ];

  static final List<Veicolo> veicoli = [
    Veicolo(
      targa: 'AB123CD',
      tipoVeicolo: TipoVeicolo.auto,
      marca: 'Fiat',
      modello: 'Punto',
      annoImmatricolazione: 2018,
      statoVeicolo: StatoVeicolo.disponibile,
      km: 52000,
    ),
    Veicolo(
      targa: 'EF456GH',
      tipoVeicolo: TipoVeicolo.furgone,
      marca: 'Renault',
      modello: 'Kangoo',
      annoImmatricolazione: 2020,
      statoVeicolo: StatoVeicolo.inManutenzione,
      km: 78000,
    ),
    Veicolo(
      targa: 'IJ789KL',
      tipoVeicolo: TipoVeicolo.auto,
      marca: 'Toyota',
      modello: 'Yaris',
      annoImmatricolazione: 2022,
      statoVeicolo: StatoVeicolo.prenotato,
      km: 15000,
    ),
    Veicolo(
      targa: 'MN012OP',
      tipoVeicolo: TipoVeicolo.auto,
      marca: 'Volkswagen',
      modello: 'Golf',
      annoImmatricolazione: 2019,
      statoVeicolo: StatoVeicolo.disponibile,
      km: 45000,
    ),
    Veicolo(
      targa: 'QR345ST',
      tipoVeicolo: TipoVeicolo.auto,
      marca: 'Ford',
      modello: 'Focus',
      annoImmatricolazione: 2021,
      statoVeicolo: StatoVeicolo.disponibile,
      km: 30000,
    ),
    Veicolo(
      targa: 'UV678WX',
      tipoVeicolo: TipoVeicolo.furgone,
      marca: 'Mercedes',
      modello: 'Vito',
      annoImmatricolazione: 2017,
      statoVeicolo: StatoVeicolo.fuoriServizio,
      km: 120000,
    ),
    Veicolo(
      targa: 'ZA999ZZ',
      tipoVeicolo: TipoVeicolo.furgone,
      marca: 'Iveco',
      modello: 'Daily',
      annoImmatricolazione: 2023,
      statoVeicolo: StatoVeicolo.disponibile,
      km: 500, 
    ),
    Veicolo(
      targa: 'XX000XX',
      tipoVeicolo: TipoVeicolo.auto,
      marca: 'Tesla',
      modello: 'Model 3',
      annoImmatricolazione: 2022,
      statoVeicolo: StatoVeicolo.fuoriServizio,
      km: 45000,
    ),
  ];

  static final List<Prenotazione> prenotazioni = [
    Prenotazione(
      idPrenotazione: 1,
      dataInizio: DateTime.now().subtract(const Duration(days: 2)),
      dataFine: DateTime.now().add(const Duration(days: 1)),
      statoPrenotazione: StatoPrenotazione.attiva,
      tipoPrenotazione: TipoPrenotazione.utente,
      idUtente: 2,
      targa: 'IJ789KL',
    ),
    Prenotazione(
      idPrenotazione: 2,
      dataInizio: DateTime.now().add(const Duration(days: 3)),
      dataFine: DateTime.now().add(const Duration(days: 7)),
      statoPrenotazione: StatoPrenotazione.confermata,
      tipoPrenotazione: TipoPrenotazione.privata,
      idUtente: 2,
      targa: 'AB123CD',
    ),
// --- PRENOTAZIONI PASSATE (Per testare lo Storico) ---
    Prenotazione(
      idPrenotazione: 10,
      dataInizio: DateTime.now().subtract(const Duration(days: 15)),
      dataFine: DateTime.now().subtract(const Duration(days: 12)),
      statoPrenotazione: StatoPrenotazione.completata,
      tipoPrenotazione: TipoPrenotazione.utente,
      idUtente: 2,
      targa: 'AB123CD',
    ),
    Prenotazione(
      idPrenotazione: 11,
      dataInizio: DateTime.now().subtract(const Duration(days: 10)),
      dataFine: DateTime.now().subtract(const Duration(days: 9)),
      statoPrenotazione: StatoPrenotazione.annullata,
      tipoPrenotazione: TipoPrenotazione.utente,
      idUtente: 5,
      targa: 'MN012OP',
    ),
    Prenotazione(
      idPrenotazione: 12,
      dataInizio: DateTime.now().subtract(const Duration(days: 5)),
      dataFine: DateTime.now().subtract(const Duration(days: 4)),
      statoPrenotazione: StatoPrenotazione.completata,
      tipoPrenotazione: TipoPrenotazione.privata,
      idUtente: 2,
      targa: 'QR345ST',
    ),
  ];

  static Utente? findUser(String email, String password) {
    try {
      return utenti
          .firstWhere((u) => u.email == email && u.password == password);
    } catch (_) {
      return null;
    }
  }

  static List<Prenotazione> prenotazioniPerUtente(int? idUtente) {
    if (idUtente == null) return prenotazioni;
    return prenotazioni.where((p) => p.idUtente == idUtente).toList();
  }

  static bool validaDisponibilita(
      String targa, DateTime dataInizio, DateTime dataFine) {
    for (var p in prenotazioni) {
      if (p.targa == targa &&
          p.statoPrenotazione != StatoPrenotazione.annullata) {
        bool overlap =
            dataInizio.isBefore(p.dataFine) && dataFine.isAfter(p.dataInizio);
        if (overlap) return false;
      }
    }
    return true;
  }
}
