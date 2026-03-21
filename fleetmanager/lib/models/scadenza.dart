import 'enums/tipo_scadenza.dart';

class Scadenza {
  final int idScadenza;
  final TipoScadenza tipoScadenza;
  final DateTime data;
  final bool notificata;
  final String targa;

  Scadenza({
    required this.idScadenza,
    required this.tipoScadenza,
    required this.data,
    required this.notificata,
    required this.targa,
  });

  factory Scadenza.fromJson(Map<String, dynamic> json) {
    return Scadenza(
      idScadenza: json['id_scadenza'],
      tipoScadenza: TipoScadenza.values.firstWhere((e) => e.name == json['tipo']),
      data: DateTime.parse(json['data']),
      notificata: json['notificata'] ?? false,
      targa: json['targa'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id_scadenza': idScadenza,
      'tipo': tipoScadenza.name,
      'data': data.toIso8601String(),
      'notificata': notificata,
      'targa': targa,
    };
  }
}