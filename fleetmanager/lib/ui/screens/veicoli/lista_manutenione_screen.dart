import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fleetmanager/provider/fleet_provider.dart';
import 'package:fleetmanager/models/veicolo.dart';
import 'package:fleetmanager/models/enums/stato_veicolo.dart';
import 'package:fleetmanager/models/enums/tipo_veicolo.dart';

class MaintenanceDashboardScreen extends StatefulWidget {
  const MaintenanceDashboardScreen({super.key});

  @override
  State<MaintenanceDashboardScreen> createState() => _MaintenanceDashboardScreenState();
}

class _MaintenanceDashboardScreenState extends State<MaintenanceDashboardScreen> {
  @override
  Widget build(BuildContext context) {
    // Watch permette di reagire ai notifyListeners() del provider
    final provider = context.watch<FleetProvider>();
    
    // Filtro locale sui veicoli caricati nel provider
    final veicoliInManutenzione = provider.veicoli
        .where((v) => v.statoVeicolo == StatoVeicolo.inManutenzione)
        .toList();

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Gestione Manutenzioni"),
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
                          return _buildMaintenanceCard(veicoliInManutenzione[index], provider);
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
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "$count Veicoli in Service",
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const Text("Interventi ordinari e straordinari", style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildMaintenanceCard(Veicolo v, FleetProvider provider) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: Icon(
          v.tipoVeicolo == TipoVeicolo.furgone ? Icons.local_shipping : Icons.directions_car,
          color: Colors.orange[800],
        ),
        title: Text("${v.marca} ${v.modello}", style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text("Targa: ${v.targa} • Ultimi Km: ${v.km}"),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _confirmCloseMaintenance(v, provider),
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text("CHIUDI INTERVENTO"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  // --- LOGICA DI INTEGRAZIONE MODIFICATA ---

  void _confirmCloseMaintenance(Veicolo v, FleetProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Completamento Lavori"),
        content: Text("Confermi che il veicolo ${v.targa} è pronto per tornare in flotta?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("ANNULLA")),
          ElevatedButton(
            onPressed: () async {
              // MODIFICA: Passiamo l'ID 0 (o quello reale) e la TARGA del veicolo
              await provider.chiudiManutenzione(0, v.targa); 
              
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Veicolo ${v.targa} ripristinato.")),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            child: const Text("CONFERMA"),
          ),
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
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 20, right: 20, top: 20
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Segnala Intervento", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            DropdownButtonFormField<Veicolo>(
              items: veicoliDisponibili.map((v) => DropdownMenuItem(value: v, child: Text("${v.targa} - ${v.modello}"))).toList(),
              onChanged: (val) => veicoloSelezionato = val,
              decoration: const InputDecoration(labelText: "Veicolo"),
            ),
            TextField(
              controller: descController,
              decoration: const InputDecoration(labelText: "Descrizione guasto"),
            ),
            const SizedBox(height: 20),
            // All'interno di _showNewMaintenanceDialog, modifica il tasto:
ElevatedButton(
       onPressed: () async {
          if (veicoloSelezionato != null) {
           await provider.segnalareInterventoStraordinario(
           veicoloSelezionato!, 
           descController.text,
         );

          if (context.mounted) {
           Navigator.pop(context);
            // AGGIUNGI QUESTO FEEDBACK:
             ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text("Manutenzione avviata per ${veicoloSelezionato!.targa}")),
           );
          }
       }
     },
      child: const Text("AVVIA MANUTENZIONE"),
    ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.build_circle_outlined, size: 80, color: Colors.grey),
          SizedBox(height: 16),
          Text("Nessun veicolo attualmente in manutenzione.", style: TextStyle(color: Colors.grey, fontSize: 16)),
        ],
      ),
    );
  }
}