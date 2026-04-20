import 'enums/tipo_scadenza.dart';

class Scadenza {
  final int idScadenza;
  final TipoScadenza tipoScadenza;
  final DateTime data;
  final bool notificata;
  final String targa;
  final int? kmScadenza; // per tagliandi basati su km
  final int? mesiScadenza; // per tagliandi basati su tempo
  final bool chiusa; // se l'intervento è stato completato
  final DateTime? dataChiusura; // quando è stato chiuso
  final double? costoChiusura; // costo dell'intervento
  final String? dettagliChiusura; // dettagli dell'intervento completato
  final String? descrizione; // descrizione della scadenza (es. tipo manutenzione)

  Scadenza({
    required this.idScadenza,
    required this.tipoScadenza,
    required this.data,
    required this.notificata,
    required this.targa,
    this.kmScadenza,
    this.mesiScadenza,
    this.chiusa = false,
    this.dataChiusura,
    this.costoChiusura,
    this.dettagliChiusura,
    this.descrizione,
  });

  factory Scadenza.fromJson(Map<String, dynamic> json) {
    return Scadenza(
      idScadenza: json['id_scadenza'],
      tipoScadenza: TipoScadenza.values.firstWhere((e) => e.name == json['tipo']),
      data: DateTime.parse(json['data']),
      notificata: json['notificata'] ?? false,
      targa: json['targa'],
      kmScadenza: json['km_scadenza'],
      mesiScadenza: json['mesi_scadenza'],
      chiusa: json['chiusa'] ?? false,
      dataChiusura: json['data_chiusura'] != null ? DateTime.parse(json['data_chiusura']) : null,
      costoChiusura: (json['costo_chiusura'] as num?)?.toDouble(),
      dettagliChiusura: json['dettagli_chiusura'],
      descrizione: json['descrizione'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id_scadenza': idScadenza,
      'tipo': tipoScadenza.name,
      'data': data.toIso8601String(),
      'notificata': notificata,
      'targa': targa,
      'km_scadenza': kmScadenza,
      'mesi_scadenza': mesiScadenza,
      'chiusa': chiusa,
      'data_chiusura': dataChiusura?.toIso8601String(),
      'costo_chiusura': costoChiusura,
      'dettagli_chiusura': dettagliChiusura,
      'descrizione': descrizione,
    };
  }

  // Crea una copia con modifiche
  Scadenza copyWith({
    int? idScadenza,
    TipoScadenza? tipoScadenza,
    DateTime? data,
    bool? notificata,
    String? targa,
    int? kmScadenza,
    int? mesiScadenza,
    bool? chiusa,
    DateTime? dataChiusura,
    double? costoChiusura,
    String? dettagliChiusura,
    String? descrizione,
  }) {
    return Scadenza(
      idScadenza: idScadenza ?? this.idScadenza,
      tipoScadenza: tipoScadenza ?? this.tipoScadenza,
      data: data ?? this.data,
      notificata: notificata ?? this.notificata,
      targa: targa ?? this.targa,
      kmScadenza: kmScadenza ?? this.kmScadenza,
      mesiScadenza: mesiScadenza ?? this.mesiScadenza,
      chiusa: chiusa ?? this.chiusa,
      dataChiusura: dataChiusura ?? this.dataChiusura,
      costoChiusura: costoChiusura ?? this.costoChiusura,
      dettagliChiusura: dettagliChiusura ?? this.dettagliChiusura,
      descrizione: descrizione ?? this.descrizione,
    );
  }
}