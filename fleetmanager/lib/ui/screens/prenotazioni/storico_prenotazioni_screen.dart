import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fleetmanager/provider/fleet_provider.dart';
import 'package:fleetmanager/models/prenotazione.dart';
import 'package:fleetmanager/models/enums/stato_prenotazione.dart';
import 'package:fleetmanager/models/enums/ruolo_utente.dart';

class BookingHistoryScreen extends StatefulWidget {
  const BookingHistoryScreen({super.key});

  @override
  State<BookingHistoryScreen> createState() => _BookingHistoryScreenState();
}

class _BookingHistoryScreenState extends State<BookingHistoryScreen> {
  StatoPrenotazione? filtroStato; // null = Tutte (Completate + Annullate)

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FleetProvider>();
    final utente = provider.utenteLoggato;
    final isManager = utente?.ruoloUtente == RuoloUtente.manager;

    // 1. Prendiamo tutte le prenotazioni dal provider
    List<Prenotazione> storico = provider.prenotazioni.where((p) {
      // Filtriamo solo quelle chiuse (completate o annullate)
      bool isChiusa = p.statoPrenotazione == StatoPrenotazione.completata || 
                     p.statoPrenotazione == StatoPrenotazione.annullata;
      
      // Se non è manager, vede solo le sue
      bool isMia = isManager ? true : p.idUtente == utente?.idUtente;
      
      return isChiusa && isMia;
    }).toList();

    // 2. Applichiamo il filtro della UI (se selezionato)
    if (filtroStato != null) {
      storico = storico.where((p) => p.statoPrenotazione == filtroStato).toList();
    }

    // 3. Ordiniamo per data (la più recente in alto)
    storico.sort((a, b) => b.dataFine.compareTo(a.dataFine));

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Storico Prenotazioni", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blueGrey[800],
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: storico.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: storico.length,
                    itemBuilder: (context, index) => _buildHistoryCard(storico[index], isManager),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      height: 60,
      color: Colors.white,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          _filterChip(null, "TUTTE"),
          _filterChip(StatoPrenotazione.completata, "COMPLETATE"),
          _filterChip(StatoPrenotazione.annullata, "ANNULLATE"),
        ],
      ),
    );
  }

  Widget _filterChip(StatoPrenotazione? stato, String label) {
    final isSelected = filtroStato == stato;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : Colors.blueGrey)),
        selected: isSelected,
        selectedColor: Colors.blueGrey,
        onSelected: (val) => setState(() => filtroStato = val ? stato : null),
      ),
    );
  }

  Widget _buildHistoryCard(Prenotazione p, bool isManager) {
    final DateFormat formatter = DateFormat('dd/MM/yyyy');
    final bool isAnnullata = p.statoPrenotazione == StatoPrenotazione.annullata;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(
          isAnnullata ? Icons.cancel_outlined : Icons.check_circle_outline,
          color: isAnnullata ? Colors.red : Colors.green,
          size: 32,
        ),
        title: Text("Veicolo: ${p.targa}", style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Periodo: ${formatter.format(p.dataInizio)} - ${formatter.format(p.dataFine)}"),
            if (isManager) Text("Driver ID: #${p.idUtente}", style: const TextStyle(color: Colors.blueGrey, fontSize: 12)),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isAnnullata ? Colors.red[50] : Colors.green[50],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            p.statoPrenotazione.name.toUpperCase(),
            style: TextStyle(color: isAnnullata ? Colors.red[700] : Colors.green[700], fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_toggle_off, size: 80, color: Colors.grey),
          SizedBox(height: 16),
          Text("Nessuna prenotazione passata trovata.", style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}