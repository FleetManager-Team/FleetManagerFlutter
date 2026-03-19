import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fleetmanager/provider/fleet_provider.dart';
import 'package:fleetmanager/models/prenotazione.dart';
import 'package:fleetmanager/models/enums/stato_prenotazione.dart';
import 'package:fleetmanager/models/enums/ruolo_utente.dart';
import 'package:fleetmanager/ui/widgets/details_pop_up.dart'; // Importa il widget condiviso

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

    List<Prenotazione> lista = provider.prenotazioni.where((p) {
      final matchStato =
          filtroStato == null || p.statoPrenotazione == filtroStato;
      final matchRicerca =
          p.targa.toLowerCase().contains(queryRicerca.toLowerCase());
      return matchStato && matchRicerca;
    }).toList();

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
        ],
      ),
      body: Column(
        children: [
          _buildTopActions(),
          Expanded(
            child: lista.isEmpty
                ? const Center(child: Text("Nessuna prenotazione trovata"))
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: lista.length,
                    itemBuilder: (context, index) =>
                        _buildBookingCard(lista[index], provider, isManager),
                  ),
          ),
        ],
      ),
    );
  }

  // --- LOGICA DEL POPUP AGGIORNATA ---
  void _showBookingDetails(
      Prenotazione p, FleetProvider provider, bool isManager) {
    final statusColor = _getBookingStatusColor(p.statoPrenotazione);

    showDialog(
      context: context,
      builder: (context) => DetailsPopUp(
        title: "Dettaglio Prenotazione",
        titleIcon: Icons.assignment,
        details: [
          _detailRow(Icons.directions_car, "Veicolo", p.targa),
          _detailRow(Icons.person, "Driver ID", "#${p.idUtente}"),
          _detailRow(Icons.calendar_today, "Inizio",
              DateFormat('dd/MM/yyyy HH:mm').format(p.dataInizio)),
          _detailRow(Icons.event_available, "Fine",
              DateFormat('dd/MM/yyyy HH:mm').format(p.dataFine)),
          _detailRow(Icons.info_outline, "Tipo",
              p.tipoPrenotazione.name.toUpperCase()),
        ],
        // Qui sfruttiamo il nuovo "Riquadro Automatico" del DetailsPopUp
        extraSectionTitle: "Stato Attuale",
        extraContent: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lens, size: 12, color: statusColor),
            const SizedBox(width: 8),
            Text(
              p.statoPrenotazione.name.toUpperCase(),
              style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("CHIUDI")),
          if (isManager &&
              p.statoPrenotazione == StatoPrenotazione.richiesta) ...[
            ElevatedButton(
              style:
                  ElevatedButton.styleFrom(backgroundColor: Colors.green[600]),
              onPressed: () {
                provider.confermaPrenotazione(p.idPrenotazione);
                Navigator.pop(context);
              },
              child:
                  const Text("APPROVA", style: TextStyle(color: Colors.white)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red[600]),
              onPressed: () {
                provider.annullaPrenotazione(p.idPrenotazione);
                Navigator.pop(context);
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
