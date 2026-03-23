import 'package:fleetmanager/models/enums/stato_veicolo.dart';
import 'package:fleetmanager/ui/screens/notifiche/notifiche_screen.dart';
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
    final provider = context.watch<FleetProvider>();
    final notificheNonLette = provider.notifiche.where((n) => !n.letta).length;

    return AppBar(
      elevation: 0,
      backgroundColor: Colors.blue[800],
      foregroundColor: Colors.white,
      title: const Text(
        "FleetManager Pro",
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      actions: [
        Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_none),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const NotificheScreen()),
                );
              },
            ),
            if (notificheNonLette > 0)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  constraints:
                      const BoxConstraints(minWidth: 16, minHeight: 16),
                  child: Text(
                    '$notificheNonLette',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildHeader(Utente? utente) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Bentornato,",
            style: TextStyle(fontSize: 16, color: Colors.grey[600])),
        Text(
          "${utente?.nome ?? ''} ${utente?.cognome ?? ''}",
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildAdminStats(FleetProvider provider) {
    final inManutenzione = provider.veicoli
        .where((v) => v.statoVeicolo == StatoVeicolo.inManutenzione)
        .length;

    return Row(
      children: [
        _statCard(
            "Auto",
            provider.veicoli.length.toString(),
            Icons.directions_car,
            Colors.blue,
            () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const VehicleListScreen()))),
        _statCard(
            "Prenotazioni",
            provider.prenotazioni.length.toString(),
            Icons.assignment,
            Colors.purple,
            () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const BookingListScreen()))),
        _statCard(
            "Officina",
            inManutenzione.toString(),
            Icons.build,
            Colors.orange,
            () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const MaintenanceDashboardScreen()))),
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
          const Text("Hai bisogno di un'auto?",
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => NuovaPrenotazioneScreen())),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.blue[700]),
            child: const Text("NUOVA PRENOTAZIONE"),
          ),
        ],
      ),
    );
  }

  Widget _buildManagerPrenotazioni(FleetProvider provider, Utente? utente) {
    if (utente == null) return const SizedBox.shrink();
    // Il manager vede le prenotazioni che richiedono attenzione (Richieste o Attive)
    final attive = provider.prenotazioni
        .where((p) =>
            p.statoPrenotazione == StatoPrenotazione.richiesta ||
            p.statoPrenotazione == StatoPrenotazione.attiva)
        .toList();

    return _buildPrenotazioniList(attive, true);
  }

  Widget _buildDriverPrenotazioni(FleetProvider provider) {
    final utente = provider.utenteLoggato;
    // Il driver vede solo le sue prenotazioni non ancora concluse
    final mie = provider.prenotazioni
        .where((p) =>
            p.idUtente == utente?.idUtente &&
            p.statoPrenotazione != StatoPrenotazione.completata &&
            p.statoPrenotazione != StatoPrenotazione.annullata)
        .toList();

    return _buildPrenotazioniList(mie, false);
  }

  Widget _buildPrenotazioniList(
      List<Prenotazione> prenotazioni, bool isManager) {
    if (prenotazioni.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Text("Nessuna attività recente.",
            style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
      );
    }

    final df = DateFormat('dd/MM HH:mm');
    final provider = context.read<FleetProvider>();

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: prenotazioni.length,
      itemBuilder: (context, index) {
        final p = prenotazioni[index];

        // Definiamo se il driver può agire (solo su richieste o confermate future)
        final bool canEditOrCancel = !isManager &&
            (p.statoPrenotazione == StatoPrenotazione.richiesta ||
                p.statoPrenotazione == StatoPrenotazione.confermata);

        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 10),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor:
                  _getStatusColor(p.statoPrenotazione).withOpacity(0.1),
              child: Icon(Icons.calendar_today,
                  color: _getStatusColor(p.statoPrenotazione), size: 20),
            ),
            title: Text(
                "${p.targa} - ${p.statoPrenotazione.name.toUpperCase()}",
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            subtitle: Text(
                "Dal: ${df.format(p.dataInizio)}\nAl: ${df.format(p.dataFine)}",
                style: const TextStyle(fontSize: 12)),

            // NUOVO TRAILING DINAMICO
            trailing: canEditOrCancel
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Tasto Modifica
                      IconButton(
                        icon: const Icon(Icons.edit_calendar,
                            color: Colors.blue, size: 22),
                        onPressed: () => _mostraDialogModifica(context, p),
                      ),
                      // Tasto Annulla
                      IconButton(
                        icon: const Icon(Icons.cancel_outlined,
                            color: Colors.redAccent, size: 22),
                        onPressed: () => _mostraDialogAnnullamento(context, p),
                      ),
                    ],
                  )
                : (isManager &&
                        p.statoPrenotazione == StatoPrenotazione.richiesta
                    ? IconButton(
                        icon: const Icon(Icons.arrow_forward_ios, size: 16),
                        onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const BookingListScreen())),
                      )
                    : null),
          ),
        );
      },
    );
  }

  // Helper per colori stati
  Color _getStatusColor(StatoPrenotazione stato) {
    switch (stato) {
      case StatoPrenotazione.richiesta:
        return Colors.orange;
      case StatoPrenotazione.confermata:
        return Colors.blue;
      case StatoPrenotazione.attiva:
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Widget _statCard(String label, String value, IconData icon, Color color,
      VoidCallback onTap) {
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
                Text(value,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
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
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Text(title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
            currentAccountPicture: const CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(Icons.person, size: 40)),
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
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const UserManagementScreen()));
              },
            ),
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text("Storico Prenotazioni"),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const BookingHistoryScreen()));
            },
          ),
          const Spacer(),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.exit_to_app, color: Colors.red),
            title: const Text("Logout"),
            onTap: () {
              context.read<FleetProvider>().logout();
              Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false);
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  void _mostraDialogModifica(BuildContext context, Prenotazione p) async {
    DateTime nuovaDataInizio = p.dataInizio;
    DateTime nuovaDataFine = p.dataFine;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          // Necessario per aggiornare la UI dentro il BottomSheet
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("Modifica Orari Prenotazione",
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),

                  // SELETTORE INIZIO
                  _buildDateTimePickerTile(
                    label: "Inizio",
                    dateTime: nuovaDataInizio,
                    onTap: () async {
                      final picked =
                          await _selezionaDataEOra(context, nuovaDataInizio);
                      if (picked != null)
                        setModalState(() => nuovaDataInizio = picked);
                    },
                  ),

                  const Divider(),

                  // SELETTORE FINE
                  _buildDateTimePickerTile(
                    label: "Fine",
                    dateTime: nuovaDataFine,
                    onTap: () async {
                      final picked =
                          await _selezionaDataEOra(context, nuovaDataFine);
                      if (picked != null)
                        setModalState(() => nuovaDataFine = picked);
                    },
                  ),

                  const SizedBox(height: 30),

                  // BOTTONE SALVA
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[800],
                        padding: const EdgeInsets.symmetric(vertical: 15),
                      ),
                      onPressed: () async {
                        if (nuovaDataFine.isBefore(nuovaDataInizio)) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text(
                                    "La fine non può essere prima dell'inizio")),
                          );
                          return;
                        }

                        Navigator.pop(ctx); // Chiude il BottomSheet

                        try {
                          await context
                              .read<FleetProvider>()
                              .modificaPrenotazione(p.idPrenotazione,
                                  nuovaDataInizio, nuovaDataFine);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content:
                                      Text("Modifica salvata con successo!")),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text(e.toString()),
                                  backgroundColor: Colors.red),
                            );
                          }
                        }
                      },
                      child: const Text("SALVA MODIFICHE",
                          style: TextStyle(color: Colors.white)),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            );
          },
        );
      },
    );
  }

// Funzione Helper per mostrare DataPicker e poi TimePicker in sequenza
  Future<DateTime?> _selezionaDataEOra(
      BuildContext context, DateTime iniziale) async {
    final date = await showDatePicker(
      context: context,
      initialDate: iniziale,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (date == null) return null;

    if (!context.mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(iniziale),
    );

    if (time == null) return null;

    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

// Widget grafico per la riga del selettore
  Widget _buildDateTimePickerTile(
      {required String label,
      required DateTime dateTime,
      required VoidCallback onTap}) {
    return ListTile(
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(DateFormat('dd/MM/yyyy HH:mm').format(dateTime)),
      trailing: const Icon(Icons.edit_calendar, color: Colors.blue),
      onTap: onTap,
    );
  }

  void _mostraDialogAnnullamento(BuildContext context, Prenotazione p) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Annulla Prenotazione"),
        content: Text("Vuoi davvero annullare la prenotazione per ${p.targa}?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text("NO")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await context
                  .read<FleetProvider>()
                  .annullaPrenotazione(p.idPrenotazione);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text("SÌ, ANNULLA",
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
