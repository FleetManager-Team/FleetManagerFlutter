import 'package:flutter/material.dart';
import '../models/veicolo.dart';
import '../models/prenotazione.dart';
import '../models/utente.dart';
import '../services/veicolo_service.dart';
import '../services/prenotazione_service.dart';

class FleetProvider with ChangeNotifier {
  // Istanze dei Service
  final VeicoloService _veicoloService = VeicoloService();
  final PrenotazioneService _prenotazioneService = PrenotazioneService();

  // Stato dell'app
  List<Veicolo> _veicoli = [];
  List<Prenotazione> _prenotazioni = [];
  Utente? _utenteLoggato;
  bool _isLoading = false;

  // Getter per leggere i dati dalla UI
  List<Veicolo> get veicoli => _veicoli;
  List<Prenotazione> get prenotazioni => _prenotazioni;
  Utente? get utenteLoggato => _utenteLoggato;
  bool get isLoading => _isLoading;

  // Caricamento iniziale dei dati
  Future<void> inizializzaDati() async {
    _isLoading = true;
    notifyListeners(); // Diciamo alla UI di mostrare il caricamento

    try {
      _veicoli = await _veicoloService.fetchAllVeicoli();
      
      // Logica presa da GestorePrenotazioniImpl.java: 
      // Se è admin vede tutto, se è driver vede solo le sue
      if (_utenteLoggato?.ruoloUtente.name == 'admin') {
        _prenotazioni = await _prenotazioneService.fetchPrenotazioni();
      } else {
        _prenotazioni = await _prenotazioneService.fetchPrenotazioni(idUtente: _utenteLoggato?.idUtente);
      }
    } catch (e) {
      print("Errore nel caricamento dati: $e");
    } finally {
      _isLoading = false;
      notifyListeners(); // Diciamo alla UI di nascondere il caricamento e mostrare i dati
    }
  }

  // Metodo per fare il login (settando l'utente globale)
  void setUtente(Utente utente) {
    _utenteLoggato = utente;
    inizializzaDati(); // Appena loggato, carica subito i dati giusti per lui
    notifyListeners();
  }
}