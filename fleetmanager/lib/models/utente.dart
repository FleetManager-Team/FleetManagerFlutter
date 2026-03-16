import 'enums/ruolo_utente.dart';

class Utente {
  final int idUtente;
  final String nome;
  final String cognome;
  final String email;
  final String? password; // Opzionale se riceviamo i dati dal server
  final RuoloUtente ruoloUtente;
  final String? patente; // Può essere nullo

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
      idUtente: json['idUtente'],
      nome: json['nome'],
      cognome: json['cognome'],
      email: json['email'],
      ruoloUtente: RuoloUtente.values.firstWhere((e) => e.name == json['ruoloUtente']),
      patente: json['patente'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'idUtente': idUtente,
      'nome': nome,
      'cognome': cognome,
      'email': email,
      'password': password,
      'ruoloUtente': ruoloUtente.name,
      'patente': patente,
    };
  }
}