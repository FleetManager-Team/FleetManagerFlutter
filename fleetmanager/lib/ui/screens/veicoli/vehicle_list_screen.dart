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
      default:
        return Colors.grey;
    }
  }
}
