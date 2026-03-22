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
  void initState() {
    super.initState();
    // Al caricamento, assicuriamoci che gli stati siano aggiornati (es. da confermata ad attiva)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FleetProvider>().inizializzaDati();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FleetProvider>();
    final isManager =
        provider.utenteLoggato?.ruoloUtente == RuoloUtente.manager;

    // Filtro e ricerca
    List<Prenotazione> lista = provider.prenotazioni.where((p) {
      final matchStato =
          filtroStato == null || p.statoPrenotazione == filtroStato;
      final matchRicerca =
          p.targa.toLowerCase().contains(queryRicerca.toLowerCase());

      // Se non è manager, vede solo le sue (Logica opzionale, dipende dal tuo business)
      bool matchUtente =
          isManager || p.idUtente == provider.utenteLoggato?.idUtente;

      return matchStato && matchRicerca && matchUtente;
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
        backgroundColor: Colors.blue[900],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(
                ordineCrescente ? Icons.arrow_upward : Icons.arrow_downward),
            onPressed: () => setState(() => ordineCrescente = !ordineCrescente),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => provider.inizializzaDati(),
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
                    ? _buildEmptyState()
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
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none),
              ),
            ),
          ),
          const SizedBox(width: 10),
          DropdownButton<StatoPrenotazione>(
            value: filtroStato,
            hint: const Text("Stato"),
            underline: const SizedBox(),
            icon: const Icon(Icons.filter_list_alt),
            onChanged: (val) => setState(() => filtroStato = val),
            items: [
              const DropdownMenuItem(value: null, child: Text("Tutti")),
              ...StatoPrenotazione.values.map((s) => DropdownMenuItem(
                  value: s,
                  child: Text(s.name.toUpperCase(),
                      style: const TextStyle(fontSize: 12)))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBookingCard(
      Prenotazione p, FleetProvider provider, bool isManager) {
    final statusColor = _getBookingStatusColor(p.statoPrenotazione);
    final driver =
        provider.utenti.firstWhereOrNull((u) => u.idUtente == p.idUtente);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        onTap: () => _showBookingDetails(p, provider, isManager, driver),
        leading: CircleAvatar(
          backgroundColor: statusColor.withOpacity(0.1),
          child: Icon(Icons.calendar_month, color: statusColor),
        ),
        title: Text("Targa: ${p.targa}",
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Inizio: ${DateFormat('dd/MM HH:mm').format(p.dataInizio)}"),
            if (isManager && driver != null)
              Text("Driver: ${driver.nome} ${driver.cognome}",
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        trailing: _buildStatusTag(p.statoPrenotazione, statusColor),
      ),
    );
  }

  void _showBookingDetails(
      Prenotazione p, FleetProvider provider, bool isManager, dynamic driver) {
    final statusColor = _getBookingStatusColor(p.statoPrenotazione);
    final nomeDriver = driver != null
        ? "${driver.nome} ${driver.cognome}"
        : "ID: #${p.idUtente}";

    showDialog(
      context: context,
      barrierDismissible: !provider.isLoading,
      builder: (context) => StatefulBuilder(
        // Per gestire il caricamento dentro il dialog
        builder: (context, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: const Text("Dettaglio Prenotazione"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _detailRow(Icons.directions_car, "Veicolo", p.targa),
              _detailRow(Icons.person, "Driver", nomeDriver),
              _detailRow(Icons.access_time, "Dalle",
                  DateFormat('dd/MM/yy HH:mm').format(p.dataInizio)),
              _detailRow(Icons.access_time_filled, "Alle",
                  DateFormat('dd/MM/yy HH:mm').format(p.dataFine)),
              const Divider(height: 30),
              Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10)),
                child: Text(p.statoPrenotazione.name.toUpperCase(),
                    style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2)),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed:
                    provider.isLoading ? null : () => Navigator.pop(context),
                child: const Text("CHIUDI")),
            if (isManager &&
                p.statoPrenotazione == StatoPrenotazione.richiesta) ...[
              ElevatedButton(
                style:
                    ElevatedButton.styleFrom(backgroundColor: Colors.red[400]),
                onPressed: provider.isLoading
                    ? null
                    : () async {
                        await provider.annullaPrenotazione(p.idPrenotazione);
                        if (context.mounted) Navigator.pop(context);
                      },
                child: const Text("RIFIUTA",
                    style: TextStyle(color: Colors.white)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[600]),
                onPressed: provider.isLoading
                    ? null
                    : () async {
                        await provider.confermaPrenotazione(p.idPrenotazione);
                        if (context.mounted) Navigator.pop(context);
                      },
                child: const Text("APPROVA",
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Supporto UI
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_busy, size: 60, color: Colors.grey[400]),
          const SizedBox(height: 10),
          Text("Nessuna prenotazione trovata",
              style: TextStyle(color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.blue[900]),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(fontSize: 11, color: Colors.grey)),
              Text(value,
                  style: const TextStyle(
                      fontWeight: FontWeight.w500, fontSize: 14)),
            ],
          ),
        ],
      ),
    );
  }

  Color _getBookingStatusColor(StatoPrenotazione stato) {
    switch (stato) {
      case StatoPrenotazione.richiesta:
        return Colors.orange[800]!;
      case StatoPrenotazione.attiva:
        return Colors.green[700]!;
      case StatoPrenotazione.completata:
        return Colors.blueGrey[600]!;
      case StatoPrenotazione.annullata:
        return Colors.red[700]!;
      case StatoPrenotazione.confermata:
        return Colors.blue[700]!;
    }
  }
}
