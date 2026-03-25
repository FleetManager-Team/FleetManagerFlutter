import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/veicolo.dart';
import '../models/enums/stato_veicolo.dart';

class VeicoloService {
  final _supabase = Supabase.instance.client;

  Future<List<Veicolo>> fetchAllVeicoli() async {
    final response = await _supabase.from('veicoli').select();
    return (response as List).map((json) => Veicolo.fromJson(json)).toList();
  }

  Future<void> updateStatoVeicolo(String targa, StatoVeicolo nuovoStato) async {
    await _supabase
        .from('veicoli')
        .update({'stato': nuovoStato.name}).eq('targa', targa);
  }

  Future<void> createVeicolo(Veicolo veicolo) async {
    await _supabase.from('veicoli').insert(veicolo.toJson());
  }

  Future<Veicolo?> getVeicoloByTarga(String targa) async {
    try {
      final response = await _supabase
          .from('veicoli')
          .select()
          .eq('targa', targa.trim().toUpperCase())
          .maybeSingle(); // Importante: non va in crash se non trova nulla

      if (response == null) return null;
      return Veicolo.fromJson(response);
    } catch (e) {
      print("Errore VeicoloService: $e");
      return null;
    }
  }
}
