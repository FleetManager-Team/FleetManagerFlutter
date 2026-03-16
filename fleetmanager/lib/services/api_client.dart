import 'package:dio/dio.dart';

class ApiClient {
  // Per ora usiamo un indirizzo fittizio o il tuo IP locale dove girerà Spring Boot
  static const String baseUrl = "http://localhost:8080/api"; 
  
  final Dio dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 5), // Massimo 5 secondi per connettersi
    receiveTimeout: const Duration(seconds: 3),
  ));
}