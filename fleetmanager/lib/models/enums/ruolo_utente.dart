enum RuoloUtente {
  admin,
  driver;

  String get label {
    switch (this) {
      case RuoloUtente.admin: return "Amministratore";
      case RuoloUtente.driver: return "Conducente";
    }
  }
}