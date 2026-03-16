import 'enums/tipo_notifica.dart';

class Notifica {
  final int? idNotifica; // Nullable perché può essere creata localmente prima del salvataggio
  final TipoNotifica tipoNotifica;
  final String messaggio;
  final DateTime dataInvio;
  final bool letta;
  final int idUtente;
  final int? idScadenza; // Nullable come nel tuo Java

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
      idNotifica: json['idNotifica'],
      tipoNotifica: TipoNotifica.values.firstWhere((e) => e.name == json['tipoNotifica']),
      messaggio: json['messaggio'],
      dataInvio: DateTime.parse(json['dataInvio']),
      letta: json['letta'] ?? false,
      idUtente: json['idUtente'],
      idScadenza: json['idScadenza'],
    );
  }
}