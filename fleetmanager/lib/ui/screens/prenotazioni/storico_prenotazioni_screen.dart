import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fleetmanager/provider/fleet_provider.dart';
import 'package:fleetmanager/models/prenotazione.dart';
import 'package:fleetmanager/models/enums/stato_prenotazione.dart';
import 'package:fleetmanager/models/enums/ruolo_utente.dart';
import 'package:collection/collection.dart';
import 'package:fleetmanager/ui/screens/prenotazioni/dettaglio_prenotazione_manager.dart';

class BookingHistoryScreen extends StatefulWidget {
  const BookingHistoryScreen({super.key});

  @override
  State<BookingHistoryScreen> createState() => _BookingHistoryScreenState();
}

class _BookingHistoryScreenState extends State<BookingHistoryScreen> {
  StatoPrenotazione? filtroStato; // null = TUTTE

  Future<void> _onRefresh() async {
    await context.read<FleetProvider>().inizializzaDati();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FleetProvider>();
    final utente = provider.utenteLoggato;
    final isManager = utente?.ruoloUtente == RuoloUtente.manager;

    // --- LOGICA DI FILTRAGGIO AGGIORNATA ---
    List<Prenotazione> storico = provider.prenotazioni.where((p) {
      // 1. Identifichiamo se è una prenotazione finita temporalmente ma "dimenticata" (non completata)
      final bool isScadutaDimenticata =
          (p.statoPrenotazione == StatoPrenotazione.confermata ||
                  p.statoPrenotazione == StatoPrenotazione.attiva) &&
              DateTime.now().isAfter(p.dataFine);

      // 2. La mostriamo nello storico se è chiusa ufficialmente OPPURE se è scaduta
      bool belongsToHistory =
          p.statoPrenotazione == StatoPrenotazione.completata ||
              p.statoPrenotazione == StatoPrenotazione.annullata ||
              isScadutaDimenticata;

      // 3. Controllo permessi (Manager vede tutto, Driver solo le sue)
      bool isMia = isManager ? true : p.idUtente == utente?.idUtente;

      return belongsToHistory && isMia;
    }).toList();

    // Filtro della UI (Chip)
    if (filtroStato != null) {
      storico =
          storico.where((p) => p.statoPrenotazione == filtroStato).toList();
    }

    // Ordinamento: le più recenti (per data fine) in alto
    storico.sort((a, b) => b.dataFine.compareTo(a.dataFine));

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Storico Prenotazioni",
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blueGrey[800],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _onRefresh,
          )
        ],
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: provider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _onRefresh,
                    child: storico.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                            padding: const EdgeInsets.all(12),
                            itemCount: storico.length,
                            itemBuilder: (context, index) => _buildHistoryCard(
                                storico[index], isManager, provider),
                          ),
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
        label: Text(label,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : Colors.blueGrey)),
        selected: isSelected,
        selectedColor: Colors.blueGrey,
        onSelected: (val) => setState(() => filtroStato = val ? stato : null),
      ),
    );
  }

  Widget _buildHistoryCard(
      Prenotazione p, bool isManager, FleetProvider provider) {
    final DateFormat formatter = DateFormat('dd/MM/yyyy HH:mm');
    final bool isAnnullata = p.statoPrenotazione == StatoPrenotazione.annullata;
    final bool isCompletata =
        p.statoPrenotazione == StatoPrenotazione.completata;

    final bool deveCompilare = !isAnnullata &&
        !isCompletata &&
        DateTime.now().isAfter(p.dataFine.toLocal());

    String infoSottotitolo = "Fine: ${formatter.format(p.dataFine.toLocal())}";
    String? nomeDriver;
    if (isManager) {
      final d =
          provider.utenti.firstWhereOrNull((u) => u.idUtente == p.idUtente);
      if (d != null) nomeDriver = "Driver: ${d.nome} ${d.cognome}";
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: deveCompilare ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: deveCompilare
            ? const BorderSide(color: Colors.orange, width: 2)
            : BorderSide.none,
      ),
      child: ListTile(
        onTap: () {
          if (isManager || p.statoPrenotazione != StatoPrenotazione.annullata) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DettaglioPrenotazioneManager(prenotazione: p),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text(
                      "Non è possibile gestire una prenotazione annullata.")),
            );
          }
        },
        leading: Icon(
          isAnnullata
              ? Icons.cancel_outlined
              : (isCompletata ? Icons.check_circle_outline : Icons.history),
          color: isAnnullata
              ? Colors.red
              : (isCompletata ? Colors.green : Colors.orange),
          size: 32,
        ),
        title: Text("Veicolo: ${p.targa}",
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(infoSottotitolo),
            if (nomeDriver != null)
              Text(nomeDriver,
                  style: const TextStyle(
                      color: Colors.blueGrey,
                      fontSize: 12,
                      fontWeight: FontWeight.bold)),

            // Messaggio dinamico sotto la card
            if (!isManager && !isAnnullata)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Row(
                  children: [
                    Icon(isCompletata ? Icons.edit : Icons.add_a_photo,
                        size: 14,
                        color: isCompletata ? Colors.blue : Colors.orange),
                    const SizedBox(width: 5),
                    Text(
                      isCompletata
                          ? "MODIFICA DATI INSERITI"
                          : "AGGIUNGI DATI RESTITUZIONE",
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isCompletata ? Colors.blue : Colors.orange),
                    ),
                  ],
                ),
              ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
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
          Text("Nessun record trovato nello storico.",
              style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}
