import 'package:fleetmanager/models/enums/stato_veicolo.dart';
import 'package:fleetmanager/ui/screens/prenotazioni/lista_prenotazioni_screen.dart';
import 'package:fleetmanager/ui/screens/utenti/lista_utenti_screen.dart';
import 'package:fleetmanager/ui/screens/veicoli/lista_manutenione_screen.dart';
import 'package:fleetmanager/ui/screens/veicoli/lista_veicoli_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fleetmanager/provider/fleet_provider.dart';
import 'package:fleetmanager/models/enums/ruolo_utente.dart';
import 'package:fleetmanager/models/enums/stato_prenotazione.dart';
import 'package:fleetmanager/models/prenotazione.dart';
import 'package:fleetmanager/models/utente.dart';
import 'package:fleetmanager/ui/screens/login_screen.dart';
import 'package:fleetmanager/ui/screens/prenotazioni/nuova_prenotazione_screen.dart';
import 'package:fleetmanager/ui/widgets/details_pop_up.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FleetProvider>().inizializzaDati();
    });
  }

  @override
  Widget build(BuildContext context) {
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
                      _buildSectionTitle("Prenotazioni Attive"),
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
          onPressed: () {},
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

  Widget _buildAdminStats(FleetProvider provider) {
    final veicoliInManutenzione = provider.veicoli
        .where((v) => v.statoVeicolo == StatoVeicolo.inManutenzione)
        .length;

    return Row(
      children: [
        _statCard(
          "Totale Veicoli",
          provider.veicoli.length.toString(),
          Icons.directions_car,
          Colors.blue,
          () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const VehicleListScreen())),
        ),
        _statCard(
          "Prenotazioni",
          provider.prenotazioni.length.toString(),
          Icons.assignment,
          Colors.purple,
          () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const BookingListScreen())),
        ),
        _statCard(
          "In Manutenzione",
          veicoliInManutenzione.toString(),
          Icons.build,
          Colors.orange,
          () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const MaintenanceDashboardScreen())),
        ),
      ],
    );
  }

  Widget _buildDriverActionCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient:
            LinearGradient(colors: [Colors.blue[700]!, Colors.blue[500]!]),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Hai bisogno di un'auto?",
            style: TextStyle(
                color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => NuovaPrenotazioneScreen())),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.blue[700]),
            child: const Text("PRENOTA ORA"),
          ),
        ],
      ),
    );
  }

  Widget _buildManagerPrenotazioni(FleetProvider provider, Utente? utente) {
    if (utente == null) return const SizedBox.shrink();
    final attive = provider.prenotazioni
        .where((p) => p.statoPrenotazione == StatoPrenotazione.attiva)
        .toList();
    return _buildPrenotazioniList(attive, true, provider, utente);
  }

  Widget _buildDriverPrenotazioni(FleetProvider provider) {
    final utente = provider.utenteLoggato;
    final miePrenotazioni = provider.prenotazioni
        .where((p) => p.idUtente == utente?.idUtente)
        .toList();
    return _buildPrenotazioniList(miePrenotazioni, false, provider, utente);
  }

  Widget _buildPrenotazioniList(List<Prenotazione> prenotazioni, bool isManager,
      FleetProvider provider, Utente? utente) {
    if (prenotazioni.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(
            child: Text("Nessuna prenotazione da gestire", // Testo più generico
                style: TextStyle(
                    color: Colors.grey, fontStyle: FontStyle.italic))),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: prenotazioni.length,
      itemBuilder: (context, index) {
        final p = prenotazioni[index];

        final statoColor = p.statoPrenotazione == StatoPrenotazione.attiva
            ? Colors.green[700]!
            : Colors.orange[800]!;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          child: InkWell(
            borderRadius: BorderRadius.circular(15),
            onTap: () => _showBookingDetails(p, provider),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.event_note,
                              color: Colors.blue[900], size: 20),
                          const SizedBox(width: 8),
                          Text("Prenotazione #${p.idPrenotazione}",
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 15)),
                        ],
                      ),
                      _buildStatusTag(p.statoPrenotazione, statoColor),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    children: [
                      _infoMini(Icons.directions_car, p.targa),
                      if (isManager) ...[
                        const SizedBox(width: 20),
                        _infoMini(
                            Icons.person_outline, "User ID: ${p.idUtente}"),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildDateRangeBox(p),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showBookingDetails(Prenotazione p, FleetProvider provider) {
    final utentePrenotazione = provider.utenti.firstWhere(
        (u) => u.idUtente == p.idUtente,
        orElse: () => Utente(
            idUtente: 0,
            nome: "N/D",
            cognome: "",
            email: "",
            ruoloUtente: RuoloUtente.driver));

    showDialog(
      context: context,
      builder: (context) => DetailsPopUp(
        title: "Dettaglio Prenotazione",
        titleIcon: Icons.bookmark_added,
        details: [
          _detailRow(Icons.tag, "ID", "#${p.idPrenotazione}"),
          _detailRow(Icons.directions_car, "Veicolo", p.targa),
          _detailRow(Icons.person, "Conducente",
              "${utentePrenotazione.nome} ${utentePrenotazione.cognome}"),
          _detailRow(Icons.calendar_today, "Inizio",
              DateFormat('dd/MM/yyyy HH:mm').format(p.dataInizio)),
          _detailRow(Icons.calendar_month, "Fine",
              DateFormat('dd/MM/yyyy HH:mm').format(p.dataFine)),
        ],
        extraSectionTitle: "NOTE E STATO",
        extraContent: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Stato attuale: ${p.statoPrenotazione.name.toUpperCase()}",
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.blue[900])),
            const SizedBox(height: 5),
            const Text("Veicolo regolarmente assegnato per scopi aziendali.",
                style: TextStyle(fontSize: 13, color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("CHIUDI")),
        ],
      ),
    );
  }

  Widget _buildStatusTag(StatoPrenotazione stato, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(stato.name.toUpperCase(),
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildDateRangeBox(Prenotazione p) {
    final df = DateFormat('dd/MM HH:mm');
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
          color: Colors.grey[50], borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(df.format(p.dataInizio),
              style: TextStyle(fontSize: 12, color: Colors.grey[800])),
          const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Icon(Icons.arrow_forward, size: 14, color: Colors.grey)),
          Text(df.format(p.dataFine),
              style: TextStyle(fontSize: 12, color: Colors.grey[800])),
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.blueGrey[400]),
          const SizedBox(width: 10),
          Text("$label: ", style: const TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _infoMini(IconData icon, String text) {
    return Row(children: [
      Icon(icon, size: 16, color: Colors.blueGrey[400]),
      const SizedBox(width: 6),
      Text(text,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
    ]);
  }

  Widget _statCard(String label, String value, IconData icon, Color color,
      VoidCallback onTap) {
    return Expanded(
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            child: Column(
              children: [
                Icon(icon, color: color),
                const SizedBox(height: 8),
                Text(value,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold)),
                Text(label,
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                    textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 15),
      child: Text(title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildDrawer(BuildContext context, Utente? utente) {
    final bool isManager = utente?.ruoloUtente == RuoloUtente.manager;
    return Drawer(
      child: ListView(
        children: [
          UserAccountsDrawerHeader(
            accountName: Text("${utente?.nome ?? ''} ${utente?.cognome ?? ''}"),
            accountEmail: Text(utente?.email ?? ''),
            currentAccountPicture: const CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(Icons.person, size: 40)),
          ),
          ListTile(
              leading: const Icon(Icons.home),
              title: const Text("Dashboard"),
              onTap: () => Navigator.pop(context)),
          if (isManager)
            ListTile(
              leading: const Icon(Icons.people),
              title: const Text("Gestione Utenti"),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const UserManagementScreen()));
              },
            ),
          ListTile(
              leading: const Icon(Icons.history),
              title: const Text("Storico"),
              onTap: () => Navigator.pop(context)),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.exit_to_app, color: Colors.red),
            title: const Text("Logout"),
            onTap: () {
              context.read<FleetProvider>().logout();
              Navigator.pushReplacement(context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()));
            },
          ),
        ],
      ),
    );
  }
}
