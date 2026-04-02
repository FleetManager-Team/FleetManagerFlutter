import 'package:fleetmanager/models/enums/stato_prenotazione.dart';
import 'package:fleetmanager/provider/fleet_provider.dart';
import 'package:fleetmanager/ui/screens/prenotazioni/restituzione_veicolo_screen.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide Provider;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../models/prenotazione.dart';

class DettaglioPrenotazioneManager extends StatelessWidget {
  final Prenotazione prenotazione;
  const DettaglioPrenotazioneManager({super.key, required this.prenotazione});

  Future<Map<String, dynamic>> _getDatiCompleti() async {
    final client = Supabase.instance.client;

    final resRestituzione = await client
        .from('restituzioni')
        .select()
        .eq('id_prenotazione', prenotazione.idPrenotazione)
        .maybeSingle();

    final resVeicolo = await client
        .from('veicoli')
        .select('km')
        .eq('targa', prenotazione.targa)
        .single();

    return {
      'restituzione': resRestituzione,
      'km_veicolo': resVeicolo['km'],
    };
  }

  Future<void> _aggiornaStato(BuildContext context, StatoPrenotazione nuovoStato) async {
    final provider = Provider.of<FleetProvider>(context, listen: false);
    try {
      if (nuovoStato == StatoPrenotazione.attiva) {
        await provider.confermaPrenotazione(prenotazione.idPrenotazione);
      } else if (nuovoStato == StatoPrenotazione.annullata) {
        await provider.annullaPrenotazione(prenotazione.idPrenotazione);
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Operazione completata con successo"),
            backgroundColor: nuovoStato == StatoPrenotazione.attiva ? Colors.green : Colors.red,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Errore: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd/MM/yyyy HH:mm');
    final utente = Provider.of<FleetProvider>(context, listen: false).utenteLoggato;
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
          if (snapshot.hasError) {
            return Center(child: Text("Errore: ${snapshot.error}"));
          }

          final datiRestituzione = snapshot.data?['restituzione'];
          final kmVeicolo = snapshot.data?['km_veicolo'] ?? 'N/D';

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildHeader(context, df, kmVeicolo),
              const SizedBox(height: 24),

              if (prenotazione.statoPrenotazione == StatoPrenotazione.richiesta && isManager)
                _buildManagerActions(context)
              else if (prenotazione.statoPrenotazione != StatoPrenotazione.annullata) ...[
                if (datiRestituzione == null)
                  _buildNoDataWarning()
                else
                  _buildSezioniRestituzione(context, datiRestituzione, df),
                
                if (!isManager) _buildBottoneDriver(context, datiRestituzione),
              ]
              else
                Card(
                  color: Colors.red[50],
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.red[200]!),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Center(
                      child: Text("Prenotazione annullata.", 
                        style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                ),

              if (datiRestituzione != null && !isManager && prenotazione.statoPrenotazione != StatoPrenotazione.annullata)
                const Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: Center(
                    child: Text("Puoi modificare i dati in caso di errore",
                      style: TextStyle(color: Colors.grey, fontSize: 12, fontStyle: FontStyle.italic)),
                  ),
                ),
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
                Text(prenotazione.targa, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
                Icon(iconaStato, color: coloreStato, size: 32),
              ],
            ),
            const Divider(height: 24),
            _row("Inizio", df.format(prenotazione.dataInizio.toLocal())),
            _row("Fine", df.format(prenotazione.dataFine.toLocal())),
            _row("KM Attuali Veicolo", "$kmVeicolo"),
            _row("Stato", prenotazione.statoPrenotazione.name.toUpperCase(), colorVal: coloreStato),
          ],
        ),
      ),
    );
  }

  Widget _buildManagerActions(BuildContext context) {
    return Column(
      children: [
        const Text("AZIONI MANAGER", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _aggiornaStato(context, StatoPrenotazione.attiva),
                icon: const Icon(Icons.check),
                label: const Text("APPROVA"),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _aggiornaStato(context, StatoPrenotazione.annullata),
                icon: const Icon(Icons.close),
                label: const Text("RIFIUTA"),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSezioniRestituzione(BuildContext context, Map dati, DateFormat df) {
    return Column(
      children: [
        _buildSection("Dati Veicolo al Rientro", [
          _row("KM Finali", "${dati['km_finali']}"),
          _row("Livello Carburante", "${dati['livello_carburante']}/16"),
          _row("Data Restituzione", dati['data_restituzione'] != null 
              ? df.format(DateTime.parse(dati['data_restituzione']).toLocal()) 
              : "N/D"),
        ]),
        
        if (dati['rifornimento_effettuato'] == true)
          _buildSectionWithImage(
            context,
            "Spese Benzina",
            [
              _row("Costo", "${dati['importo_euro']} €"),
              _row("Litri", "${dati['litri_carburante']} L"),
            ],
            dati['url_scontrino'],
            color: Colors.blue[50]!,
          ),
          
        if (dati['danni_presenti'] == true)
          _buildSectionWithImage(
            context,
            "Danni Segnalati",
            [
              Text(dati['descrizione_danni'] ?? "Nessuna descrizione.", 
                style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 13)),
            ],
            dati['url_foto_danni'],
            color: Colors.red[50]!,
          ),
      ],
    );
  }

  Widget _buildSectionWithImage(BuildContext context, String title, List<Widget> children, String? url, {Color color = Colors.white}) {
    return Card(
      color: color,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
            const Divider(),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: children,
                  ),
                ),
                if (url != null) ...[
                  const SizedBox(width: 16),
                  GestureDetector(
                    onTap: () => _mostraImmagine(context, url),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        url,
                        height: 70,
                        width: 70,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return Container(
                            height: 70, width: 70, color: Colors.grey[200],
                            child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottoneDriver(BuildContext context, Map? dati) {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: ElevatedButton.icon(
        onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => RestituzioneVeicoloScreen(prenotazione: prenotazione))),
        style: ElevatedButton.styleFrom(
          backgroundColor: dati == null ? Colors.orange[800] : Colors.blueGrey[700],
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 54),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        icon: Icon(dati == null ? Icons.add_a_photo : Icons.edit_note),
        label: Text(dati == null ? "INSERISCI DATI RESTITUZIONE" : "MODIFICA DATI INSERITI"),
      ),
    );
  }

  Widget _buildNoDataWarning() {
    return Card(
      color: Colors.orange[50],
      elevation: 0,
      child: const Padding(
        padding: EdgeInsets.all(20.0),
        child: Column(
          children: [
            Icon(Icons.directions_car, color: Colors.orange, size: 48),
            SizedBox(height: 8),
            Text("Veicolo in Uso", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
            Text("In attesa che il driver carichi i dati di riconsegna.", textAlign: TextAlign.center, style: TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children, {Color color = Colors.white}) {
    return Card(
      color: color,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
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
            Text(val, style: TextStyle(fontWeight: FontWeight.bold, color: colorVal ?? Colors.black87)),
          ],
        ),
      );

  // FUNZIONE MOSTRA IMMAGINE OTTIMIZZATA PER RIEMPIRE IL DIALOG
  void _mostraImmagine(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(10), // Riduce i bordi esterni del dialogo
        backgroundColor: Colors.transparent, // Rende lo sfondo del dialogo invisibile
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Immagine che riempie lo spazio
            GestureDetector(
              onTap: () => Navigator.pop(context), // Chiude se si tocca l'immagine
              child: InteractiveViewer( // Permette lo zoom a pizzico
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    url,
                    fit: BoxFit.contain, // Mantiene le proporzioni riempiendo il possibile
                    width: double.infinity,
                    height: MediaQuery.of(context).size.height * 0.8,
                  ),
                ),
              ),
            ),
            // Bottone di chiusura in alto a destra
            Positioned(
              top: 10,
              right: 10,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}