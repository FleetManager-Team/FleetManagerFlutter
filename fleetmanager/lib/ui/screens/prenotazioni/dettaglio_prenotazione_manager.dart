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

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd/MM/yyyy HH:mm');

    // Identificazione Manager: se l'utente loggato NON è colui che ha effettuato la prenotazione
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
      body: FutureBuilder(
        future: Supabase.instance.client
            .from('restituzioni')
            .select()
            .eq('id_prenotazione', prenotazione.idPrenotazione)
            .maybeSingle(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
                child: Text("Errore nel caricamento: ${snapshot.error}"));
          }

          final dati = snapshot.data;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildHeader(context, dati, df),
              const SizedBox(height: 16),
              if (dati == null)
                _buildNoDataWarning()
              else ...[
                _buildSection("Dati Veicolo", [
                  _row("KM Finali", "${dati['km_finali']}"),
                  _row(
                      "Livello Carburante", "${dati['livello_carburante']}/16"),
                  _row(
                      "Data Restituzione",
                      dati['data_restituzione'] != null
                          ? df.format(DateTime.parse(dati['data_restituzione'])
                              .toLocal())
                          : "N/D"),
                ]),
                if (dati['rifornimento_effettuato'] == true)
                  _buildSection(
                      "Spese Benzina",
                      [
                        _row("Costo", "${dati['importo_euro']} €"),
                        _row("Litri", "${dati['litri_carburante']} L"),
                        if (dati['url_scontrino'] != null)
                          _imageBtn(
                              context, "Vedi Scontrino", dati['url_scontrino']),
                      ],
                      color: Colors.blue[50]!),
                if (dati['danni_presenti'] == true)
                  _buildSection(
                      "Danni Segnalati",
                      [
                        Text(
                            dati['descrizione_danni'] ??
                                "Nessuna descrizione fornita.",
                            style:
                                const TextStyle(fontStyle: FontStyle.italic)),
                        const SizedBox(height: 10),
                        if (dati['url_foto_danni'] != null)
                          _imageBtn(context, "Vedi Foto Danni",
                              dati['url_foto_danni']),
                      ],
                      color: Colors.red[50]!),
              ],

              // Tasto mostrato solo se NON è annullata e l'utente è il proprietario (NON manager)
              if (prenotazione.statoPrenotazione !=
                      StatoPrenotazione.annullata &&
                  !isManager)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => RestituzioneVeicoloScreen(
                              prenotazione: prenotazione),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: dati == null
                          ? Colors.orange[800]
                          : Colors.blueGrey[700],
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 54),
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: Icon(
                        dati == null ? Icons.add_a_photo : Icons.edit_note),
                    label: Text(
                      dati == null
                          ? "INSERISCI DATI RESTITUZIONE"
                          : "MODIFICA DATI INSERITI",
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                ),

              if (prenotazione.statoPrenotazione == StatoPrenotazione.annullata)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.only(top: 20),
                    child: Text(
                      "Prenotazione annullata: inserimento dati non consentito.",
                      style: TextStyle(
                          color: Colors.red,
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),

              if (dati != null && !isManager)
                const Center(
                  child: Text(
                    "Puoi modificare i dati in caso di errore",
                    style: TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                        fontStyle: FontStyle.italic),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context, Map? dati, DateFormat df) {
    return Card(
      elevation: 2,
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
                Icon(
                  dati == null ? Icons.pending_actions : Icons.verified_user,
                  color: dati == null ? Colors.orange : Colors.green,
                  size: 30,
                ),
              ],
            ),
            const Divider(),
            _row("Inizio", df.format(prenotazione.dataInizio.toLocal())),
            _row("Fine", df.format(prenotazione.dataFine.toLocal())),
            _row("Stato", prenotazione.statoPrenotazione.name.toUpperCase()),
          ],
        ),
      ),
    );
  }

  Widget _buildNoDataWarning() {
    return Card(
      color: Colors.orange[50],
      child: const Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            Icon(Icons.info_outline, color: Colors.orange, size: 40),
            SizedBox(height: 8),
            Text("In attesa di restituzione",
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.orange)),
            Text("Il driver non ha ancora caricato i dati finali (KM/Benzina).",
                textAlign: TextAlign.center, style: TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children,
      {Color color = Colors.white}) {
    return Card(
        color: color,
        elevation: 1,
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.blueGrey)),
            const Divider(),
            ...children
          ]),
        ));
  }

  Widget _row(String label, String val) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child:
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label, style: TextStyle(color: Colors.grey[600])),
          Text(val, style: const TextStyle(fontWeight: FontWeight.bold))
        ]),
      );

  Widget _imageBtn(BuildContext context, String label, String url) => Padding(
        padding: const EdgeInsets.only(top: 8.0),
        child: ElevatedButton.icon(
          onPressed: () => _mostraImmagine(context, url),
          icon: const Icon(Icons.image_search),
          label: Text(label),
          style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 36)),
        ),
      );

  void _mostraImmagine(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title:
                  const Text("Anteprima Foto", style: TextStyle(fontSize: 14)),
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context))
              ],
            ),
            Image.network(
              url,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return const Padding(
                  padding: EdgeInsets.all(20.0),
                  child: CircularProgressIndicator(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
