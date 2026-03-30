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

  Future<Map<String, dynamic>> _getDatiCompleti() async {
    final client = Supabase.instance.client;

    final resRestituzione = await client
        .from('restituzioni')
        .select()
        .eq('id_prenotazione', prenotazione.idPrenotazione)
        .maybeSingle();

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
    final provider = Provider.of<FleetProvider>(context, listen: false);

    try {
      if (nuovoStato == StatoPrenotazione.confermata) {
        await provider.confermaPrenotazione(prenotazione.idPrenotazione);
      } else if (nuovoStato == StatoPrenotazione.annullata) {
        await provider.annullaPrenotazione(prenotazione.idPrenotazione);
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Operazione effettuata con successo"),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint("Errore: $e");
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

          final datiRest = snapshot.data?['restituzione'];
          final kmAttuali = snapshot.data?['km_veicolo'] ?? 'N/D';

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildHeader(df, kmAttuali),
              const SizedBox(height: 20),
              if (prenotazione.statoPrenotazione == StatoPrenotazione.richiesta)
                _buildManagerActions(context)
              else if (prenotazione.statoPrenotazione ==
                  StatoPrenotazione.confermata)
                _buildStatusInfo(
                    Icons.verified_user,
                    Colors.blue,
                    "Prenotazione Confermata",
                    "In attesa dell'orario di inizio.")
              else if (prenotazione.statoPrenotazione ==
                  StatoPrenotazione.attiva) ...[
                if (datiRest == null)
                  _buildNoDataWarning()
                else
                  _buildSezioniRestituzione(context, datiRest, df),
                if (!isManager) _buildBottoneDriver(context, datiRest),
              ],
              if (prenotazione.statoPrenotazione == StatoPrenotazione.annullata)
                _buildStatusInfo(Icons.cancel, Colors.red, "Annullata",
                    "Questa prenotazione è stata annullata."),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(DateFormat df, dynamic kmVeicolo) {
    Color colore;
    switch (prenotazione.statoPrenotazione) {
      case StatoPrenotazione.richiesta:
        colore = Colors.orange;
        break;
      case StatoPrenotazione.confermata:
        colore = Colors.blue;
        break;
      case StatoPrenotazione.attiva:
        colore = Colors.green;
        break;
      case StatoPrenotazione.annullata:
        colore = Colors.red;
        break;
      default:
        colore = Colors.grey;
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
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
                Icon(Icons.info_outline, color: colore, size: 32),
              ],
            ),
            const Divider(height: 30),
            _row("Inizio", df.format(prenotazione.dataInizio.toLocal())),
            _row("Fine", df.format(prenotazione.dataFine.toLocal())),
            _row("KM Attuali Veicolo", "$kmVeicolo"),
            _row("Stato", prenotazione.statoPrenotazione.name.toUpperCase(),
                colorVal: colore),
          ],
        ),
      ),
    );
  }

  Widget _buildManagerActions(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: () =>
                _aggiornaStato(context, StatoPrenotazione.confermata),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green, foregroundColor: Colors.white),
            child: const Text("APPROVA"),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: () =>
                _aggiornaStato(context, StatoPrenotazione.annullata),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text("RIFIUTA"),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusInfo(
      IconData icon, Color color, String title, String desc) {
    return Card(
      color: color.withOpacity(0.05),
      elevation: 0,
      shape: RoundedRectangleBorder(
          side: BorderSide(color: color.withOpacity(0.2)),
          borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(title,
            style: TextStyle(fontWeight: FontWeight.bold, color: color)),
        subtitle: Text(desc, style: const TextStyle(fontSize: 12)),
      ),
    );
  }

  Widget _buildNoDataWarning() {
    return Card(
      color: Colors.orange[50],
      elevation: 0,
      shape: RoundedRectangleBorder(
          side: const BorderSide(color: Colors.orange),
          borderRadius: BorderRadius.circular(12)),
      child: const Padding(
        padding: EdgeInsets.all(16),
        child: Text("Viaggio in corso. In attesa dei dati di rientro.",
            textAlign: TextAlign.center,
            style:
                TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildSezioniRestituzione(
      BuildContext context, Map dati, DateFormat df) {
    return Column(
      children: [
        _buildSection("Riepilogo Rientro", [
          _row("KM Finali", "${dati['km_finali']}"),
          _row("Livello Carburante", "${dati['livello_carburante']}/16"),
        ]),
        if (dati['url_scontrino'] != null)
          _imageBtn(context, "Vedi Scontrino", dati['url_scontrino']),
        if (dati['url_foto_danni'] != null)
          _imageBtn(context, "Vedi Foto Danni", dati['url_foto_danni']),
      ],
    );
  }

  Widget _buildBottoneDriver(BuildContext context, Map? dati) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: ElevatedButton(
        onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) =>
                    RestituzioneVeicoloScreen(prenotazione: prenotazione))),
        style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueGrey[700],
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50)),
        child: Text(
            dati == null ? "INSERISCI DATI RIENTRO" : "MODIFICA DATI RIENTRO"),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
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
                    color: colorVal ?? Colors.black87))
          ],
        ),
      );

  Widget _imageBtn(BuildContext context, String label, String url) =>
      OutlinedButton(
        onPressed: () => showDialog(
            context: context,
            builder: (_) => Dialog(child: Image.network(url))),
        child: Text(label),
      );
}
