import 'package:fleetmanager/models/enums/ruolo_utente.dart';
import 'package:fleetmanager/models/enums/stato_prenotazione.dart';
import 'package:fleetmanager/models/prenotazione.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fleetmanager/models/enums/stato_veicolo.dart';
import 'package:fleetmanager/models/enums/tipo_veicolo.dart';
import 'package:fleetmanager/provider/fleet_provider.dart';
import 'package:fleetmanager/models/veicolo.dart';

class VehicleListScreen extends StatefulWidget {
  const VehicleListScreen({super.key});

  @override
  State<VehicleListScreen> createState() => _VehicleListScreenState();
}

class _VehicleListScreenState extends State<VehicleListScreen> {
  // null significa "Tutti i veicoli"
  StatoVeicolo? filtroSelezionato;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FleetProvider>();

    // Logica di filtraggio
    final veicoliFiltrati = filtroSelezionato == null
        ? provider.veicoli
        : provider.veicoli
              .where((v) => v.statoVeicolo == filtroSelezionato)
              .toList();

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          "Parco Veicoli",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Sezione Filtri
          _buildFilterBar(),

          // Lista Risultati
          Expanded(
            child: veicoliFiltrati.isEmpty
                ? const Center(
                    child: Text("Nessun veicolo trovato con questo filtro"),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: veicoliFiltrati.length,
                    itemBuilder: (context, index) {
                      return _buildVehicleCard(veicoliFiltrati[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  /// Barra dei filtri orizzontale
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

  /// Singolo pulsante di filtro
  Widget _filterChip(StatoVeicolo? stato, String label) {
    final isSelected = filtroSelezionato == stato;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : Colors.blue[800],
          ),
        ),
        selected: isSelected,
        selectedColor: Colors.blue[800],
        backgroundColor: Colors.blue[50],
        onSelected: (selected) {
          setState(() {
            filtroSelezionato = selected ? stato : null;
          });
        },
      ),
    );
  }

  Widget _buildVehicleCard(Veicolo v) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        // --- AGGIUNGIAMO IL TOCCO QUI ---
        onTap: () => _showVehicleDetails(v),
        // --------------------------------
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
        title: Text(
          "${v.marca} ${v.modello}",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text("Targa: ${v.targa} • ${v.km} km"),
        trailing: _buildStatusChip(v.statoVeicolo),
      ),
    );
  }

  void _showVehicleDetails(Veicolo v) {
    final provider = context.read<FleetProvider>();

    // 1. Cerchiamo tutte le prenotazioni per questa targa che non siano annullate
    // e che finiscano dopo "adesso"
    List<Prenotazione> prenotazioniFuture = provider.prenotazioni
        .where(
          (p) =>
              p.targa == v.targa &&
              p.statoPrenotazione != StatoPrenotazione.annullata &&
              p.dataFine.isAfter(DateTime.now()),
        )
        .toList();

    // 2. Le ordiniamo per data d'inizio (la più vicina per prima)
    prenotazioniFuture.sort((a, b) => a.dataInizio.compareTo(b.dataInizio));

    // 3. Prendiamo la prima (se esiste)
    Prenotazione? prossima = prenotazioniFuture.isNotEmpty
        ? prenotazioniFuture.first
        : null;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(
                v.tipoVeicolo == TipoVeicolo.furgone
                    ? Icons.local_shipping
                    : Icons.directions_car,
                color: Colors.blue[800],
              ),
              const SizedBox(width: 10),
              Expanded(child: Text("${v.marca} ${v.modello}")),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _detailRow(Icons.tag, "Targa", v.targa),
                _detailRow(
                  Icons.calendar_today,
                  "Anno",
                  v.annoImmatricolazione.toString(),
                ),
                _detailRow(Icons.speed, "Km attuali", "${v.km} km"),
                _detailRow(
                  Icons.info,
                  "Stato",
                  v.statoVeicolo.name.toUpperCase(),
                ),

                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Divider(),
                ),

                // --- SEZIONE PROSSIMA PRENOTAZIONE ---
                Text(
                  "PROSSIMA PRENOTAZIONE",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[900],
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 10),

                if (prossima != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.blue[100]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _detailRow(
                          Icons.person,
                          "ID Utente",
                          "#${prossima.idUtente}",
                        ),
                        _detailRow(
                          Icons.event,
                          "Inizio",
                          "${prossima.dataInizio.day}/${prossima.dataInizio.month} ore ${prossima.dataInizio.hour}:${prossima.dataInizio.minute.toString().padLeft(2, '0')}",
                        ),
                        _detailRow(
                          Icons.event_available,
                          "Fine",
                          "${prossima.dataFine.day}/${prossima.dataFine.month} ore ${prossima.dataFine.hour}:${prossima.dataFine.minute.toString().padLeft(2, '0')}",
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      "Nessun impegno futuro. Il veicolo è libero.",
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.green,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("CHIUDI"),
            ),
            // --- MODIFICA QUI: Mostra il tasto solo se NON è manager ---
            if (provider.utenteLoggato?.ruoloUtente != RuoloUtente.manager &&
                v.statoVeicolo == StatoVeicolo.disponibile)
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[800],
                ),
                onPressed: () {
                  Navigator.pop(context);
                  // Navigazione alla schermata di prenotazione per i Driver
                },
                child: const Text(
                  "PRENOTA ORA",
                  style: TextStyle(color: Colors.white),
                ),
              ),
          ],
        );
      },
    );
  }

  // Widget di supporto per le righe (mettilo sotto il metodo build)
  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(
            "$label: ",
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  Widget _buildStatusChip(StatoVeicolo stato) {
    return Chip(
      label: Text(
        stato.name.toUpperCase(),
        style: const TextStyle(
          fontSize: 9,
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      backgroundColor: _getStatusColor(stato),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
