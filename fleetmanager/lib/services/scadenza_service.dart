import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/scadenza.dart';

class ScadenzaService {
  final SupabaseClient _supabase;

  ScadenzaService({SupabaseClient? supabaseClient})
      : _supabase = supabaseClient ?? Supabase.instance.client;

  Future<List<Scadenza>> fetchTutteLeScadenze() async {
    final response = await _supabase.from('scadenze').select();
    return (response as List).map((json) => Scadenza.fromJson(json)).toList();
  }

  Future<void> segnaNotificata(int id) async {
    await _supabase
        .from('scadenze')
        .update({'notificata': true})
        .eq('id_scadenza', id);
  }
}
