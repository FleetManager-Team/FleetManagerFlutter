import 'package:fleetmanager/models/enums/stato_veicolo.dart';
import 'package:fleetmanager/models/restituzione.dart';
import 'package:fleetmanager/ui/screens/checkup_iniziale/checkup_screen.dart';
import 'package:fleetmanager/ui/screens/costi/analisi_costi_screen.dart';
import 'package:fleetmanager/ui/screens/emergenze/emergenze_screen.dart';
import 'package:fleetmanager/core/theme/index.dart';
import 'package:fleetmanager/ui/screens/notifiche/notifiche_screen.dart';
import 'package:fleetmanager/ui/screens/prenotazioni/dettaglio_prenotazione_manager.dart';
import 'package:fleetmanager/ui/screens/prenotazioni/lista_prenotazioni_screen.dart';
import 'package:fleetmanager/ui/screens/restituzioni/restituzione_veicolo_screen.dart';
import 'package:fleetmanager/ui/screens/prenotazioni/storico_prenotazioni_screen.dart';
import 'package:fleetmanager/ui/screens/utenti/lista_utenti_screen.dart';
import 'package:fleetmanager/ui/screens/veicoli/lista_manutenione_screen.dart';
import 'package:fleetmanager/ui/screens/veicoli/lista_veicoli_screen.dart';
import 'package:fleetmanager/ui/screens/impostazioni/impostazioni_manager_screen.dart';
import 'package:fleetmanager/ui/screens/scadenze/lista_scadenze_screen.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:fleetmanager/provider/fleet_provider.dart';
import 'package:fleetmanager/provider/impostazioni_provider.dart';
import 'package:fleetmanager/models/enums/ruolo_utente.dart';
import 'package:fleetmanager/models/enums/stato_prenotazione.dart';
import 'package:fleetmanager/models/prenotazione.dart';
import 'package:fleetmanager/models/utente.dart';
import 'package:fleetmanager/ui/screens/login_screen.dart';
import 'package:fleetmanager/ui/screens/prenotazioni/nuova_prenotazione_screen.dart';
import 'package:fleetmanager/ui/widgets/form_pop_up.dart';
import 'package:url_launcher/url_launcher.dart';

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

    final emergenzeInCorso = provider.prenotazioni.where((p) {
      return provider.emergenzeAttive
          .any((r) => r.idPrenotazione == p.idPrenotazione);
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.grey100,
      appBar: _buildAppBar(context, utente),
      drawer: _buildDrawer(context, utente),
      body: Builder(
        builder: (context) {
          final provider = context.watch<FleetProvider>();
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          return RefreshIndicator(
            onRefresh: () => provider.inizializzaDati(),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(utente),
                  if (emergenzeInCorso.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    ...emergenzeInCorso.map((p) {
                      final sos = provider.restituzioni.firstWhere(
                          (r) => r.idPrenotazione == p.idPrenotazione);
                      return _buildEmergencyCard(
                        prenotazione: p,
                        isManager: isManager,
                        onTap: () {
                          if (isManager) {
                            _mostraDettaglioSosManager(context, p, sos);
                          } else {
                            _vaiACompletamentoDriver(context, p);
                          }
                        },
                      );
                    }),
                  ],
                  const SizedBox(height: 25),
                  if (isManager) ...[
                    _buildAdminStats(provider),
                    const SizedBox(height: 25),
                    _buildSectionTitle("Prenotazioni in Sede / Attive"),
                    _buildManagerPrenotazioni(provider, utente),
                  ] else ...[
                    if (emergenzeInCorso.isEmpty) ...[
                      _buildDriverActionCard(context),
                      _buildCheckinActionCard(context, provider),
                      _buildReturnActionCard(context, provider),
                      const SizedBox(height: 25),
                    ],
                    _buildSectionTitle("Le Mie Prenotazioni"),
                    _buildDriverPrenotazioni(provider),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // --- COMPONENTI DELLA UI ---

  AppBar _buildAppBar(BuildContext context, Utente? utente) {
    // FIX: context.read invece di context.watch per evitare loop di rebuild
    final provider = context.read<FleetProvider>();
    final notificheNonLette = provider.notifiche.where((n) => !n.letta).length;

    return AppBar(
      elevation: 0,
      backgroundColor: AppColors.primaryDark,
      foregroundColor: AppColors.white,
      title: const Text(
        "FleetManager",
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
                    color: AppColors.error,
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radiusDefault),
                  ),
                  constraints:
                      const BoxConstraints(minWidth: 16, minHeight: 16),
                  child: Text(
                    '$notificheNonLette',
                    style: const TextStyle(
                        color: AppColors.white,
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
        const Text("Bentornato,",
            style: TextStyle(fontSize: 16, color: AppColors.grey600)),
        Text(
          "${utente?.nome ?? ''} ${utente?.cognome ?? ''}",
          style: AppTextStyles.displayMedium,
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
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [AppColors.success, AppColors.success]),
          borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
          boxShadow: [
            BoxShadow(
              color: Colors.green..withValues(alpha: 0.2),
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
                Text(
                  "VEICOLO IN USO",
                  style: TextStyle(
                      color: AppColors.white..withValues(alpha: 0.7),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1),
                ),
                Text(
                  attiva.targa,
                  style: const TextStyle(
                      color: AppColors.white, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              "Stai terminando il viaggio?",
              style: TextStyle(
                  color: AppColors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 15),
            // FIX: Expanded sul bottone principale per vincolare la larghezza
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: ElevatedButton(
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
                    style: AppButtonStyles.elevated(
                      color: AppColors.white,
                      foregroundColor: AppColors.success,
                    ),
                    child: const Text("RESTITUISCI VEICOLO"),
                  ),
                ),
                const SizedBox(width: 12),
                // Bottone circolare SOS — dimensione fissa, non ha bisogno di Expanded
                SizedBox(
                  width: 60,
                  height: 60,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => RestituzioneVeicoloScreen(
                            prenotazione: attiva!,
                            isEmergenza: true,
                          ),
                        ),
                      );
                    },
                    style: AppButtonStyles.elevated(
                      color: AppColors.error,
                    ).copyWith(
                      shape: const WidgetStatePropertyAll(CircleBorder()),
                      padding: const WidgetStatePropertyAll(EdgeInsets.zero),
                    ),
                    child: const Icon(
                      Icons.warning_amber_rounded,
                      size: 28,
                    ),
                  ),
                ),
              ],
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
            AppColors.primary,
            () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const VehicleListScreen()))),
        _statCard(
          "Prenotazioni",
          provider.prenotazioni
              .where((p) =>
                  p.statoPrenotazione != StatoPrenotazione.completata &&
                  p.statoPrenotazione != StatoPrenotazione.annullata)
              .length
              .toString(),
          Icons.assignment,
          AppColors.info,
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const BookingListScreen()),
          ),
        ),
        _statCard(
            "Officina",
            inManutenzione.toString(),
            Icons.build,
            AppColors.secondary,
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
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        gradient:
            LinearGradient(colors: [AppColors.primaryDark, Colors.blue[500]!]),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Hai bisogno di un'auto?",
              style: TextStyle(
                  color: AppColors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          // FIX: larghezza fissa invece di lasciarlo libero in una Column
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const NuovaPrenotazioneScreen())),
              style: AppButtonStyles.elevated(
                color: AppColors.white,
                foregroundColor: AppColors.primaryDark,
              ),
              child: const Text("NUOVA PRENOTAZIONE"),
            ),
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
            p.statoPrenotazione == StatoPrenotazione.attiva ||
            p.statoPrenotazione == StatoPrenotazione.confermata ||
            p.statoPrenotazione == StatoPrenotazione.attesaCheckup ||
            p.statoPrenotazione == StatoPrenotazione.sospesa)
        .toList();
    return _buildPrenotazioniList(list, true, provider);
  }

  Widget _buildDriverPrenotazioni(FleetProvider provider) {
    final utente = provider.utenteLoggato;
    final mie = provider.prenotazioni
        .where((p) =>
            p.idUtente == utente?.idUtente &&
            p.statoPrenotazione != StatoPrenotazione.completata &&
            p.statoPrenotazione != StatoPrenotazione.annullata &&
            p.statoPrenotazione != StatoPrenotazione.attiva)
        .toList();
    return _buildPrenotazioniList(mie, false, provider);
  }

  Widget _buildPrenotazioniList(
      List<Prenotazione> prenotazioni, bool isManager, FleetProvider provider) {
    if (prenotazioni.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Text("Nessuna attività recente.",
            style: TextStyle(
                color: AppColors.grey500, fontStyle: FontStyle.italic)),
      );
    }

    final df = DateFormat('dd/MM HH:mm');
    // FIX: rimossa la riga "final provider = Provider.of<FleetProvider>..."
    // che ridichiarava il parametro causando conflitti

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: prenotazioni.length,
      itemBuilder: (context, index) {
        final p = prenotazioni[index];

        final bool haConflitto = prenotazioni.any((altra) =>
            altra.idPrenotazione != p.idPrenotazione &&
            altra.targa == p.targa &&
            altra.statoPrenotazione != StatoPrenotazione.annullata &&
            altra.statoPrenotazione != StatoPrenotazione.completata &&
            p.dataInizio.isBefore(altra.dataFine) &&
            p.dataFine.isAfter(altra.dataInizio));

        final bool canEditOrCancel = !isManager &&
            (p.statoPrenotazione == StatoPrenotazione.richiesta ||
                p.statoPrenotazione == StatoPrenotazione.confermata ||
                p.statoPrenotazione == StatoPrenotazione.attesaCheckup);

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
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusDefault)),
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
              backgroundColor: _getStatusColor(p, provider)
                ..withValues(alpha: 0.1),
              child: Icon(Icons.calendar_today,
                  color: _getStatusColor(p, provider), size: 20),
            ),
            // FIX: Row con Flexible invece di Wrap per evitare crash su Flutter Web
            title: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    "${p.targa} - ${_getStatusText(p, provider)}",
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (haConflitto &&
                    p.statoPrenotazione == StatoPrenotazione.richiesta) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      // FIX: colore con opacità per rendere il testo leggibile
                      color: AppColors.secondary..withValues(alpha: 0.15),
                      border: Border.all(color: AppColors.secondary, width: 1),
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusDefault),
                    ),
                    child: const Text(
                      "SOVRAPPOSIZIONE",
                      style: TextStyle(
                        color: AppColors.secondary,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
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
            trailing: isManager
                ? const Icon(Icons.arrow_forward_ios,
                    size: 16, color: Colors.grey)
                : (canEditOrCancel
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                              icon: const Icon(Icons.edit_calendar,
                                  color: AppColors.primary, size: 22),
                              onPressed: () =>
                                  _mostraDialogModifica(context, p)),
                          IconButton(
                              icon: const Icon(Icons.cancel_outlined,
                                  color: Colors.redAccent, size: 22),
                              onPressed: () =>
                                  _mostraDialogAnnullamento(context, p)),
                        ],
                      )
                    : const Icon(Icons.arrow_forward_ios,
                        size: 16, color: Colors.transparent)),
          ),
        );
      },
    );
  }

  String _getStatusText(Prenotazione p, FleetProvider provider) {
    if (p.statoPrenotazione == StatoPrenotazione.attiva) {
      final hasRestituzione = provider.restituzioni
          .any((r) => r.idPrenotazione == p.idPrenotazione);
      final isScaduta = DateTime.now().isAfter(p.dataFine);
      if (!hasRestituzione && isScaduta) {
        return "IN ATTESA DI REPORT RIENTRO";
      }
    }
    return p.statoPrenotazione.name.toUpperCase();
  }

  Color _getStatusColor(Prenotazione p, FleetProvider provider) {
    if (p.statoPrenotazione == StatoPrenotazione.attiva) {
      final hasRestituzione = provider.restituzioni
          .any((r) => r.idPrenotazione == p.idPrenotazione);
      final isScaduta = DateTime.now().isAfter(p.dataFine);
      if (!hasRestituzione && isScaduta) {
        return Colors.orange;
      }
      return Colors.green;
    }
    switch (p.statoPrenotazione) {
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
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusDefault)),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSpacing.radiusDefault),
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
        child: Text(title, style: AppTextStyles.headlineMedium));
  }

  Widget _buildDrawer(BuildContext context, Utente? utente) {
    final bool isManager = utente?.ruoloUtente == RuoloUtente.manager;
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(color: AppColors.primaryDark),
              accountName:
                  Text("${utente?.nome ?? ''} ${utente?.cognome ?? ''}"),
              accountEmail: Text(utente?.email ?? ''),
              currentAccountPicture: const CircleAvatar(
                  backgroundColor: AppColors.white,
                  child: Icon(Icons.person, size: 40)),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    ListTile(
                        leading:
                            const Icon(Icons.home, color: AppColors.primary),
                        title: const Text("Dashboard"),
                        onTap: () => Navigator.pop(context)),
                    if (isManager)
                      ListTile(
                          leading: const Icon(Icons.people,
                              color: AppColors.success),
                          title: const Text("Gestione Utenti"),
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const UserManagementScreen()));
                          }),
                    ListTile(
                        leading: const Icon(Icons.history, color: Colors.brown),
                        title: const Text("Storico Prenotazioni"),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      const BookingHistoryScreen()));
                        }),
                    if (isManager)
                      ListTile(
                        leading: const Icon(Icons.bar_chart_rounded,
                            color: AppColors.secondary),
                        title: const Text("Analisi Costi"),
                        onTap: () {
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) =>
                                      const AnalisiCostiScreen()));
                        },
                      ),
                    if (isManager)
                      ListTile(
                        leading: const Icon(Icons.warning_amber_rounded,
                            color: AppColors.error),
                        title: const Text("Emergenze"),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) =>
                                      const EmergenzeScreen()));
                        },
                      ),
                    if (isManager)
                      ListTile(
                          leading: const Icon(Icons.calendar_month_outlined,
                              color: AppColors.warning),
                          title: const Text("Scadenze"),
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) =>
                                        const ListaScadenzeScreen()));
                          }),
                    if (isManager)
                      ListTile(
                          leading: const Icon(Icons.settings_outlined,
                              color: AppColors.grey600),
                          title: const Text("Impostazioni Azienda"),
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) =>
                                        const ImpostazioniManagerScreen()));
                          }),
                  ],
                ),
              ),
            ),
            const Divider(),
            ListTile(
                leading: const Icon(Icons.exit_to_app, color: AppColors.error),
                title: const Text("Logout"),
                onTap: () {
                  context.read<FleetProvider>().logout();
                  Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (route) => false);
                }),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // --- LOGICA DIALOG ---
  void _mostraDialogModifica(BuildContext context, Prenotazione p) async {
    DateTime inizio = p.dataInizio.toLocal();
    DateTime fine = p.dataFine.toLocal();

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setModalState) => FormPopUp(
          title: "Modifica Orari",
          titleIcon: Icons.event_available,
          sectionTitle: "Periodo prenotazione",
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("ANNULLA"),
            ),
            ElevatedButton(
              onPressed: () async {
                if (fine.isBefore(inizio)) return;
                Navigator.pop(dialogContext);
                await context
                    .read<FleetProvider>()
                    .modificaPrenotazione(p.idPrenotazione, inizio, fine);
              },
              child: const Text("SALVA"),
            ),
          ],
        ),
      ),
    );
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
      context: context,
      initialTime: TimeOfDay.fromDateTime(iniziale.toLocal()));
    if (t == null) return null;
    return DateTime(d.year, d.month, d.day, t.hour, t.minute);
  }

  Widget _buildDateTimePickerTile(
      {required String label,
      required DateTime dateTime,
      required VoidCallback onTap}) {
    return ListTile(
        title: Text(label),
        subtitle: Text(DateFormat('dd/MM/yyyy HH:mm').format(dateTime.toLocal())),
        trailing: const Icon(Icons.edit),
        onTap: onTap);
  }

  Widget _buildCheckinActionCard(BuildContext context, FleetProvider provider) {
    final imp = context.watch<ImpostazioniProvider>();
    final utente = provider.utenteLoggato;
    Prenotazione? daRitirare;

    try {
      daRitirare = provider.prenotazioni.firstWhere((p) =>
          p.idUtente == utente?.idUtente &&
          (p.statoPrenotazione == StatoPrenotazione.attesaCheckup ||
              p.statoPrenotazione == StatoPrenotazione.confermata));
    } catch (_) {
      daRitirare = null;
    }

    if (daRitirare == null) return const SizedBox.shrink();
    if (!imp.caricato) return const SizedBox.shrink();

    final DateTime oraInizioUtc = daRitirare.dataInizio.toUtc();
    final DateTime oraAttualeUtc = DateTime.now().toUtc();
    final minutiAllaPartenza = oraInizioUtc.difference(oraAttualeUtc).inMinutes;
    if (minutiAllaPartenza > 30) {
      return const SizedBox.shrink();
    }

    final bool richiedeCheckup = imp.checkupObbligatorio &&
        daRitirare.statoPrenotazione == StatoPrenotazione.attesaCheckup;

    return Padding(
      padding: const EdgeInsets.only(top: 15),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [AppColors.secondary, AppColors.secondaryLight]),
          borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
          boxShadow: [
            BoxShadow(
              color: AppColors.secondary..withValues(alpha: 0.2),
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
                Text(
                  "PRENOTAZIONE PRONTA",
                  style: TextStyle(
                      color: AppColors.white..withValues(alpha: 0.7),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1),
                ),
                Text(
                  daRitirare.targa,
                  style: const TextStyle(
                      color: AppColors.white, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              "Ritira il veicolo adesso",
              style: TextStyle(
                  color: AppColors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold),
            ),
            Text(
              richiedeCheckup
                  ? "Esegui il controllo perimetrale per partire"
                  : "Il checkup non è richiesto dalla tua azienda",
              style: TextStyle(
                  color: AppColors.white..withValues(alpha: 0.7), fontSize: 13),
            ),
            const SizedBox(height: 15),
            SizedBox(
              width: double.infinity,
              child: richiedeCheckup
                  ? ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CheckingVeicoloScreen(
                              idPrenotazione: daRitirare!.idPrenotazione,
                              targa: daRitirare.targa,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.camera_enhance),
                      style: AppButtonStyles.elevated(
                        color: AppColors.white,
                        foregroundColor: AppColors.secondary,
                      ),
                      label: const Text("INIZIA ISPEZIONE E PARTI"),
                    )
                  : ElevatedButton.icon(
                      onPressed: () async {
                        await imp.ensureLoaded();
                        await provider.attivaPrenotazioneSenzaCheckup(
                            daRitirare!.idPrenotazione);
                      },
                      icon: const Icon(Icons.directions_car),
                      style: AppButtonStyles.elevated(
                        color: AppColors.white,
                        foregroundColor: AppColors.secondary,
                      ),
                      label: const Text("PARTI SUBITO"),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _apriMappaEsterna(String? posizione) async {
    if (posizione == null || posizione.isEmpty) return;

    final query = Uri.encodeComponent(posizione);
    final googleMapsUrl =
        "https://www.google.com/maps/search/?api=1&query=$query";
    final appleMapsUrl = "https://maps.apple.com/?q=$query";

    try {
      if (await canLaunchUrl(Uri.parse(googleMapsUrl))) {
        await launchUrl(Uri.parse(googleMapsUrl),
            mode: LaunchMode.externalApplication);
      } else if (await canLaunchUrl(Uri.parse(appleMapsUrl))) {
        await launchUrl(Uri.parse(appleMapsUrl),
            mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint("Impossibile aprire la mappa: $e");
    }
  }

  Widget _buildManagerSosDetail(Map<String, dynamic> datiSos) {
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.location_on, color: AppColors.error),
          title: const Text("Posizione segnalata"),
          subtitle: Text(datiSos['posizione_emergenza'] ?? "N/D"),
          trailing: IconButton(
            icon: const Icon(Icons.map_outlined),
            onPressed: () => _apriMappaEsterna(datiSos['posizione_emergenza']),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          color: AppColors.white,
          child: Row(
            children: [
              const Icon(Icons.build_circle, color: AppColors.secondary),
              const SizedBox(width: 10),
              Expanded(
                  child: Text("Problema: ${datiSos['descrizione_danni']}")),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmergencyCard({
    required Prenotazione prenotazione,
    required bool isManager,
    required VoidCallback onTap,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.error, AppColors.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
        boxShadow: [
          BoxShadow(
            color: Colors.red..withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded,
                  color: AppColors.white, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isManager
                      ? "EMERGENZA: ${prenotazione.targa}"
                      : "SEGNALAZIONE SOS ATTIVA",
                  style: const TextStyle(
                      color: AppColors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            isManager
                ? "Un driver ha segnalato un guasto o incidente. Verifica subito la posizione."
                : "Hai segnalato un'emergenza per il veicolo ${prenotazione.targa}. Completa i dati appena possibile.",
            style: TextStyle(
              color: AppColors.white.withValues(alpha: 0.7),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 15),
          // FIX: SizedBox per vincolare la larghezza del bottone nell'emergency card
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onTap,
              style: AppButtonStyles.elevated(
                color: AppColors.white,
                foregroundColor: AppColors.error,
              ),
              child: Text(
                  isManager ? "VEDI DETTAGLI E MAPPA" : "COMPLETA PROCEDURA"),
            ),
          ),
        ],
      ),
    );
  }

  void _vaiACompletamentoDriver(BuildContext context, Prenotazione p) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RestituzioneVeicoloScreen(
          prenotazione: p,
        ),
      ),
    );
  }

  void _mostraDettaglioSosManager(
      BuildContext context, Prenotazione p, Restituzione sos) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Dettaglio Emergenza",
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.error),
            ),
            const Divider(height: 30),
            _buildManagerSosDetail({
              'posizione_emergenza': sos.posizioneEmergenza,
              'descrizione_danni': sos.descrizioneDanni,
            }),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Chiudi"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
