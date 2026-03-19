import 'enums/stato_prenotazione.dart';
import 'enums/tipo_prenotazione.dart';

class Prenotazione {
  final int idPrenotazione;
  final DateTime dataInizio;
  final DateTime dataFine;
  final StatoPrenotazione statoPrenotazione;
  final TipoPrenotazione tipoPrenotazione;
  final int idUtente;
  final String targa;

  var inizio;

  Prenotazione({
    required this.idPrenotazione,
    required this.dataInizio,
    required this.dataFine,
    required this.statoPrenotazione,
    required this.tipoPrenotazione,
    required this.idUtente,
    required this.targa,
  });

  factory Prenotazione.fromJson(Map<String, dynamic> json) {
    return Prenotazione(
      idPrenotazione: json['idPrenotazione'],
      dataInizio: DateTime.parse(json['dataInizio']),
      dataFine: DateTime.parse(json['dataFine']),
      statoPrenotazione: StatoPrenotazione.values.firstWhere((e) => e.name == json['statoPrenotazione']),
      tipoPrenotazione: TipoPrenotazione.values.firstWhere((e) => e.name == json['tipoPrenotazione']),
      idUtente: json['idUtente'],
      targa: json['targa'],
    );
  }

  get veicoloId => null;

  Map<String, dynamic> toJson() {
    return {
      'idPrenotazione': idPrenotazione,
      'dataInizio': dataInizio.toIso8601String(),
      'dataFine': dataFine.toIso8601String(),
      'statoPrenotazione': statoPrenotazione.name,
      'tipoPrenotazione': tipoPrenotazione.name,
      'idUtente': idUtente,
      'targa': targa,
    };
  }
}