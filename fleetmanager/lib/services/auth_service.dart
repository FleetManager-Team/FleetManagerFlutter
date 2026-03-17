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
}