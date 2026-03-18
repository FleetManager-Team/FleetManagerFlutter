enum RuoloUtente {
  admin,
  driver,
  manager;

  String get label {
    switch (this) {
      case RuoloUtente.admin: return "Amministratore";
      case RuoloUtente.driver: return "Conducente";
      case RuoloUtente.manager: return "Manager";
    }
  }
}