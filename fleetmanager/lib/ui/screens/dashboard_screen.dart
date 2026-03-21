import 'package:fleetmanager/models/enums/stato_veicolo.dart';
import 'package:fleetmanager/ui/screens/prenotazioni/lista_prenotazioni_screen.dart';
import 'package:fleetmanager/ui/screens/prenotazioni/storico_prenotazioni_screen.dart';
import 'package:fleetmanager/ui/screens/utenti/lista_utenti_screen.dart';
import 'package:fleetmanager/ui/screens/veicoli/lista_manutenione_screen.dart';
import 'package:fleetmanager/ui/screens/veicoli/lista_veicoli_screen.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:fleetmanager/provider/fleet_provider.dart';
import 'package:fleetmanager/models/enums/ruolo_utente.dart';
import 'package:fleetmanager/models/enums/stato_prenotazione.dart';
import 'package:fleetmanager/models/prenotazione.dart';
import 'package:fleetmanager/models/utente.dart';
import 'package:fleetmanager/ui/screens/login_screen.dart';
import 'package:fleetmanager/ui/screens/prenotazioni/nuova_prenotazione_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // RIMOSSO: _prenotazioniFuture (non serve più con il caricamento centralizzato)

  @override
  void initState() {
    super.initState();
    // Non carichiamo qui perché lo abbiamo fatto nel login, 
    // ma lasciamo il check di sicurezza se per caso i dati fossero vuoti
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<FleetProvider>();
      if (provider.veicoli.isEmpty) {
        provider.inizializzaDati();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // watch permette alla UI di reagire istantaneamente quando i dati su Supabase cambiano
    final provider = context.watch<FleetProvider>();
    final utente = provider.utenteLoggato;
    final bool isManager = utente?.ruoloUtente == RuoloUtente.manager;

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
                    if (isManager) ...[
                      _buildAdminStats(provider),
                      const SizedBox(height: 25),
                      _buildSectionTitle("Prenotazioni in Sede / Attive"),
                      _buildManagerPrenotazioni(provider, utente),
                    ] else ...[
                      _buildDriverActionCard(context),
                      const SizedBox(height: 25),
                      _buildSectionTitle("Le Mie Prenotazioni"),
                      _buildDriverPrenotazioni(provider),
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
      title: const Text(
        "FleetManager Pro",
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.notifications_none),
          onPressed: () { /* Future: Notifiche */ },
        ),
      ],
    );
  }

  Widget _buildHeader(Utente? utente) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Bentornato,", style: TextStyle(fontSize: 16, color: Colors.grey[600])),
        Text(
          "${utente?.nome ?? ''} ${utente?.cognome ?? ''}",
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildAdminStats(FleetProvider provider) {
    final inManutenzione = provider.veicoli.where((v) => v.statoVeicolo == StatoVeicolo.inManutenzione).length;

    return Row(
      children: [
        _statCard("Auto", provider.veicoli.length.toString(), Icons.directions_car, Colors.blue, 
          () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VehicleListScreen()))),
        _statCard("Prenotazioni", provider.prenotazioni.length.toString(), Icons.assignment, Colors.purple, 
          () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BookingListScreen()))),
        _statCard("Officina", inManutenzione.toString(), Icons.build, Colors.orange, 
          () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MaintenanceDashboardScreen()))),
      ],
    );
  }

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
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => NuovaPrenotazioneScreen())),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.blue[700]),
            child: const Text("NUOVA PRENOTAZIONE"),
          ),
        ],
      ),
    );
  }

  Widget _buildManagerPrenotazioni(FleetProvider provider, Utente? utente) {
    if (utente == null) return const SizedBox.shrink();
    // Il manager vede le prenotazioni che richiedono attenzione (Richieste o Attive)
    final attive = provider.prenotazioni.where((p) => 
      p.statoPrenotazione == StatoPrenotazione.richiesta || 
      p.statoPrenotazione == StatoPrenotazione.attiva).toList();

    return _buildPrenotazioniList(attive, true);
  }

  Widget _buildDriverPrenotazioni(FleetProvider provider) {
    final utente = provider.utenteLoggato;
    // Il driver vede solo le sue prenotazioni non ancora concluse
    final mie = provider.prenotazioni.where((p) => 
      p.idUtente == utente?.idUtente && 
      p.statoPrenotazione != StatoPrenotazione.completata && 
      p.statoPrenotazione != StatoPrenotazione.annullata).toList();

    return _buildPrenotazioniList(mie, false);
  }

  Widget _buildPrenotazioniList(List<Prenotazione> prenotazioni, bool isManager) {
    if (prenotazioni.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Text("Nessuna attività recente.", style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
      );
    }

    final df = DateFormat('dd/MM HH:mm');

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: prenotazioni.length,
      itemBuilder: (context, index) {
        final p = prenotazioni[index];
        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: _getStatusColor(p.statoPrenotazione).withOpacity(0.1),
              child: Icon(Icons.calendar_today, color: _getStatusColor(p.statoPrenotazione), size: 20),
            ),
            title: Text("${p.targa} - ${p.statoPrenotazione.name.toUpperCase()}", 
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            subtitle: Text("Dal: ${df.format(p.dataInizio)}\nAl: ${df.format(p.dataFine)}", 
              style: const TextStyle(fontSize: 12)),
            trailing: isManager && p.statoPrenotazione == StatoPrenotazione.richiesta
                ? IconButton(
                    icon: const Icon(Icons.arrow_forward_ios, size: 16),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BookingListScreen())),
                  )
                : null,
          ),
        );
      },
    );
  }

  // Helper per colori stati
  Color _getStatusColor(StatoPrenotazione stato) {
    switch (stato) {
      case StatoPrenotazione.richiesta: return Colors.orange;
      case StatoPrenotazione.confermata: return Colors.blue;
      case StatoPrenotazione.attiva: return Colors.green;
      default: return Colors.grey;
    }
  }

  Widget _statCard(String label, String value, IconData icon, Color color, VoidCallback onTap) {
    return Expanded(
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(height: 8),
                Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey), textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildDrawer(BuildContext context, Utente? utente) {
    final bool isManager = utente?.ruoloUtente == RuoloUtente.manager;
    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(color: Colors.blue[800]),
            accountName: Text("${utente?.nome ?? ''} ${utente?.cognome ?? ''}"),
            accountEmail: Text(utente?.email ?? ''),
            currentAccountPicture: const CircleAvatar(backgroundColor: Colors.white, child: Icon(Icons.person, size: 40)),
          ),
          ListTile(
            leading: const Icon(Icons.home),
            title: const Text("Dashboard"),
            onTap: () => Navigator.pop(context),
          ),
          if (isManager)
            ListTile(
              leading: const Icon(Icons.people),
              title: const Text("Gestione Utenti"),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const UserManagementScreen()));
              },
            ),
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text("Storico Prenotazioni"),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const BookingHistoryScreen()));
            },
          ),
          const Spacer(),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.exit_to_app, color: Colors.red),
            title: const Text("Logout"),
            onTap: () {
              context.read<FleetProvider>().logout();
              Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false);
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}