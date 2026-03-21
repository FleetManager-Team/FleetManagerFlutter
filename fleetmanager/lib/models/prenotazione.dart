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
      idPrenotazione: json['id_prenotazione'],
      dataInizio: DateTime.parse(json['data_inizio']),
      dataFine: DateTime.parse(json['data_fine']),
      statoPrenotazione: StatoPrenotazione.values.firstWhere((e) => e.name == json['stato']),
      tipoPrenotazione: TipoPrenotazione.values.firstWhere((e) => e.name == json['tipo']),
      idUtente: json['id_utente'],
      targa: json['targa'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id_prenotazione': idPrenotazione,
      'data_inizio': dataInizio.toIso8601String(),
      'data_fine': dataFine.toIso8601String(),
      'stato': statoPrenotazione.name,
      'tipo': tipoPrenotazione.name,
      'id_utente': idUtente,
      'targa': targa,
    };
  }
}