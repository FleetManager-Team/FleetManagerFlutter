import 'package:fleetmanager/models/enums/stato_prenotazione.dart';
import 'package:fleetmanager/provider/fleet_provider.dart';
import 'package:fleetmanager/ui/screens/prenotazioni/restituzione_veicolo_screen.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../models/prenotazione.dart';

class DettaglioPrenotazioneManager extends StatelessWidget {
  final Prenotazione prenotazione;
  const DettaglioPrenotazioneManager({super.key, required this.prenotazione});

  // Funzione per recuperare sia la restituzione che i KM attuali del veicolo
  Future<Map<String, dynamic>> _getDatiCompleti() async {
    final client = Supabase.instance.client;

    // 1. Recupero dati restituzione (se esistono)
    final resRestituzione = await client
        .from('restituzioni')
        .select()
        .eq('id_prenotazione', prenotazione.idPrenotazione)
        .maybeSingle();

    // 2. Recupero KM attuali dal veicolo (tramite la targa)
    final resVeicolo = await client
        .from('veicoli')
        .select('km_attuali')
        .eq('targa', prenotazione.targa)
        .single();

    return {
      'restituzione': resRestituzione,
      'km_veicolo': resVeicolo['km_attuali'],
    };
  }

  Future<void> _aggiornaStato(
      BuildContext context, StatoPrenotazione nuovoStato) async {
    // Recuperiamo il provider senza metterlo in ascolto (listen: false)
    final provider = Provider.of<FleetProvider>(context, listen: false);

    try {
      if (nuovoStato == StatoPrenotazione.attiva) {
        // Usa il metodo che mi hai appena mostrato
        // Nota: se il tuo ID è int, passa prenotazione.idPrenotazione così com'è
        await provider.confermaPrenotazione(prenotazione.idPrenotazione);
      } else if (nuovoStato == StatoPrenotazione.annullata) {
        // Presumo tu abbia un metodo simile per l'annullamento
        await provider.annullaPrenotazione(prenotazione.idPrenotazione);
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Operazione completata con successo"),
            backgroundColor: nuovoStato == StatoPrenotazione.attiva
                ? Colors.green
                : Colors.red,
          ),
        );
        // Fondamentale: torniamo alla lista.
        // La lista si sarà già aggiornata grazie a inizializzaDati() dentro il provider.
        Navigator.pop(context);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Errore: ${e.toString()}")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd/MM/yyyy HH:mm');
    final utente =
        Provider.of<FleetProvider>(context, listen: false).utenteLoggato;
    final isManager = utente?.idUtente != prenotazione.idUtente;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text("Dettaglio ${prenotazione.targa}"),
        backgroundColor: Colors.blueGrey[800],
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _getDatiCompleti(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final datiRestituzione = snapshot.data?['restituzione'];
          final kmAttualiVeicolo = snapshot.data?['km_veicolo'] ?? 'N/D';

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildHeader(context, df, kmAttualiVeicolo),
              const SizedBox(height: 24),

              // --- LOGICA STATI ---
              if (prenotazione.statoPrenotazione == StatoPrenotazione.richiesta)
                _buildManagerActions(context)
              else if (prenotazione.statoPrenotazione ==
                  StatoPrenotazione.attiva) ...[
                if (datiRestituzione == null)
                  _buildNoDataWarning()
                else
                  _buildSezioniRestituzione(context, datiRestituzione, df),
                if (!isManager) _buildBottoneDriver(context, datiRestituzione),
              ],

              if (prenotazione.statoPrenotazione == StatoPrenotazione.annullata)
                const Center(
                    child: Text("Prenotazione annullata.",
                        style: TextStyle(color: Colors.red))),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context, DateFormat df, dynamic kmVeicolo) {
    IconData iconaStato;
    Color coloreStato;

    switch (prenotazione.statoPrenotazione) {
      case StatoPrenotazione.richiesta:
        iconaStato = Icons.pending_actions;
        coloreStato = Colors.orange;
        break;
      case StatoPrenotazione.attiva:
        iconaStato = Icons.check_circle_outline;
        coloreStato = Colors.green;
        break;
      case StatoPrenotazione.annullata:
        iconaStato = Icons.cancel_outlined;
        coloreStato = Colors.red;
        break;
      default:
        iconaStato = Icons.help_outline;
        coloreStato = Colors.grey;
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(prenotazione.targa,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 22)),
                Icon(iconaStato, color: coloreStato, size: 32),
              ],
            ),
            const Divider(height: 24),
            _row("Inizio", df.format(prenotazione.dataInizio.toLocal())),
            _row("Fine", df.format(prenotazione.dataFine.toLocal())),
            // KM Recuperati dalla tabella veicoli
            _row("KM Attuali Veicolo", "$kmVeicolo"),
            _row("Stato", prenotazione.statoPrenotazione.name.toUpperCase(),
                colorVal: coloreStato),
          ],
        ),
      ),
    );
  }

  // ... (Resto dei widget: _buildManagerActions, _buildSezioniRestituzione, _buildBottoneDriver, _buildNoDataWarning, _buildSection, _row, _imageBtn, _mostraImmagine rimangono uguali a prima)

  Widget _buildManagerActions(BuildContext context) {
    return Column(
      children: [
        const Text("AZIONI MANAGER",
            style:
                TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () =>
                    _aggiornaStato(context, StatoPrenotazione.attiva),
                icon: const Icon(Icons.check),
                label: const Text("APPROVA"),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () =>
                    _aggiornaStato(context, StatoPrenotazione.annullata),
                icon: const Icon(Icons.close),
                label: const Text("RIFIUTA"),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red, foregroundColor: Colors.white),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSezioniRestituzione(
      BuildContext context, Map dati, DateFormat df) {
    return Column(
      children: [
        _buildSection("Dati Veicolo al Rientro", [
          _row("KM Finali", "${dati['km_finali']}"),
          _row("Livello Carburante", "${dati['livello_carburante']}/16"),
          _row(
              "Data Restituzione",
              dati['data_restituzione'] != null
                  ? df.format(
                      DateTime.parse(dati['data_restituzione']).toLocal())
                  : "N/D"),
        ]),
        if (dati['rifornimento_effettuato'] == true)
          _buildSection(
              "Spese Benzina",
              [
                _row("Costo", "${dati['importo_euro']} €"),
                _row("Litri", "${dati['litri_carburante']} L"),
                if (dati['url_scontrino'] != null)
                  _imageBtn(context, "Vedi Scontrino", dati['url_scontrino']),
              ],
              color: Colors.blue[50]!),
        if (dati['danni_presenti'] == true)
          _buildSection(
              "Danni Segnalati",
              [
                Text(dati['descrizione_danni'] ?? "Nessuna descrizione."),
                if (dati['url_foto_danni'] != null)
                  _imageBtn(context, "Vedi Foto Danni", dati['url_foto_danni']),
              ],
              color: Colors.red[50]!),
      ],
    );
  }

  Widget _buildBottoneDriver(BuildContext context, Map? dati) {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: ElevatedButton.icon(
        onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) =>
                    RestituzioneVeicoloScreen(prenotazione: prenotazione))),
        style: ElevatedButton.styleFrom(
          backgroundColor:
              dati == null ? Colors.orange[800] : Colors.blueGrey[700],
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 54),
        ),
        icon: Icon(dati == null ? Icons.add_a_photo : Icons.edit_note),
        label: Text(dati == null
            ? "INSERISCI DATI RESTITUZIONE"
            : "MODIFICA DATI INSERITI"),
      ),
    );
  }

  Widget _buildNoDataWarning() {
    return Card(
      color: Colors.orange[50],
      child: const Padding(
        padding: EdgeInsets.all(20.0),
        child: Column(
          children: [
            Icon(Icons.directions_car, color: Colors.orange, size: 48),
            Text("Veicolo in Uso",
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.orange)),
            Text("In attesa che il driver carichi i dati di riconsegna.",
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children,
      {Color color = Colors.white}) {
    return Card(
      color: color,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: Colors.blueGrey)),
          const Divider(),
          ...children
        ]),
      ),
    );
  }

  Widget _row(String label, String val, {Color? colorVal}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(color: Colors.grey[600])),
            Text(val,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: colorVal ?? Colors.black87)),
          ],
        ),
      );

  Widget _imageBtn(BuildContext context, String label, String url) => Padding(
        padding: const EdgeInsets.only(top: 8.0),
        child: OutlinedButton.icon(
          onPressed: () => _mostraImmagine(context, url),
          icon: const Icon(Icons.image),
          label: Text(label),
          style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 40)),
        ),
      );

  void _mostraImmagine(BuildContext context, String url) {
    showDialog(
        context: context,
        builder: (_) => Dialog(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
              AppBar(
                  title: const Text("Anteprima"),
                  automaticallyImplyLeading: false,
                  actions: [
                    IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context))
                  ]),
              Image.network(url),
            ])));
  }
}
