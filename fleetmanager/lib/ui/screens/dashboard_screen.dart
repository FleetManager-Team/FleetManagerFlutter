import 'package:fleetmanager/models/enums/stato_veicolo.dart';
import 'package:fleetmanager/ui/screens/analisi_costi_screen.dart';
import 'package:fleetmanager/ui/screens/notifiche/notifiche_screen.dart';
import 'package:fleetmanager/ui/screens/prenotazioni/dettaglio_prenotazione_manager.dart';
import 'package:fleetmanager/ui/screens/prenotazioni/lista_prenotazioni_screen.dart';
import 'package:fleetmanager/ui/screens/prenotazioni/restituzione_veicolo_screen.dart';
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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<FleetProvider>();
      if (provider.veicoli.isEmpty) {
        provider.inizializzaDati();
      }
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
                      _buildSectionTitle("Prenotazioni in Sede / Attive"),
                      _buildManagerPrenotazioni(provider, utente),
                    ] else ...[
                      _buildDriverActionCard(context),
                      // Card per la restituzione (solo se c'è una prenotazione attiva)
                      _buildReturnActionCard(context, provider),
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
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: () => provider.inizializzaDati(),
          tooltip: "Aggiorna dati",
        ),
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
        const SizedBox(width: 8),
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

  Widget _buildReturnActionCard(BuildContext context, FleetProvider provider) {
    final utente = provider.utenteLoggato;
    Prenotazione? attiva;

    try {
      attiva = provider.prenotazioni.firstWhere((p) =>
          p.idUtente == utente?.idUtente &&
          p.statoPrenotazione == StatoPrenotazione.attiva);
    } catch (_) {
      attiva = null;
    }

    if (attiva == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 15),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient:
              LinearGradient(colors: [Colors.green[700]!, Colors.green[500]!]),
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.green.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "VEICOLO IN USO",
                  style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1),
                ),
                Text(
                  attiva.targa,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              "Stai terminando il viaggio?",
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 15),
            // Pulsante reso identico a quello della card blu
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => RestituzioneVeicoloScreen(
                      prenotazione: attiva!,
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.green[700]),
              child: const Text("RESTITUISCI VEICOLO"),
            ),
          ],
        ),
      ),
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
            onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const NuovaPrenotazioneScreen())),
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
    final list = provider.prenotazioni
        .where((p) =>
            p.statoPrenotazione == StatoPrenotazione.richiesta ||
            p.statoPrenotazione == StatoPrenotazione.attiva)
        .toList();
    return _buildPrenotazioniList(list, true);
  }

  Widget _buildDriverPrenotazioni(FleetProvider provider) {
    final utente = provider.utenteLoggato;
    // LOGICA DI FILTRAGGIO: Escludiamo le attive perché sono già nel widget verde in alto
    final mie = provider.prenotazioni
        .where((p) =>
                p.idUtente == utente?.idUtente &&
                p.statoPrenotazione != StatoPrenotazione.completata &&
                p.statoPrenotazione != StatoPrenotazione.annullata &&
                p.statoPrenotazione !=
                    StatoPrenotazione
                        .attiva // <--- NASCONDE L'ATTIVA DALL'ELENCO
            )
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
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: prenotazioni.length,
      itemBuilder: (context, index) {
        final p = prenotazioni[index];
        final bool canEditOrCancel = !isManager &&
            (p.statoPrenotazione == StatoPrenotazione.richiesta ||
                p.statoPrenotazione == StatoPrenotazione.confermata);

        final provider = Provider.of<FleetProvider>(context, listen: false);

        final driver = provider.utenti.firstWhere(
          (u) => u.idUtente == p.idUtente,
          orElse: () => Utente(
              idUtente: -1,
              nome: "Utente",
              cognome: "Sconosciuto",
              email: "",
              ruoloUtente: RuoloUtente.driver),
        );

        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 10),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            onTap: isManager
                ? () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            DettaglioPrenotazioneManager(prenotazione: p),
                      ),
                    )
                : null,
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
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                // Mostra Nome e Cognome del Driver
                Row(
                  children: [
                    const Icon(Icons.person, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      "${driver.nome} ${driver.cognome}",
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                          fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  "Dal: ${df.format(p.dataInizio.toLocal())}\nAl: ${df.format(p.dataFine.toLocal())}",
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
            // ---------------------------

            trailing: canEditOrCancel
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                          icon: const Icon(Icons.edit_calendar,
                              color: Colors.blue, size: 22),
                          onPressed: () => _mostraDialogModifica(context, p)),
                      IconButton(
                          icon: const Icon(Icons.cancel_outlined,
                              color: Colors.redAccent, size: 22),
                          onPressed: () =>
                              _mostraDialogAnnullamento(context, p)),
                    ],
                  )
                : (isManager &&
                        p.statoPrenotazione == StatoPrenotazione.richiesta
                    ? const Icon(Icons.arrow_forward_ios, size: 16)
                    : null),
          ),
        );
        ;
      },
    );
  }

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
            child: Column(children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 8),
              Text(value,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              Text(label,
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                  textAlign: TextAlign.center),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Text(title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)));
  }

  Widget _buildDrawer(BuildContext context, Utente? utente) {
    final bool isManager = utente?.ruoloUtente == RuoloUtente.manager;
    return Drawer(
      child: Column(children: [
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
              }),
        ListTile(
            leading: const Icon(Icons.history),
            title: const Text("Storico Prenotazioni"),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const BookingHistoryScreen()));
            }),
        ListTile(
          leading: Icon(Icons.bar_chart_rounded, color: Colors.blue),
          title: Text("Analisi Costi"),
          onTap: () {
            Navigator.push(context,
                MaterialPageRoute(builder: (context) => AnalisiCostiScreen()));
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
            }),
        const SizedBox(height: 20),
      ]),
    );
  }

  // --- LOGICA DIALOG ---
  void _mostraDialogModifica(BuildContext context, Prenotazione p) async {
    DateTime inizio = p.dataInizio;
    DateTime fine = p.dataFine;
    await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (ctx) => StatefulBuilder(
            builder: (context, setModalState) => Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Text("Modifica Orari",
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    _buildDateTimePickerTile(
                        label: "Inizio",
                        dateTime: inizio,
                        onTap: () async {
                          final p = await _selezionaDataEOra(context, inizio);
                          if (p != null) setModalState(() => inizio = p);
                        }),
                    _buildDateTimePickerTile(
                        label: "Fine",
                        dateTime: fine,
                        onTap: () async {
                          final p = await _selezionaDataEOra(context, fine);
                          if (p != null) setModalState(() => fine = p);
                        }),
                    ElevatedButton(
                        onPressed: () async {
                          if (fine.isBefore(inizio)) return;
                          Navigator.pop(ctx);
                          await context
                              .read<FleetProvider>()
                              .modificaPrenotazione(
                                  p.idPrenotazione, inizio, fine);
                        },
                        child: const Text("SALVA")),
                  ]),
                )));
  }

  void _mostraDialogAnnullamento(BuildContext context, Prenotazione p) {
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text("Annulla"),
              content: const Text("Confermi l'annullamento?"),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text("NO")),
                ElevatedButton(
                    onPressed: () async {
                      await context
                          .read<FleetProvider>()
                          .annullaPrenotazione(p.idPrenotazione);
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    child: const Text("SÌ")),
              ],
            ));
  }

  Future<DateTime?> _selezionaDataEOra(
      BuildContext context, DateTime iniziale) async {
    final d = await showDatePicker(
        context: context,
        initialDate: iniziale,
        firstDate: DateTime.now().subtract(const Duration(days: 30)),
        lastDate: DateTime.now().add(const Duration(days: 365)));
    if (d == null || !context.mounted) return null;
    final t = await showTimePicker(
        context: context, initialTime: TimeOfDay.fromDateTime(iniziale));
    if (t == null) return null;
    return DateTime(d.year, d.month, d.day, t.hour, t.minute);
  }

  Widget _buildDateTimePickerTile(
      {required String label,
      required DateTime dateTime,
      required VoidCallback onTap}) {
    return ListTile(
        title: Text(label),
        subtitle: Text(DateFormat('dd/MM/yyyy HH:mm').format(dateTime)),
        trailing: const Icon(Icons.edit),
        onTap: onTap);
  }
}
