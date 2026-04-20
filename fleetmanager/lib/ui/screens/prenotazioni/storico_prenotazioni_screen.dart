import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fleetmanager/provider/fleet_provider.dart';
import 'package:fleetmanager/models/prenotazione.dart';
import 'package:fleetmanager/core/theme/index.dart';
import 'package:fleetmanager/models/enums/stato_prenotazione.dart';
import 'package:fleetmanager/models/enums/ruolo_utente.dart';
import 'package:fleetmanager/ui/screens/prenotazioni/dettaglio_prenotazione_manager.dart';

class BookingHistoryScreen extends StatefulWidget {
  const BookingHistoryScreen({super.key});

  @override
  State<BookingHistoryScreen> createState() => _BookingHistoryScreenState();
}

class _BookingHistoryScreenState extends State<BookingHistoryScreen> {
  StatoPrenotazione? filtroStato;

  Future<void> _onRefresh() async {
    await context.read<FleetProvider>().inizializzaDati();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FleetProvider>();
    final utente = provider.utenteLoggato;
    final isManager = utente?.ruoloUtente == RuoloUtente.manager;

    List<Prenotazione> storico = provider.prenotazioni.where((p) {
      final bool isScadutaDimenticata =
          (p.statoPrenotazione == StatoPrenotazione.confermata ||
                  p.statoPrenotazione == StatoPrenotazione.attiva) &&
              DateTime.now().isAfter(p.dataFine);

      bool belongsToHistory =
          p.statoPrenotazione == StatoPrenotazione.completata ||
              p.statoPrenotazione == StatoPrenotazione.annullata ||
              isScadutaDimenticata;

      bool isMia = isManager ? true : p.idUtente == utente?.idUtente;
      return belongsToHistory && isMia;
    }).toList();

    if (filtroStato != null) {
      storico = storico.where((p) => p.statoPrenotazione == filtroStato).toList();
    }

    storico.sort((a, b) => b.dataFine.compareTo(a.dataFine));

    return Scaffold(
      backgroundColor: AppColors.grey100,
      appBar: AppBar(
        title: const Text("Storico Prenotazioni",
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.grey800,
        foregroundColor: AppColors.white,
        elevation: 0,
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
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            itemCount: storico.length,
                            itemBuilder: (context, index) => 
                                _buildSimpleHistoryCard(storico[index], isManager, provider),
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
      decoration: BoxDecoration(
        color: AppColors.white,
        boxShadow: [BoxShadow(color: AppColors.grey900.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))],
      ),
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
        label: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
        selected: isSelected,
        onSelected: (val) => setState(() => filtroStato = val ? stato : null),
        selectedColor: AppColors.grey800,
        labelStyle: TextStyle(color: isSelected ? Colors.white : AppColors.grey800),
      ),
    );
  }

  Widget _buildSimpleHistoryCard(Prenotazione p, bool isManager, FleetProvider provider) {
    final df = DateFormat('dd/MM/yyyy HH:mm');
    final driver = provider.getDriverDallaPrenotazione(p);
    
    // Colori e icone in base allo stato
    Color statusColor;
    IconData statusIcon;
    
    if (p.statoPrenotazione == StatoPrenotazione.annullata) {
      statusColor = Colors.red;
      statusIcon = Icons.cancel;
    } else if (p.statoPrenotazione == StatoPrenotazione.completata) {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
    } else {
      statusColor = Colors.orange; // Per le "scadute/dimenticate"
      statusIcon = Icons.history;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
        side: BorderSide(color: Colors.grey.withOpacity(0.2)),
      ),
      child: InkWell( // Rende tutta la card cliccabile
        borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => DettaglioPrenotazioneManager(prenotazione: p)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              // Icona di stato a sinistra
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(statusIcon, color: statusColor, size: 24),
              ),
              const SizedBox(width: 16),
              
              // Informazioni centrali
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.targa,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1.1),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "${driver.nome} ${driver.cognome}",
                      style: const TextStyle(color: AppColors.grey600, fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 12, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          df.format(p.dataFine.toLocal()),
                          style: const TextStyle(color: AppColors.grey500, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Frecciolina a destra
              const Icon(Icons.chevron_right, color: AppColors.grey400),
            ],
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
          Icon(Icons.history_toggle_off, size: 60, color: Colors.grey),
          SizedBox(height: 16),
          Text("Nessun record trovato nello storico.", style: TextStyle(color: AppColors.grey500)),
        ],
      ),
    );
  }
}