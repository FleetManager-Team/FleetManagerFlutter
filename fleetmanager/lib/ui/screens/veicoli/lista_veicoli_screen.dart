import 'package:fleetmanager/models/enums/ruolo_utente.dart';
import 'package:fleetmanager/models/enums/stato_prenotazione.dart';
import 'package:fleetmanager/models/prenotazione.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fleetmanager/models/enums/stato_veicolo.dart';
import 'package:fleetmanager/models/enums/tipo_veicolo.dart';
import 'package:fleetmanager/provider/fleet_provider.dart';
import 'package:fleetmanager/models/veicolo.dart';
import 'package:fleetmanager/ui/widgets/details_pop_up.dart';

class VehicleListScreen extends StatefulWidget {
  const VehicleListScreen({super.key});

  @override
  State<VehicleListScreen> createState() => _VehicleListScreenState();
}

class _VehicleListScreenState extends State<VehicleListScreen> {
  StatoVeicolo? filtroSelezionato;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FleetProvider>();

    final veicoliFiltrati = filtroSelezionato == null
        ? provider.veicoli
        : provider.veicoli
            .where((v) => v.statoVeicolo == filtroSelezionato)
            .toList();

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Parco Veicoli",
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: veicoliFiltrati.isEmpty
                ? const Center(child: Text("Nessun veicolo trovato"))
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: veicoliFiltrati.length,
                    itemBuilder: (context, index) =>
                        _buildVehicleCard(veicoliFiltrati[index]),
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
          _filterChip(null, "TUTTI"),
          _filterChip(StatoVeicolo.disponibile, "DISPONIBILI"),
          _filterChip(StatoVeicolo.prenotato, "PRENOTATI"),
          _filterChip(StatoVeicolo.inManutenzione, "IN SERVICE"),
          _filterChip(StatoVeicolo.fuoriServizio, "OFF-LINE"),
        ],
      ),
    );
  }

  Widget _filterChip(StatoVeicolo? stato, String label) {
    final isSelected = filtroSelezionato == stato;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : Colors.blue[800])),
        selected: isSelected,
        selectedColor: Colors.blue[800],
        backgroundColor: Colors.blue[50],
        onSelected: (val) =>
            setState(() => filtroSelezionato = val ? stato : null),
      ),
    );
  }

  Widget _buildVehicleCard(Veicolo v) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        onTap: () => _showVehicleDetails(v),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _getStatusColor(v.statoVeicolo).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            v.tipoVeicolo == TipoVeicolo.furgone
                ? Icons.local_shipping
                : Icons.directions_car,
            color: _getStatusColor(v.statoVeicolo),
          ),
        ),
        title: Text("${v.marca} ${v.modello}",
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text("Targa: ${v.targa} • ${v.km} km"),
        trailing: _buildStatusChip(v.statoVeicolo),
      ),
    );
  }

  // --- LOGICA DEL POPUP DETTAGLI (Utilizza DetailsPopUp) ---

  void _showVehicleDetails(Veicolo v) {
    final provider = context.read<FleetProvider>();

    // Ricerca prossima prenotazione
    List<Prenotazione> future = provider.prenotazioni
        .where((p) =>
            p.targa == v.targa &&
            p.statoPrenotazione != StatoPrenotazione.annullata &&
            p.dataFine.isAfter(DateTime.now()))
        .toList();
    future.sort((a, b) => a.dataInizio.compareTo(b.dataInizio));
    Prenotazione? prossima = future.isNotEmpty ? future.first : null;

    showDialog(
      context: context,
      builder: (context) => DetailsPopUp(
        title: "${v.marca} ${v.modello}",
        titleIcon: v.tipoVeicolo == TipoVeicolo.furgone
            ? Icons.local_shipping
            : Icons.directions_car,
        details: [
          _detailRow(Icons.tag, "Targa", v.targa),
          _detailRow(Icons.calendar_today, "Immatricolazione",
              v.annoImmatricolazione.toString()),
          _detailRow(Icons.speed, "Chilometraggio", "${v.km} km"),
          _detailRow(Icons.info_outline, "Stato Attuale",
              v.statoVeicolo.name.toUpperCase()),
        ],
        extraSectionTitle: "PROSSIMO IMPEGNO",
        extraContent: prossima != null
            ? Column(
                children: [
                  _detailRow(
                      Icons.person, "Driver ID", "#${prossima.idUtente}"),
                  _detailRow(Icons.event, "Inizio",
                      DateFormat('dd/MM HH:mm').format(prossima.dataInizio)),
                  _detailRow(Icons.event_available, "Fine",
                      DateFormat('dd/MM HH:mm').format(prossima.dataFine)),
                ],
              )
            : const Text(
                "Nessuna prenotazione futura. Il veicolo è libero.",
                style: TextStyle(
                    fontSize: 13,
                    color: Colors.green,
                    fontStyle: FontStyle.italic),
              ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("CHIUDI")),
          if (provider.utenteLoggato?.ruoloUtente != RuoloUtente.manager &&
              v.statoVeicolo == StatoVeicolo.disponibile)
            ElevatedButton(
              style:
                  ElevatedButton.styleFrom(backgroundColor: Colors.blue[800]),
              onPressed: () {
                Navigator.pop(context);
                // Navigazione alla prenotazione
              },
              child: const Text("PRENOTA ORA",
                  style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
    );
  }

  // Helper per le righe di dettaglio
  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.blueGrey[400]),
          const SizedBox(width: 10),
          Text("$label: ",
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  Widget _buildStatusChip(StatoVeicolo stato) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _getStatusColor(stato),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        stato.name.toUpperCase(),
        style: const TextStyle(
            fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold),
      ),
    );
  }

  Color _getStatusColor(StatoVeicolo stato) {
    switch (stato) {
      case StatoVeicolo.disponibile:
        return Colors.green[600]!;
      case StatoVeicolo.prenotato:
        return Colors.blue[600]!;
      case StatoVeicolo.inManutenzione:
        return Colors.orange[700]!;
      case StatoVeicolo.fuoriServizio:
        return Colors.red[700]!;
    }
  }
}
