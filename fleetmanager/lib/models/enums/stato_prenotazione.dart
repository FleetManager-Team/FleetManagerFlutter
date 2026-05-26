enum StatoPrenotazione {
  richiesta,
  attiva,
  confermata,
  completata,
  annullata,
  sospesa,
  attesaCheckup,
}

extension StatoPrenotazioneDbValue on StatoPrenotazione {
  String get dbValue {
    switch (this) {
      case StatoPrenotazione.attesaCheckup:
        return 'attesa_checkup';
      case StatoPrenotazione.richiesta:
      case StatoPrenotazione.attiva:
      case StatoPrenotazione.confermata:
      case StatoPrenotazione.completata:
      case StatoPrenotazione.annullata:
      case StatoPrenotazione.sospesa:
        return name;
    }
  }
}
