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

  // --- AGGIUNTO: Metodo copyWith per permettere gli aggiornamenti nel Provider ---
  Prenotazione copyWith({
    int? idPrenotazione,
    DateTime? dataInizio,
    DateTime? dataFine,
    StatoPrenotazione? statoPrenotazione,
    TipoPrenotazione? tipoPrenotazione,
    int? idUtente,
    String? targa,
  }) {
    return Prenotazione(
      idPrenotazione: idPrenotazione ?? this.idPrenotazione,
      dataInizio: dataInizio ?? this.dataInizio,
      dataFine: dataFine ?? this.dataFine,
      statoPrenotazione: statoPrenotazione ?? this.statoPrenotazione,
      tipoPrenotazione: tipoPrenotazione ?? this.tipoPrenotazione,
      idUtente: idUtente ?? this.idUtente,
      targa: targa ?? this.targa,
    );
  }

  factory Prenotazione.fromJson(Map<String, dynamic> json) {
    return Prenotazione(
      idPrenotazione: json['id_prenotazione'],
      dataInizio: DateTime.parse(json['data_inizio']).toLocal(),
      dataFine: DateTime.parse(json['data_fine']).toLocal(),
      statoPrenotazione: _mapStato(json[
          'stato']), 
      tipoPrenotazione: TipoPrenotazione.values.firstWhere(
        (e) => e.name.toLowerCase() == json['tipo'].toString().toLowerCase(),
        orElse: () => TipoPrenotazione.utente,
      ),
      idUtente: json['id_utente'],
      targa: json['targa'],
    );
  }
  static StatoPrenotazione _mapStato(String? stato) {
    switch (stato) {
      case 'richiesta':
        return StatoPrenotazione.richiesta;
      case 'confermata':
        return StatoPrenotazione.confermata;
      case 'attesa_checkup':
        return StatoPrenotazione.attesaCheckup;
      case 'attiva':
        return StatoPrenotazione.attiva;
      case 'completata':
        return StatoPrenotazione.completata;
      case 'annullata':
        return StatoPrenotazione.annullata;
      case 'sospesa':
        return StatoPrenotazione.sospesa;
      default:
        return StatoPrenotazione.richiesta;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id_prenotazione': idPrenotazione,
      'data_inizio': dataInizio.toUtc().toIso8601String(),
      'data_fine': dataFine.toUtc().toIso8601String(),
      'stato': statoPrenotazione.name,
      'tipo': tipoPrenotazione.name,
      'id_utente': idUtente,
      'targa': targa,
    };
  }
}
