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

  Veicolo({
    required this.targa,
    required this.tipoVeicolo,
    required this.marca,
    required this.modello,
    required this.annoImmatricolazione,
    required this.statoVeicolo,
    required this.km,
  });

  factory Veicolo.fromJson(Map<String, dynamic> json) {
    return Veicolo(
      targa: json['targa'],
      tipoVeicolo: TipoVeicolo.values.firstWhere((e) => e.name == json['tipo']),
      marca: json['marca'],
      modello: json['modello'],
      annoImmatricolazione: json['anno_immatricolazione'],
      statoVeicolo: StatoVeicolo.values.firstWhere((e) => e.name == json['stato']),
      km: json['km'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'targa': targa,
      'tipo': tipoVeicolo.name,
      'marca': marca,
      'modello': modello,
      'anno_immatricolazione': annoImmatricolazione,
      'stato': statoVeicolo.name,
      'km': km,
    };
  }
}