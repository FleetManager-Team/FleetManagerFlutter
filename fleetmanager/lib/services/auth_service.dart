import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/utente.dart';

class AuthService {
  final SupabaseClient _supabase;

  AuthService({SupabaseClient? supabaseClient})
      : _supabase = supabaseClient ?? Supabase.instance.client;

  Future<Utente?> login(String email, String password) async {
    try {
      // 1. Autenticazione ufficiale di Supabase (gestisce lui la password)
      final AuthResponse authRes = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      // Se l'auth ha successo, procediamo a prendere i dati dal DB
      if (authRes.user != null) {
        final response = await _supabase
            .from('utenti')
            .select()
            .eq('email', email) // Usiamo l'email come ponte
            .maybeSingle();

        if (response == null) return null;
        return Utente.fromJson(response);
      }
      return null;
    } catch (e) {
      // Se la password è sbagliata o l'utente non esiste in Auth, finirà qui
      print("Errore login Supabase: $e");
      return null;
    }
  }

  // Recupera tutti gli utenti (sostituisce getTuttiUtenti)
  Future<List<Utente>> getTuttiUtenti() async {
    try {
      final response = await _supabase.from('utenti').select();
      return (response as List).map((json) => Utente.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Errore nel recupero utenti: $e');
    }
  }

  // Recupera un singolo utente per email
  Future<Utente?> getUtenteByEmail(String email) async {
    try {
      final response = await _supabase
          .from('utenti')
          .select()
          .eq('email', email)
          .maybeSingle();

      if (response == null) return null;
      return Utente.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  // Aggiorna profilo esistente
  Future<bool> updateProfilo(Utente u) async {
    try {
      await _supabase
          .from('utenti')
          .update(u.toJson())
          .eq('id_utente', u.idUtente);
      return true;
    } catch (e) {
      print("Errore update: $e");
      return false;
    }
  }

  Future<bool> createUtente(Utente nuovoUtente) async {
    try {
      final data = nuovoUtente.toJson();

      debugPrint("Tentativo di inserimento dati: $data");

      await _supabase.from('utenti').insert(data);

      return true;
    } on PostgrestException catch (e) {
      print("Errore Database (Codice ${e.code}): ${e.message}");
      print("Dettagli: ${e.details}");
      return false;
    } catch (e) {
      print("Errore generico creazione: $e");
      return false;
    }
  }

  // Elimina utente
  Future<bool> eliminaUtente(int idUtente) async {
    try {
      await _supabase.from('utenti').delete().eq('id_utente', idUtente);
      return true;
    } catch (e) {
      print("Errore eliminazione: $e");
      return false;
    }
  }
}
