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
    Utente(
      idUtente: 1,
      nome: 'Pietro',
      cognome: 'Plati',
      email: 'a',
      password: 'a',
      ruoloUtente: RuoloUtente.admin,
      patente: 'B',
    ),
    Utente(
      idUtente: 2,
      nome: 'Francesco',
      cognome: 'Basis',
      email: 'b',
      password: 'b',
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
  ];

  static final List<Prenotazione> prenotazioni = [
    Prenotazione(
      idPrenotazione: 1,
      dataInizio: DateTime.now().subtract(const Duration(days: 2)),
      dataFine: DateTime.now().add(const Duration(days: 1)),
      statoPrenotazione: StatoPrenotazione.inCorso,
      tipoPrenotazione: TipoPrenotazione.aziendale,
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
  ];

  static Utente? findUser(String email, String password) {
    try {
      return utenti.firstWhere((u) => u.email == email && u.password == password);
    } catch (_) {
      return null;
    }
  }

  static List<Prenotazione> prenotazioniPerUtente(int? idUtente) {
    if (idUtente == null) return prenotazioni;
    return prenotazioni.where((p) => p.idUtente == idUtente).toList();
  }
}
