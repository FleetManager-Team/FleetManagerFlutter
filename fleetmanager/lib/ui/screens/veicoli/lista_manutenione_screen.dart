import 'package:fleetmanager/models/enums/tipo_manutenzione.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fleetmanager/provider/fleet_provider.dart';
import 'package:fleetmanager/models/veicolo.dart';
import 'package:fleetmanager/models/manutenzione.dart'; // Assicurati di importare il modello
import 'package:fleetmanager/models/enums/stato_veicolo.dart';
import 'package:fleetmanager/models/enums/tipo_veicolo.dart';
import 'package:fleetmanager/ui/widgets/details_pop_up.dart';

class MaintenanceDashboardScreen extends StatefulWidget {
  const MaintenanceDashboardScreen({super.key});

  @override
  State<MaintenanceDashboardScreen> createState() =>
      _MaintenanceDashboardScreenState();
}

class _MaintenanceDashboardScreenState
    extends State<MaintenanceDashboardScreen> {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FleetProvider>();

    // Filtriamo i veicoli che sono attualmente in manutenzione
    final veicoliInManutenzione = provider.veicoli
        .where((v) => v.statoVeicolo == StatoVeicolo.inManutenzione)
        .toList();

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Gestione Manutenzioni",
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.orange[800],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_business),
            onPressed: () => _showNewMaintenanceDialog(context),
            tooltip: "Nuovo Intervento",
          )
        ],
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildSummaryHeader(veicoliInManutenzione.length),
                Expanded(
                  child: veicoliInManutenzione.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: veicoliInManutenzione.length,
                          itemBuilder: (context, index) {
                            return _buildMaintenanceCard(
                                veicoliInManutenzione[index], provider);
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildSummaryHeader(int count) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "$count Veicoli in Service",
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          Text("Interventi attivi nella flotta",
              style: TextStyle(color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildMaintenanceCard(Veicolo v, FleetProvider provider) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        onTap: () => _showMaintenanceDetails(v, provider),
        leading: CircleAvatar(
          backgroundColor: Colors.orange[100],
          child: Icon(
            v.tipoVeicolo == TipoVeicolo.furgone
                ? Icons.local_shipping
                : Icons.directions_car,
            color: Colors.orange[800],
          ),
        ),
        title: Text("${v.marca} ${v.modello}",
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text("Targa: ${v.targa}"),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }

  void _showMaintenanceDetails(Veicolo v, FleetProvider provider) {
    // Recuperiamo l'ID dell'intervento aperto per questo veicolo dalla lista manutenzioni
    // Se non lo trovi, usiamo un fallback o gestiamo l'errore
    final intervento = provider.manutenzioni.firstWhere(
      (m) => m.targa == v.targa && m.oraFine == null,
      orElse: () => Manutenzione(
          idManutenzione: -1, 
          data: DateTime.now(), 
          tipoManutenzione: TipoManutenzione.straordinaria, 
          descrizione: "N.D.", 
          targa: v.targa),
    );

    final kmController = TextEditingController(text: v.km.toString());

    showDialog(
      context: context,
      builder: (context) => DetailsPopUp(
        title: "Dettaglio Manutenzione",
        titleIcon: Icons.build_circle,
        details: [
          _detailRow(Icons.pin, "Targa", v.targa),
          _detailRow(Icons.speed, "Km ingresso", "${v.km} km"),
          _detailRow(Icons.description, "Motivo", intervento.descrizione),
        ],
        extraSectionTitle: "Chiusura Intervento",
        extraContent: Column(
          children: [
            const Text("Inserisci i chilometri attuali al rientro:", 
              style: TextStyle(fontSize: 12, color: Colors.black54)),
            TextField(
              controller: kmController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Km finali"),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("INDIETRO")),
          ElevatedButton(
            onPressed: () async {
              int nuoviKm = int.tryParse(kmController.text) ?? v.km;
              // Passiamo l'ID reale dell'intervento e i nuovi KM
              await provider.chiudiManutenzione(intervento.idManutenzione, v.targa, nuoviKm: nuoviKm);
              
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Veicolo ${v.targa} rientrato con $nuoviKm km")),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            child: const Text("CHIUDI INTERVENTO"),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[600]),
          const SizedBox(width: 10),
          Text("$label: ", style: const TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(value, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }

  void _showNewMaintenanceDialog(BuildContext context) {
    final provider = context.read<FleetProvider>();
    final veicoliDisponibili = provider.veicoli
        .where((v) => v.statoVeicolo != StatoVeicolo.inManutenzione)
        .toList();

    Veicolo? veicoloSelezionato;
    final descController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            left: 20, right: 20, top: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text("Segnala Nuovo Intervento", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            const SizedBox(height: 15),
            DropdownButtonFormField<Veicolo>(
              items: veicoliDisponibili.map((v) => DropdownMenuItem(value: v, child: Text("${v.targa} - ${v.modello}"))).toList(),
              onChanged: (val) => veicoloSelezionato = val,
              decoration: const InputDecoration(labelText: "Seleziona Veicolo", border: OutlineInputBorder(), prefixIcon: Icon(Icons.directions_car)),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: descController,
              decoration: const InputDecoration(labelText: "Descrizione guasto", border: OutlineInputBorder(), prefixIcon: Icon(Icons.edit_note)),
              maxLines: 2,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                if (veicoloSelezionato != null && descController.text.isNotEmpty) {
                  await provider.segnalareInterventoStraordinario(veicoloSelezionato!, descController.text);
                  if (mounted) {
                    Navigator.pop(context);
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange[800], foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 15)),
              child: const Text("AVVIA MANUTENZIONE", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.build_circle_outlined, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text("Nessun veicolo in manutenzione", style: TextStyle(color: Colors.grey[600], fontSize: 16, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}