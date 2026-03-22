import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fleetmanager/provider/fleet_provider.dart';
import 'package:fleetmanager/models/prenotazione.dart';
import 'package:fleetmanager/models/enums/stato_prenotazione.dart';
import 'package:fleetmanager/models/enums/ruolo_utente.dart';
import 'package:collection/collection.dart';

class BookingListScreen extends StatefulWidget {
  const BookingListScreen({super.key});

  @override
  State<BookingListScreen> createState() => _BookingListScreenState();
}

class _BookingListScreenState extends State<BookingListScreen> {
  StatoPrenotazione? filtroStato;
  String queryRicerca = "";
  bool ordineCrescente = false;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FleetProvider>();
    final isManager =
        provider.utenteLoggato?.ruoloUtente == RuoloUtente.manager;

    // Filtriamo la lista basandoci su targa e stato
    List<Prenotazione> lista = provider.prenotazioni.where((p) {
      final matchStato =
          filtroStato == null || p.statoPrenotazione == filtroStato;
      final matchRicerca =
          p.targa.toLowerCase().contains(queryRicerca.toLowerCase());
      return matchStato && matchRicerca;
    }).toList();

    // Ordinamento
    lista.sort((a, b) {
      int cmp = a.dataInizio.compareTo(b.dataInizio);
      return ordineCrescente ? cmp : -cmp;
    });

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Registro Prenotazioni",
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(
                ordineCrescente ? Icons.arrow_upward : Icons.arrow_downward),
            onPressed: () => setState(() => ordineCrescente = !ordineCrescente),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                provider.inizializzaDati(), // Refresh manuale dal DB
          ),
        ],
      ),
      body: Column(
        children: [
          _buildTopActions(),
          Expanded(
            child: provider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : lista.isEmpty
                    ? const Center(child: Text("Nessuna prenotazione trovata"))
                    : RefreshIndicator(
                        onRefresh: () => provider.inizializzaDati(),
                        child: ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: lista.length,
                          itemBuilder: (context, index) => _buildBookingCard(
                              lista[index], provider, isManager),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  void _showBookingDetails(
      Prenotazione p, FleetProvider provider, bool isManager) {
    final statusColor = _getBookingStatusColor(p.statoPrenotazione);

    // Cerchiamo il nome del driver per renderlo leggibile
    final driver =
        provider.utenti.firstWhereOrNull((u) => u.idUtente == p.idUtente);
    final nomeDriver = driver != null
        ? "${driver.nome} ${driver.cognome}"
        : "ID: #${p.idUtente}";

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Dettaglio Prenotazione"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _detailRow(Icons.directions_car, "Veicolo", p.targa),
            _detailRow(Icons.person, "Driver", nomeDriver),
            _detailRow(Icons.calendar_today, "Inizio",
                DateFormat('dd/MM HH:mm').format(p.dataInizio)),
            _detailRow(Icons.event_available, "Fine",
                DateFormat('dd/MM HH:mm').format(p.dataFine)),
            const Divider(),
            Text(p.statoPrenotazione.name.toUpperCase(),
                style:
                    TextStyle(color: statusColor, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          TextButton(
              onPressed:
                  provider.isLoading ? null : () => Navigator.pop(context),
              child: const Text("CHIUDI")),
          if (isManager &&
              p.statoPrenotazione == StatoPrenotazione.richiesta) ...[
            // Tasto APPROVA
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              onPressed: provider.isLoading
                  ? null
                  : () async {
                      try {
                        await provider.confermaPrenotazione(p.idPrenotazione);
                        if (context.mounted) Navigator.pop(context);
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text("Errore durante la conferma: $e"),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
              child: provider.isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Text("APPROVA",
                      style: TextStyle(color: Colors.white)),
            ),
            // Tasto RIFIUTA
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: provider.isLoading
                  ? null
                  : () async {
                      try {
                        await provider.annullaPrenotazione(p.idPrenotazione);
                        if (context.mounted) Navigator.pop(context);
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text("Errore durante l'annullamento: $e"),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
              child:
                  const Text("RIFIUTA", style: TextStyle(color: Colors.white)),
            ),
          ],
        ],
      ),
    );
  }

  // Supporto UI
  Widget _buildTopActions() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              onChanged: (val) => setState(() => queryRicerca = val),
              decoration: InputDecoration(
                hintText: "Cerca targa...",
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none),
              ),
            ),
          ),
          const SizedBox(width: 10),
          DropdownButton<StatoPrenotazione>(
            value: filtroStato,
            underline: const SizedBox(),
            icon: const Icon(Icons.filter_alt),
            onChanged: (val) => setState(() => filtroStato = val),
            items: [
              const DropdownMenuItem(value: null, child: Text("TUTTI")),
              ...StatoPrenotazione.values.map((s) => DropdownMenuItem(
                  value: s, child: Text(s.name.toUpperCase()))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBookingCard(
      Prenotazione p, FleetProvider provider, bool isManager) {
    final statusColor = _getBookingStatusColor(p.statoPrenotazione);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        onTap: () => _showBookingDetails(p, provider, isManager),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8)),
          child: Icon(Icons.event_note, color: statusColor),
        ),
        title: Text("Veicolo: ${p.targa}",
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle:
            Text("Inizio: ${DateFormat('dd/MM HH:mm').format(p.dataInizio)}"),
        trailing: _buildStatusTag(p.statoPrenotazione, statusColor),
      ),
    );
  }

  Widget _buildStatusTag(StatoPrenotazione stato, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration:
          BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
      child: Text(
        stato.name.toUpperCase(),
        style: const TextStyle(
            fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.blueGrey[400]),
          const SizedBox(width: 8),
          Text("$label: ",
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  Color _getBookingStatusColor(StatoPrenotazione stato) {
    switch (stato) {
      case StatoPrenotazione.richiesta:
        return Colors.orange[700]!;
      case StatoPrenotazione.attiva:
        return Colors.green[600]!;
      case StatoPrenotazione.completata:
        return Colors.grey[600]!;
      case StatoPrenotazione.annullata:
        return Colors.red[700]!;
      case StatoPrenotazione.confermata:
        return Colors.blue[600]!;
    }
  }
}
