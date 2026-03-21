import 'enums/tipo_notifica.dart';

class Notifica {
  final int? idNotifica; 
  final TipoNotifica tipoNotifica;
  final String messaggio;
  final DateTime dataInvio;
  final bool letta;
  final int idUtente;
  final int? idScadenza; 

  Notifica({
    this.idNotifica,
    required this.tipoNotifica,
    required this.messaggio,
    required this.dataInvio,
    required this.letta,
    required this.idUtente,
    this.idScadenza,
  });

  factory Notifica.fromJson(Map<String, dynamic> json) {
    return Notifica(
      idNotifica: json['id_notifica'],
      tipoNotifica: TipoNotifica.values.firstWhere((e) => e.name == json['tipo']),
      messaggio: json['messaggio'],
      dataInvio: DateTime.parse(json['data_invio']),
      letta: json['letta'] ?? false,
      idUtente: json['id_utente'],
      idScadenza: json['id_scadenza'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (idNotifica != null) 'id_notifica': idNotifica,
      'tipo': tipoNotifica.name,
      'messaggio': messaggio,
      'data_invio': dataInvio.toIso8601String(),
      'letta': letta,
      'id_utente': idUtente,
      'id_scadenza': idScadenza,
    };
  }
}