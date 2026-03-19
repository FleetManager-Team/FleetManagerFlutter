enum RuoloUtente {
  driver,
  manager;

  String get label {
    switch (this) {
      case RuoloUtente.driver: return "Conducente";
      case RuoloUtente.manager: return "Manager";
    }
  }
}