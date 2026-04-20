import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/scadenza.dart';
import '../models/enums/tipo_scadenza.dart';

class ScadenzaService {
  final SupabaseClient _supabase;

  ScadenzaService({SupabaseClient? supabaseClient})
      : _supabase = supabaseClient ?? Supabase.instance.client;

  Future<List<Scadenza>> fetchTutteLeScadenze() async {
    final response = await _supabase.from('scadenze').select().order('data', ascending: true);
    return (response as List).map((json) => Scadenza.fromJson(json)).toList();
  }

  Future<void> segnaNotificata(int id) async {
    await _supabase
        .from('scadenze')
        .update({'notificata': true})
        .eq('id_scadenza', id);
  }

  // Crea una nuova scadenza
  Future<void> creaScadenza(Scadenza scadenza) async {
    final data = scadenza.toJson();
    data.remove('id_scadenza'); // Il DB genererà l'ID
    await _supabase.from('scadenze').insert(data);
  }

  // Modifica una scadenza esistente
  Future<void> modificaScadenza(int idScadenza, Scadenza scadenza) async {
    final data = scadenza.toJson();
    data.remove('id_scadenza');
    await _supabase
        .from('scadenze')
        .update(data)
        .eq('id_scadenza', idScadenza);
  }

  // Elimina una scadenza
  Future<void> eliminaScadenza(int idScadenza) async {
    await _supabase
        .from('scadenze')
        .delete()
        .eq('id_scadenza', idScadenza);
  }

  // Chiude una scadenza (registra l'intervento completato)
  Future<void> chiudiScadenza(int idScadenza, double costo, String dettagli) async {
    await _supabase
        .from('scadenze')
        .update({
          'chiusa': true,
          'data_chiusura': DateTime.now().toIso8601String(),
          'costo_chiusura': costo,
          'dettagli_chiusura': dettagli,
        })
        .eq('id_scadenza', idScadenza);
  }

  @Deprecated('Usa creaScadenza() invece')
  Future<void> aggiungiScadenza(Scadenza scadenza) async {
    await creaScadenza(scadenza);
  }

  // Calcola prossima revisione basata su normative (ogni 2 anni)
  DateTime calcolaProssimaRevisione(DateTime ultimaRevisione) {
    return ultimaRevisione.add(const Duration(days: 730)); // 2 anni
  }

  // Aggiungi scadenza tagliando basata su km o mesi
  Future<void> aggiungiScadenzaTagliando(String targa, int? kmDopo, int? mesiDopo, DateTime dataChiusura) async {
    DateTime dataScadenza;
    if (kmDopo != null) {
      // Per ora, assumiamo che kmDopo sia aggiunto ai km attuali, ma per semplicità, usiamo data + mesi
      // In realtà, servirebbe km attuali del veicolo
      dataScadenza = dataChiusura.add(Duration(days: (mesiDopo ?? 6) * 30));
    } else {
      dataScadenza = dataChiusura.add(Duration(days: (mesiDopo ?? 6) * 30));
    }

    final scadenza = Scadenza(
      idScadenza: DateTime.now().millisecondsSinceEpoch, // temp, DB auto
      tipoScadenza: TipoScadenza.tagliando,
      data: dataScadenza,
      notificata: false,
      targa: targa,
      kmScadenza: kmDopo,
      mesiScadenza: mesiDopo,
    );

    await creaScadenza(scadenza);
  }
}
