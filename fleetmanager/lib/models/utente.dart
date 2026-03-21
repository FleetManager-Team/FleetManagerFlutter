import 'enums/ruolo_utente.dart';

class Utente {
  final int idUtente;
  final String nome;
  final String cognome;
  final String email;
  final String? password; 
  final RuoloUtente ruoloUtente;
  final String? patente; 

  Utente({
    required this.idUtente,
    required this.nome,
    required this.cognome,
    required this.email,
    this.password,
    required this.ruoloUtente,
    this.patente,
  });

  factory Utente.fromJson(Map<String, dynamic> json) {
    return Utente(
      idUtente: json['id_utente'],
      nome: json['nome'],
      cognome: json['cognome'],
      email: json['email'],
      ruoloUtente: RuoloUtente.values.firstWhere((e) => e.name == json['ruolo']),
      patente: json['patente'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id_utente': idUtente,
      'nome': nome,
      'cognome': cognome,
      'email': email,
      'ruolo': ruoloUtente.name,
      'patente': patente,
    };
  }
}