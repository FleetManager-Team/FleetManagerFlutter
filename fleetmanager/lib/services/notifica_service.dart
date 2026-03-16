import 'package:dio/dio.dart';
import '../models/notifica.dart';

class NotificaService {
  final Dio _dio = Dio(BaseOptions(baseUrl: 'http://localhost:8080/api'));

  Future<List<Notifica>> fetchMieNotifiche(int idUtente) async {
    final response = await _dio.get('/notifiche/utente/$idUtente');
    List<dynamic> data = response.data;
    return data.map((json) => Notifica.fromJson(json)).toList();
  }

  Future<void> segnaLetta(int id) async {
    await _dio.patch('/notifiche/$id/leggi');
  }
}