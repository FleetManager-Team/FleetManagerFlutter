enum StatoVeicolo {
  disponibile,
  inManutenzione,
  prenotato,
  fuoriServizio;

  // Questo metodo serve per mostrare nomi leggibili nella UI di Flutter
  String get nameToDisplay {
    switch (this) {
      case StatoVeicolo.disponibile: return "Disponibile";
      case StatoVeicolo.inManutenzione: return "In Manutenzione";
      case StatoVeicolo.prenotato: return "Prenotato";
      case StatoVeicolo.fuoriServizio: return "Fuori Servizio";
    }
  }
}