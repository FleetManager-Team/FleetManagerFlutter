// Servizio autenticazione
import 'package:dio/dio.dart';
import '../models/utente.dart';

class AuthService {
  final Dio _dio = Dio(BaseOptions(baseUrl: 'http://localhost:8080/api'));

  // Sostituisce login
  Future<Utente?> login(String email, String password) async {
    try {
      final response = await _dio.post('/login', data: {
        'email': email,
        'password': password
      });
      return Utente.fromJson(response.data);
    } catch (e) {
      return null; // Login fallito come nel tuo Java
    }
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
}