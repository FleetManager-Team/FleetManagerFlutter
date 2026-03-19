import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart'; // Aggiunto per eventuali date
import 'package:fleetmanager/provider/fleet_provider.dart';
import 'package:fleetmanager/models/veicolo.dart';
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
      margin: const EdgeInsets.all(8),
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

  // --- NUOVO POPUP DETTAGLI MANUTENZIONE ---
  void _showMaintenanceDetails(Veicolo v, FleetProvider provider) {
    showDialog(
      context: context,
      builder: (context) => DetailsPopUp(
        title: "Dettaglio Manutenzione",
        titleIcon: Icons.build_circle,
        details: [
          _detailRow(Icons.pin, "Targa", v.targa),
          _detailRow(Icons.speed, "Chilometraggio", "${v.km} km"),
          _detailRow(Icons.category, "Tipo", v.tipoVeicolo.name.toUpperCase()),
        ],
        extraSectionTitle: "Stato Intervento",
        // Dato che il riquadro del tuo popup è azzurro fisso,
        // usiamo icone e testi arancioni per far capire lo stato.
        extraContent: Row(
          children: [
            const Icon(Icons.settings_suggest, color: Colors.orange, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "IN ASSISTENZA",
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange[900],
                        fontSize: 13),
                  ),
                  const Text(
                    "Veicolo non disponibile per prenotazioni.",
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("INDIETRO"),
          ),
          ElevatedButton(
            onPressed: () async {
              await provider.chiudiManutenzione(0, v.targa);
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text("Veicolo ${v.targa} rientrato in flotta")),
                );
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green, foregroundColor: Colors.white),
            child: const Text("CHIUDI INTERVENTO"),
          ),
        ],
      ),
    );
  }

  // Helper per le righe di dettaglio
  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[600]),
          const SizedBox(width: 10),
          Text("$label: ", style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(value),
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
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            left: 20,
            right: 20,
            top: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "Segnala Nuovo Intervento",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 15),
            DropdownButtonFormField<Veicolo>(
              items: veicoliDisponibili
                  .map((v) => DropdownMenuItem(
                      value: v, child: Text("${v.targa} - ${v.modello}")))
                  .toList(),
              onChanged: (val) => veicoloSelezionato = val,
              decoration: const InputDecoration(
                labelText: "Seleziona Veicolo",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.directions_car),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: descController,
              decoration: const InputDecoration(
                labelText: "Descrizione guasto / motivo",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.edit_note),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                if (veicoloSelezionato != null) {
                  await provider.segnalareInterventoStraordinario(
                    veicoloSelezionato!,
                    descController.text,
                  );
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text(
                              "Manutenzione avviata per ${veicoloSelezionato!.targa}")),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange[800],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
              child: const Text("AVVIA MANUTENZIONE",
                  style: TextStyle(fontWeight: FontWeight.bold)),
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
          Text("Nessun veicolo in manutenzione",
              style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 16,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
