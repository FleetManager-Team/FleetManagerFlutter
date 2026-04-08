class CheckupVeicolo {
  final String? id;
  final int idPrenotazione;
  final String targa;
  final String driverId;
  final DateTime dataCheck;
  
  final String urlFotoFronte;
  final String urlFotoRetro;
  final String urlFotoDx;
  final String urlFotoSx;
  
  final bool luciOk;
  final bool gommeOk;
  final bool interniOk; 
  final String? noteDanni;
  final String? urlFirma;

  CheckupVeicolo({
    this.id,
    required this.idPrenotazione,
    required this.targa,
    required this.driverId,
    required this.dataCheck,
    required this.urlFotoFronte,
    required this.urlFotoRetro,
    required this.urlFotoDx,
    required this.urlFotoSx,
    this.luciOk = true,
    this.gommeOk = true,
    this.interniOk = true,
    this.noteDanni,
    this.urlFirma,
  });

  CheckupVeicolo copyWith({
    String? id,
    int? idPrenotazione,
    String? targa,
    String? driverId,
    DateTime? dataCheck,
    String? urlFotoFronte,
    String? urlFotoRetro,
    String? urlFotoDx,
    String? urlFotoSx,
    bool? luciOk,
    bool? gommeOk,
    bool? interniOk,
    String? noteDanni,
    String? urlFirma,
  }) {
    return CheckupVeicolo(
      id: id ?? this.id,
      idPrenotazione: idPrenotazione ?? this.idPrenotazione,
      targa: targa ?? this.targa,
      driverId: driverId ?? this.driverId,
      dataCheck: dataCheck ?? this.dataCheck,
      urlFotoFronte: urlFotoFronte ?? this.urlFotoFronte,
      urlFotoRetro: urlFotoRetro ?? this.urlFotoRetro,
      urlFotoDx: urlFotoDx ?? this.urlFotoDx,
      urlFotoSx: urlFotoSx ?? this.urlFotoSx,
      luciOk: luciOk ?? this.luciOk,
      gommeOk: gommeOk ?? this.gommeOk,
      interniOk: interniOk ?? this.interniOk,
      noteDanni: noteDanni ?? this.noteDanni,
      urlFirma: urlFirma ?? this.urlFirma,
    );
  }

  factory CheckupVeicolo.fromJson(Map<String, dynamic> json) {
    return CheckupVeicolo(
      id: json['id']?.toString(),
      idPrenotazione: json['id_prenotazione'] as int,
      targa: json['targa'] ?? '',
      driverId: json['driver_id'] ?? '',
      dataCheck: DateTime.parse(json['data_check']),
      urlFotoFronte: json['url_foto_fronte'] ?? '',
      urlFotoRetro: json['url_foto_retro'] ?? '',
      urlFotoDx: json['url_foto_dx'] ?? '',
      urlFotoSx: json['url_foto_sx'] ?? '',
      luciOk: json['luci_ok'] ?? true,
      gommeOk: json['gomme_ok'] ?? true,
      interniOk: json['interni_ok'] ?? true,
      noteDanni: json['note_danni'],
      urlFirma: json['url_firma'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id_prenotazione': idPrenotazione,
      'targa': targa,
      'driver_id': driverId,
      'url_foto_fronte': urlFotoFronte,
      'url_foto_retro': urlFotoRetro,
      'url_foto_dx': urlFotoDx,
      'url_foto_sx': urlFotoSx,
      'luci_ok': luciOk,
      'gomme_ok': gommeOk,
      'interni_ok': interniOk,
      'note_danni': noteDanni,
      'url_firma': urlFirma,
    };
  }
}