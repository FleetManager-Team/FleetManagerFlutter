import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fleetmanager/provider/fleet_provider.dart';
import 'package:fleetmanager/models/enums/ruolo_utente.dart';
import 'package:fleetmanager/ui/screens/login_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Ascoltiamo il provider per avere i dati in tempo reale
    final fleetProvider = context.watch<FleetProvider>();
    final utente = fleetProvider.utenteLoggato;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Fleet Manager Pro"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              fleetProvider.logout();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
              );
            },
          )
        ],
      ),
      body: fleetProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Benvenuto, ${utente?.nome} ${utente?.cognome}",
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 20),
                  
                  // Sezione condizionale in base al ruolo
                  if (utente?.ruoloUtente == RuoloUtente.admin)
                    _buildAdminDashboard(context, fleetProvider)
                  else
                    _buildDriverDashboard(context, fleetProvider),
                ],
              ),
            ),
    );
  }

  // Dashboard per l'Amministratore
  Widget _buildAdminDashboard(BuildContext context, FleetProvider provider) {
    return Column(
      children: [
        Row(
          children: [
            _buildStatCard("Veicoli", "${provider.veicoli.length}", Icons.directions_car, Colors.blue),
            _buildStatCard("Prenotazioni", "${provider.prenotazioni.length}", Icons.event_note, Colors.orange),
          ],
        ),
        const SizedBox(height: 20),
        const Text("Stato Flotta", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        // Qui potremmo mettere una lista o un grafico
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: provider.veicoli.length,
          itemBuilder: (context, index) {
            final v = provider.veicoli[index];
            return ListTile(
              leading: const Icon(Icons.car_rental),
              title: Text("${v.marca} ${v.modello}"),
              subtitle: Text("Targa: ${v.targa}"),
              trailing: Chip(label: Text(v.statoVeicolo.name)),
            );
          },
        ),
      ],
    );
  }

  // Dashboard per il Driver
  Widget _buildDriverDashboard(BuildContext context, FleetProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Le tue prenotazioni", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        provider.prenotazioni.isEmpty
            ? const Text("Non hai prenotazioni attive.")
            : ListView.builder(
                shrinkWrap: true,
                itemCount: provider.prenotazioni.length,
                itemBuilder: (context, index) {
                  final p = provider.prenotazioni[index];
                  return Card(
                    child: ListTile(
                      title: Text("Veicolo: ${p.targa}"),
                      subtitle: Text("Dal: ${p.dataInizio.toLocal()}"),
                      trailing: Icon(Icons.circle, color: p.statoPrenotazione.name == 'attiva' ? Colors.green : Colors.grey),
                    ),
                  );
                },
              ),
        const SizedBox(height: 30),
        ElevatedButton.icon(
          onPressed: () { /* Prossimo step: Pagina prenotazione */ },
          icon: const Icon(Icons.add),
          label: const Text("Nuova Prenotazione"),
          style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
        ),
      ],
    );
  }

  // Utility per creare le card delle statistiche
  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Card(
        color: color.withValues(alpha: 0.1),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Icon(icon, color: color),
              Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              Text(title),
            ],
          ),
        ),
      ),
    );
  }
}