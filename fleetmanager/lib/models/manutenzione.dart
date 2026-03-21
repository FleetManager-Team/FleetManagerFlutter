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

  factory Manutenzione.fromJson(Map<String, dynamic> json) {
    return Manutenzione(
      idManutenzione: json['id_manutenzione'],
      data: DateTime.parse(json['data']),
      oraFine: json['ora_fine'] != null ? DateTime.parse(json['ora_fine']) : null,
      tipoManutenzione: TipoManutenzione.values.firstWhere((e) => e.name == json['tipo']),
      descrizione: json['descrizione'],
      targa: json['targa'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id_manutenzione': idManutenzione,
      'data': data.toIso8601String(),
      'ora_fine': oraFine?.toIso8601String(),
      'tipo': tipoManutenzione.name,
      'descrizione': descrizione,
      'targa': targa,
    };
  }
}