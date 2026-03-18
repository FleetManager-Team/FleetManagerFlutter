import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fleetmanager/provider/fleet_provider.dart';
import 'package:fleetmanager/models/enums/ruolo_utente.dart';
import 'package:fleetmanager/models/enums/stato_prenotazione.dart';
import 'package:fleetmanager/models/veicolo.dart';
import 'package:fleetmanager/models/prenotazione.dart';
import 'package:fleetmanager/models/utente.dart';
import 'package:fleetmanager/ui/screens/login_screen.dart';
import 'package:fleetmanager/ui/screens/nuova_prenotazione_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Carichiamo i dati all'avvio (usa i Mock caricati ieri)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FleetProvider>().inizializzaDati();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FleetProvider>();
    final utente = provider.utenteLoggato;
    final bool isAdmin = utente?.ruoloUtente == RuoloUtente.admin;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: _buildAppBar(context, utente),
      drawer: _buildDrawer(context, utente),
      body: provider.isLoading 
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: () => provider.inizializzaDati(),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(utente),
                  const SizedBox(height: 25),
                  if (isAdmin) ...[
                    _buildAdminStats(provider),
                    const SizedBox(height: 25),
                    _buildSectionTitle("Stato Flotta Real-Time"),
                    _buildVeicoliList(provider.veicoli),
                  ] else ...[
                    _buildDriverActionCard(context),
                    const SizedBox(height: 25),
                    _buildSectionTitle("Le Mie Prenotazioni"),
                    _buildPrenotazioniList(provider.prenotazioni),
                  ],
                ],
              ),
            ),
          ),
    );
  }

  // --- COMPONENTI DELLA UI ---

  AppBar _buildAppBar(BuildContext context, Utente? utente) {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.blue[800],
      foregroundColor: Colors.white,
      title: const Text("FleetManager Pro", style: TextStyle(fontWeight: FontWeight.bold)),
      actions: [
        IconButton(
          icon: const Icon(Icons.notifications_none),
          onPressed: () { /* Naviga a Notifiche */ },
        ),
      ],
    );
  }

  Widget _buildHeader(Utente? utente) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Bentornato,",
          style: TextStyle(fontSize: 16, color: Colors.grey[600]),
        ),
        Text(
          "${utente?.nome ?? ''} ${utente?.cognome ?? ''}",
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  // Dashboard per ADMIN: Statistiche rapide
  Widget _buildAdminStats(FleetProvider provider) {
    return Row(
      children: [
        _statCard("Totale Veicoli", provider.veicoli.length.toString(), Icons.directions_car, Colors.blue),
        _statCard("Attive", provider.prenotazioni.where((p) => p.statoPrenotazione == StatoPrenotazione.inCorso).length.toString(), Icons.play_arrow, Colors.green),
        _statCard("In Manutenzione", "2", Icons.build, Colors.orange), // Dato simulato
      ],
    );
  }

  // Dashboard per DRIVER: Azione rapida
  Widget _buildDriverActionCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.blue[700]!, Colors.blue[500]!]),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Hai bisogno di un'auto?", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => NuovaPrenotazioneScreen()),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.blue[700]),
            child: const Text("PRENOTA ORA"),
          )
        ],
      ),
    );
  }

  Widget _buildVeicoliList(List<Veicolo> veicoli) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: veicoli.length,
      itemBuilder: (context, index) => Card(
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: ListTile(
          leading: const CircleAvatar(backgroundColor: Colors.blueGrey, child: Icon(Icons.car_repair, color: Colors.white)),
          title: Text("${veicoli[index].marca} ${veicoli[index].modello}", style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text("Targa: ${veicoli[index].targa}"),
          trailing: const Icon(Icons.chevron_right),
          onTap: () { /* Dettaglio veicolo */ },
        ),
      ),
    );
  }

  Widget _buildPrenotazioniList(List<Prenotazione> prenotazioni) {
    if (prenotazioni.isEmpty) return const Center(child: Text("Nessuna prenotazione trovata"));
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: prenotazioni.length,
      itemBuilder: (context, index) {
        final p = prenotazioni[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            title: Text("Prenotazione #${p.idPrenotazione}"),
            subtitle: Text("Veicolo: ${p.targa}\nFino al: ${p.dataFine.day}/${p.dataFine.month}"),
            isThreeLine: true,
            trailing: Chip(label: Text(p.statoPrenotazione.name), backgroundColor: Colors.green[100]),
          ),
        );
      },
    );
  }

  // Helper UI
  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Column(
            children: [
              Icon(icon, color: color),
              const SizedBox(height: 8),
              Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey), textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 15),
      child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildDrawer(BuildContext context, Utente? utente) {
    return Drawer(
      child: ListView(
        children: [
          UserAccountsDrawerHeader(
            accountName: Text("${utente?.nome ?? ''} ${utente?.cognome ?? ''}"),
            accountEmail: Text(utente?.email ?? ''),
            currentAccountPicture: const CircleAvatar(backgroundColor: Colors.white, child: Icon(Icons.person, size: 40)),
          ),
          ListTile(leading: const Icon(Icons.home), title: const Text("Dashboard"), onTap: () {}),
          ListTile(leading: const Icon(Icons.directions_car), title: const Text("Flotta"), onTap: () {}),
          ListTile(leading: const Icon(Icons.history), title: const Text("Storico"), onTap: () {}),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.exit_to_app, color: Colors.red),
            title: const Text("Logout"),
            onTap: () {
              context.read<FleetProvider>().logout();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
          ),
        ],
      ),
    );
  }
}