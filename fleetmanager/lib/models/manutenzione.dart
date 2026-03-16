import 'enums/tipo_manutenzione.dart';

class Manutenzione {
  final int idManutenzione;
  final DateTime data;
  final DateTime? oraFine; 
  final TipoManutenzione tipoManutenzione;
  final String descrizione;
  final String targa;

  Manutenzione({
    required this.idManutenzione,
    required this.data,
    this.oraFine,
    required this.tipoManutenzione,
    required this.descrizione,
    required this.targa,
  });

  Map<String, dynamic> toJson() {
    return {
      'idManutenzione': idManutenzione,
      'data': data.toIso8601String(),
      'oraFine': oraFine?.toIso8601String(),
      'tipoManutenzione': tipoManutenzione.name,
      'descrizione': descrizione,
      'targa': targa,
    };
  }

  factory Manutenzione.fromJson(Map<String, dynamic> json) {
    return Manutenzione(
      idManutenzione: json['idManutenzione'],
      data: DateTime.parse(json['data']),
      oraFine: json['oraFine'] != null ? DateTime.parse(json['oraFine']) : null,
      tipoManutenzione: TipoManutenzione.values.firstWhere((e) => e.name == json['tipoManutenzione']),
      descrizione: json['descrizione'],
      targa: json['targa'],
    );
  }
}