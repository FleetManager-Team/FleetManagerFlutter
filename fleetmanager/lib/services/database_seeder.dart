import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';

class DatabaseSeeder {
  static final _supabase = Supabase.instance.client;

  static Future<void> eseguiSeedCompleto() async {
    try {
      debugPrint("🚀 SEED: Controllo stato database...");

      // 1. CONTROLLO ESISTENZA (Logica 1)
      // Verifichiamo se esiste almeno un veicolo per capire se il seed è già stato fatto
      final checkVeicoli = await _supabase.from('veicoli').select('targa').limit(1);

      if (checkVeicoli.isNotEmpty) {
        debugPrint("⏩ SEED: Dati già presenti. Operazione annullata per evitare duplicati.");
        return; 
      }

      debugPrint("🛠️ SEED: Database vuoto. Inizio popolamento dati di prova...");

      // --- 2. INSERIMENTO VEICOLI ---
      // Usiamo i nomi colonne esatti del tuo schema (targa, marca, modello, km, stato, tipo, anno_immatricolazione)
      final veicoli = [
        {
          'targa': 'AA123BB',
          'marca': 'Fiat',
          'modello': 'Panda',
          'anno_immatricolazione': 2022,
          'km': 15000,
          'stato': 'disponibile',
          'tipo': 'auto'
        },
        {
          'targa': 'CC456DD',
          'marca': 'Volkswagen',
          'modello': 'Golf',
          'anno_immatricolazione': 2021,
          'km': 42000,
          'stato': 'disponibile',
          'tipo': 'auto'
        },
        {
          'targa': 'EE789FF',
          'marca': 'Ford',
          'modello': 'Transit',
          'anno_immatricolazione': 2023,
          'km': 5000,
          'stato': 'inManutenzione',
          'tipo': 'furgone'
        },
      ];

      await _supabase.from('veicoli').insert(veicoli);
      debugPrint("✅ SEED: Veicoli inseriti.");

      // --- 3. INSERIMENTO UTENTI (AUTH + TABELLA) ---
      // Creiamo un Manager e un Driver per i tuoi test
      await _creaUtenteSeNonEsiste(
        email: 'manager@test.it',
        password: 'password123',
        nome: 'Mario',
        cognome: 'Rossi',
        ruolo: 'manager',
        patente: 'PAT12345',
      );

      await _creaUtenteSeNonEsiste(
        email: 'driver@test.it',
        password: 'password123',
        nome: 'Luca',
        cognome: 'Bianchi',
        ruolo: 'driver',
        patente: 'PAT67890',
      );
      debugPrint("✅ SEED: Utenti (Auth e Tabella) pronti.");

      // --- 4. INSERIMENTO MANUTENZIONI (Esempio per il veicolo in manutenzione) ---
      await _supabase.from('manutenzioni').insert({
        'targa': 'EE789FF',
        'data': DateTime.now().toIso8601String(),
        'tipo': 'ordinaria',
        'descrizione': 'Revisione periodica e controllo freni',
      });

      // --- 5. INSERIMENTO SCADENZE ---
      await _supabase.from('scadenze').insert([
        {
          'targa': 'AA123BB',
          'tipo': 'assicurazione',
          'data': DateTime.now().add(const Duration(days: 45)).toIso8601String(),
          'notificata': false
        },
        {
          'targa': 'CC456DD',
          'tipo': 'bollo',
          'data': DateTime.now().add(const Duration(days: 10)).toIso8601String(),
          'notificata': true
        }
      ]);

      debugPrint("🎉 SEED: Operazione completata con successo!");

    } catch (e) {
      debugPrint("❌ SEED ERROR: $e");
    }
  }

  // Helper interno per gestire la doppia creazione Auth + Tabella Public
  static Future<void> _creaUtenteSeNonEsiste({
    required String email,
    required String password,
    required String nome,
    required String cognome,
    required String ruolo,
    required String patente,
  }) async {
    try {
      // 1. Registra in Supabase Auth
      final authRes = await _supabase.auth.signUp(email: email, password: password);
      
      if (authRes.user != null) {
        // 2. Inserisce nella tua tabella 'utenti'
        await _supabase.from('utenti').insert({
          'nome': nome,
          'cognome': cognome,
          'email': email,
          'ruolo': ruolo,
          'patente': patente,
        });
      }
    } catch (e) {
      // Se l'utente esiste già in Auth, Supabase lancia un'eccezione. La ignoriamo.
      debugPrint("ℹ️ SEED: Utente $email già presente, salto creazione.");
    }
  }
}