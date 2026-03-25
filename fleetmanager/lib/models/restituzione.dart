class Restituzione {
  final int? idRestituzione; // Generato da Supabase
  final int idPrenotazione;
  final int kmFinali;
  final DateTime dataRestituzione;

  // Carburante
  final bool rifornimentoEffettuato;
  final double? litriCarburante;
  final double? importoEuro;
  final String? urlScontrino;

  // Danni
  final bool danniPresenti;
  final String? descrizioneDanni;
  final String? urlFotoDanni;

  Restituzione({
    this.idRestituzione,
    required this.idPrenotazione,
    required this.kmFinali,
    required this.dataRestituzione,
    required this.rifornimentoEffettuato,
    this.litriCarburante,
    this.importoEuro,
    this.urlScontrino,
    required this.danniPresenti,
    this.descrizioneDanni,
    this.urlFotoDanni,
  });

  factory Restituzione.fromJson(Map<String, dynamic> json) {
    return Restituzione(
      idRestituzione: json['id_restituzione'],
      idPrenotazione: json['id_prenotazione'],
      kmFinali: json['km_finali'],
      dataRestituzione: DateTime.parse(json['data_restituzione']).toLocal(),
      rifornimentoEffettuato: json['rifornimento_effettuato'] ?? false,
      litriCarburante: json['litri_carburante']?.toDouble(),
      importoEuro: json['importo_euro']?.toDouble(),
      urlScontrino: json['url_scontrino'],
      danniPresenti: json['danni_presenti'] ?? false,
      descrizioneDanni: json['descrizione_danni'],
      urlFotoDanni: json['url_foto_danni'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (idRestituzione != null) 'id_restituzione': idRestituzione,
      'id_prenotazione': idPrenotazione,
      'km_finali': kmFinali,
      'data_restituzione': dataRestituzione.toIso8601String(),
      'rifornimento_effettuato': rifornimentoEffettuato,
      'litri_carburante': litriCarburante,
      'importo_euro': importoEuro,
      'url_scontrino': urlScontrino,
      'danni_presenti': danniPresenti,
      'descrizione_danni': descrizioneDanni,
      'url_foto_danni': urlFotoDanni,
    };
  }
}
