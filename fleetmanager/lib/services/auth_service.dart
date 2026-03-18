// Servizio autenticazione
import 'package:dio/dio.dart';
import 'package:fleetmanager/mock/mock_data.dart';
import '../models/utente.dart';

class AuthService {
  final Dio _dio = Dio(BaseOptions(baseUrl: 'http://localhost:8080/api'));

  // Sostituisce login
  Future<Utente?> login(String email, String password) async {
    // Primo tentativo: chiediamo al backend (se disponibile)
    try {
      final response = await _dio.post('/login', data: {
        'email': email,
        'password': password,
      });
      if (response.statusCode == 200 && response.data != null) {
        return Utente.fromJson(response.data);
      }
    } catch (_) {
      // Ignoriamo l'errore e utilizziamo il mock
    }

    // Fallback mock (per sviluppo/offline)
    return MockData.findUser(email, password);
  }

  // Sostituisce aggiornaProfilo
  Future<bool> updateProfilo(Utente u) async {
    try {
      await _dio.put('/utenti/${u.idUtente}', data: u.toJson());
      return true;
    } catch (e) {
      return false;
    }
  }

  // Da GestoreLoginImpl: createUtente
  Future<bool> createUtente(Utente nuovoUtente) async {
    if (nuovoUtente.email.isEmpty || nuovoUtente.email.isEmpty) {
      return false;
    }
    try {
      final response = await _dio.post('/utenti', data: nuovoUtente.toJson());
      return response.statusCode == 201;
    } catch (e) {
      return false;
    }
  }

  // Da GestoreLoginImpl: eliminaUtente
  Future<bool> eliminaUtente(int idUtente) async {
    if (idUtente <= 0) {
      return false;
    }
    try {
      await _dio.delete('/utenti/$idUtente');
      return true;
    } catch (e) {
      return false;
    }
  }

  // Da GestoreLoginImpl: getUtenteByEmail
  Future<Utente?> getUtenteByEmail(String email) async {
    if (email.isEmpty) {
      return null;
    }
    try {
      final response = await _dio.get('/utenti/email/$email');
      return Utente.fromJson(response.data);
    } catch (e) {
      return null;
    }
  }

  // Da GestoreLoginImpl: getTuttiUtenti
  Future<List<Utente>> getTuttiUtenti() async {
    try {
      final response = await _dio.get('/utenti');
      List<dynamic> data = response.data;
      return data.map((json) => Utente.fromJson(json)).toList();
    } catch (e) {
      return MockData.utenti;
    }
  }
}