import 'enums/stato_veicolo.dart';
import 'enums/tipo_veicolo.dart';

class Veicolo {
  final String targa;
  final TipoVeicolo tipoVeicolo;
  final String marca;
  final String modello;
  final int annoImmatricolazione;
  final StatoVeicolo statoVeicolo;
  final int km;

  // Costruttore "named" (tipico di Flutter)
  Veicolo({
    required this.targa,
    required this.tipoVeicolo,
    required this.marca,
    required this.modello,
    required this.annoImmatricolazione,
    required this.statoVeicolo,
    required this.km,
  });

  // Metodo Fondamentale: Converte il JSON ricevuto dal DB/API in un oggetto Veicolo
  factory Veicolo.fromJson(Map<String, dynamic> json) {
    return Veicolo(
      targa: json['targa'],
      // Conversione logica: trasformiamo la stringa che arriva dal DB nell'Enum Dart
      tipoVeicolo: TipoVeicolo.values.firstWhere((e) => e.name == json['tipoVeicolo']),
      marca: json['marca'],
      modello: json['modello'],
      annoImmatricolazione: json['annoImmatricolazione'],
      statoVeicolo: StatoVeicolo.values.firstWhere((e) => e.name == json['statoVeicolo']),
      km: json['km'],
    );
  }

  // Converte l'oggetto in JSON per inviarlo al database
  Map<String, dynamic> toJson() {
    return {
      'targa': targa,
      'tipoVeicolo': tipoVeicolo.name,
      'marca': marca,
      'modello': modello,
      'annoImmatricolazione': annoImmatricolazione,
      'statoVeicolo': statoVeicolo.name,
      'km': km,
    };
  }
}