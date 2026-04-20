import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';
import 'package:FleetManager/provider/fleet_provider.dart';
import 'package:FleetManager/core/theme/index.dart';
import 'package:FleetManager/models/prenotazione.dart';
import 'package:FleetManager/models/enums/stato_prenotazione.dart';
import 'package:FleetManager/models/enums/ruolo_utente.dart';

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
    // Aggiorna i dati dal server all'apertura della pagina
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FleetProvider>().inizializzaDati();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FleetProvider>();
    final isManager =
        provider.utenteLoggato?.ruoloUtente == RuoloUtente.manager;

    // Logica di filtraggio della lista
    List<Prenotazione> lista = provider.prenotazioni.where((p) {
      // Esclude sempre le prenotazioni completate dal registro principale
      if (p.statoPrenotazione == StatoPrenotazione.completata) return false;
      if (p.statoPrenotazione == StatoPrenotazione.annullata) return false;

      // Filtro per stato selezionato nel Dropdown
      final matchStato =
          filtroStato == null || p.statoPrenotazione == filtroStato;

      // Ricerca testuale per targa
      final matchRicerca =
          p.targa.toLowerCase().contains(queryRicerca.toLowerCase());

      // Se l'utente non è manager, vede solo le proprie prenotazioni
      final matchUtente =
          isManager || p.idUtente == provider.utenteLoggato?.idUtente;

      return matchStato && matchRicerca && matchUtente;
    }).toList();

    // Ordinamento cronologico
    lista.sort((a, b) {
      int cmp = a.dataInizio.compareTo(b.dataInizio);
      return ordineCrescente ? cmp : -cmp;
    });

    return Scaffold(
      backgroundColor: AppColors.grey100,
      appBar: _buildAppBar(provider),
      body: Column(
        children: [
          _buildSearchAndFilters(),
          Expanded(
            child: provider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : lista.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: () => provider.inizializzaDati(),
                        child: ListView.builder(
                          padding: const EdgeInsets.all(AppSpacing.md),
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

  PreferredSizeWidget _buildAppBar(FleetProvider provider) {
    return AppBar(
      title: const Text("Registro Prenotazioni",
          style: TextStyle(fontWeight: FontWeight.bold)),
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.white,
      actions: [
        IconButton(
          icon:
              Icon(ordineCrescente ? Icons.arrow_upward : Icons.arrow_downward),
          onPressed: () => setState(() => ordineCrescente = !ordineCrescente),
        ),
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: () => provider.inizializzaDati(),
        ),
      ],
    );
  }

  Widget _buildSearchAndFilters() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      color: AppColors.white,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              onChanged: (val) => setState(() => queryRicerca = val),
              decoration: InputDecoration(
                hintText: "Cerca targa...",
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: AppColors.grey100,
                contentPadding: EdgeInsets.zero,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusDefault),
                  borderSide: BorderSide.none,
                ),
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
              ...StatoPrenotazione.values
                  .where((s) => s != StatoPrenotazione.completata)
                  .map((s) => DropdownMenuItem(
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusDefault)),
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
                  style: const TextStyle(fontSize: 12, color: AppColors.grey500)),
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
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusLarge)),
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
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusDefault)),
              child: Text(p.statoPrenotazione.name.toUpperCase(),
                  style: TextStyle(
                      color: statusColor, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("CHIUDI")),
          if (isManager &&
              p.statoPrenotazione == StatoPrenotazione.richiesta) ...[
            _actionButton("RIFIUTA", AppColors.error, () async {
              await provider.annullaPrenotazione(p.idPrenotazione);
              if (mounted) Navigator.pop(context);
            }),
            _actionButton("APPROVA", AppColors.success, () async {
              await provider.confermaPrenotazione(p.idPrenotazione);
              if (mounted) Navigator.pop(context);
            }),
          ],
        ],
      ),
    );
  }

  Widget _actionButton(String label, Color color, VoidCallback onPressed) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(backgroundColor: color),
      onPressed: onPressed,
      child: Text(label, style: const TextStyle(color: AppColors.white)),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(fontSize: 11, color: AppColors.grey500)),
              Text(value,
                  style: const TextStyle(
                      fontWeight: FontWeight.w500, fontSize: 14)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusTag(StatoPrenotazione stato, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration:
          BoxDecoration(color: color, borderRadius: BorderRadius.circular(AppSpacing.radiusXLarge)),
      child: Text(
        stato.name.toUpperCase(),
        style: const TextStyle(
            fontSize: 9, color: AppColors.white, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_busy, size: 60, color: AppColors.grey400),
          SizedBox(height: 10),
          Text("Nessuna prenotazione attiva",
              style: TextStyle(color: AppColors.grey600)),
        ],
      ),
    );
  }

  Color _getBookingStatusColor(StatoPrenotazione stato) {
    switch (stato) {
      case StatoPrenotazione.richiesta:
        return AppColors.secondary;
      case StatoPrenotazione.attiva:
        return AppColors.success;
      case StatoPrenotazione.completata:
        return AppColors.grey600;
      case StatoPrenotazione.annullata:
        return AppColors.error;
      case StatoPrenotazione.confermata:
        return AppColors.primaryDark;
      case StatoPrenotazione.sospesa:
        return Colors.grey;
      case StatoPrenotazione.attesaCheckup:
        return AppColors.primaryDark;
    }
  }
}
