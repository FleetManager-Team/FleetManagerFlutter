import 'package:fleetmanager/models/enums/ruolo_utente.dart';
import 'package:fleetmanager/models/enums/stato_prenotazione.dart';
import 'package:fleetmanager/models/manutenzione.dart';
import 'package:fleetmanager/models/prenotazione.dart';
import 'package:fleetmanager/ui/screens/prenotazioni/nuova_prenotazione_screen.dart';
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
    // watch permette alla lista di aggiornarsi in tempo reale se cambiano i dati sul DB
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
            child: provider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : veicoliFiltrati.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: veicoliFiltrati.length,
                        itemBuilder: (context, index) =>
                            _buildVehicleCard(veicoliFiltrati[index]),
                      ),
          ),
        ],
      ),
      floatingActionButton:
          provider.utenteLoggato?.ruoloUtente == RuoloUtente.manager
              ? FloatingActionButton(
                  onPressed: () => _showAddVehicleForm(context),
                  backgroundColor: Colors.blue[900],
                  child: const Icon(Icons.add, color: Colors.white),
                )
              : null,
    );
  }

  Widget _buildFilterBar() {
    return Container(
      height: 60,
      width: double.infinity,
      color: Colors.white,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          _filterChip(null, "TUTTI"),
          _filterChip(StatoVeicolo.disponibile, "DISPONIBILI"),
          _filterChip(StatoVeicolo.prenotato, "PRENOTATI"),
          _filterChip(StatoVeicolo.inManutenzione, "IN SERVICE"),
          _filterChip(StatoVeicolo.fuoriServizio, "NON DISPONIBILI"),
        ],
      ),
    );
  }

  Widget _filterChip(StatoVeicolo? stato, String label) {
    final isSelected = filtroSelezionato == stato;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        labelStyle: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : Colors.blue[800]),
        selected: isSelected,
        selectedColor: Colors.blue[800],
        backgroundColor: Colors.blue[50],
        onSelected: (val) =>
            setState(() => filtroSelezionato = val ? stato : null),
      ),
    );
  }

 Widget _buildVehicleCard(Veicolo v) {
  final provider = context.watch<FleetProvider>();
  
  // Cerchiamo se c'è una manutenzione programmata (non ancora chiusa e futura)
  final manutenzioneProgrammata = provider.manutenzioni.cast<Manutenzione?>().firstWhere(
    (m) => m?.targa == v.targa && m?.oraFine == null && m!.data.isAfter(DateTime.now()),
    orElse: () => null,
  );

  return Card(
    elevation: 2,
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
      
      // MODIFICA QUI: Subtitle multi-riga per mostrare i KM e l'eventuale avviso
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Targa: ${v.targa} • ${v.km} km"),
          
          // Se c'è una manutenzione in arrivo, mostriamo l'avviso arancione
          if (manutenzioneProgrammata != null)
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Row(
                children: [
                  const Icon(Icons.event_busy, color: Colors.orange, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    "Manutenzione: ${manutenzioneProgrammata.data.day}/${manutenzioneProgrammata.data.month} ore ${manutenzioneProgrammata.data.hour}:${manutenzioneProgrammata.data.minute.toString().padLeft(2, '0')}",
                    style: const TextStyle(
                      color: Colors.orange, 
                      fontSize: 11, 
                      fontWeight: FontWeight.bold
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      trailing: _buildStatusChip(v.statoVeicolo),
    ),
  );
}

  void _showVehicleDetails(Veicolo v) {
    final provider = context.read<FleetProvider>();

    // Calcolo prossima prenotazione per questo veicolo
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
          _detailRow(
              Icons.calendar_today, "Anno", v.annoImmatricolazione.toString()),
          _detailRow(Icons.speed, "Km attuali", "${v.km} km"),
          _detailRow(
              Icons.info_outline, "Stato", v.statoVeicolo.name.toUpperCase()),
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
                "Nessuna prenotazione futura.",
                style: TextStyle(
                    fontSize: 13,
                    color: Colors.green,
                    fontStyle: FontStyle.italic),
              ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("CHIUDI")),
          // Se il veicolo è disponibile e l'utente non è manager, può prenotare
          if (provider.utenteLoggato?.ruoloUtente != RuoloUtente.manager &&
              v.statoVeicolo == StatoVeicolo.disponibile)
            ElevatedButton(
              style:
                  ElevatedButton.styleFrom(backgroundColor: Colors.blue[800]),
              onPressed: () {
                Navigator.pop(context); // Chiude il popup
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const NuovaPrenotazioneScreen()),
                );
              },
              child: const Text("PRENOTA ORA",
                  style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 60, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text("Nessun veicolo corrisponde al filtro",
              style: TextStyle(color: Colors.grey[600], fontSize: 16)),
        ],
      ),
    );
  }

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

  void _showAddVehicleForm(BuildContext context) {
    final targaController = TextEditingController();
    final marcaController = TextEditingController();
    final modelloController = TextEditingController();
    final kmController = TextEditingController();
    final annoController = TextEditingController(text: DateTime.now().year.toString());
    TipoVeicolo tipoSelezionato = TipoVeicolo.auto;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 20,
          right: 20,
          top: 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("AGGIUNGI NUOVO VEICOLO",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 20),
              TextField(
                  controller: targaController,
                  decoration: const InputDecoration(labelText: "Targa")),
              TextField(
                  controller: marcaController,
                  decoration: const InputDecoration(labelText: "Marca")),
              TextField(
                  controller: modelloController,
                  decoration: const InputDecoration(labelText: "Modello")),
              TextField(
                controller: annoController,
                decoration:
                    const InputDecoration(labelText: "Anno Immatricolazione"),
                keyboardType: TextInputType.number,
              ),
              TextField(
                  controller: kmController,
                  decoration:
                      const InputDecoration(labelText: "Kilometri attuali"),
                  keyboardType: TextInputType.number),
              const SizedBox(height: 15),
              DropdownButtonFormField<TipoVeicolo>(
                initialValue: tipoSelezionato,
                decoration: const InputDecoration(labelText: "Tipo Veicolo"),
                items: TipoVeicolo.values
                    .map((t) => DropdownMenuItem(
                        value: t, child: Text(t.name.toUpperCase())))
                    .toList(),
                onChanged: (val) => tipoSelezionato = val!,
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  backgroundColor: Colors.blue[900],
                ),
                onPressed: () async {
                  final provider = context.read<FleetProvider>();

                  try {
                    await provider.aggiungiNuovoVeicolo(
                      targa: targaController.text,
                      marca: marcaController.text,
                      modello: modelloController.text,
                      tipo:
                          tipoSelezionato.name, 
                      anno: annoController.text,
                      kmAttuali: kmController.text,
                    );

                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text("Veicolo aggiunto con successo!")),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Errore: ${e.toString()}")),
                      );
                    }
                  }
                },
                child: const Text("SALVA VEICOLO",
                    style: TextStyle(color: Colors.white)),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
