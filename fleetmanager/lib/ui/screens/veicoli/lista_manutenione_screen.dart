import 'package:fleetmanager/models/enums/ruolo_utente.dart';
import 'package:fleetmanager/models/enums/tipo_manutenzione.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:fleetmanager/core/theme/index.dart';
import 'package:fleetmanager/provider/fleet_provider.dart';
import 'package:fleetmanager/models/veicolo.dart';
import 'package:fleetmanager/models/manutenzione.dart';
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
  final bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) {
        context.read<FleetProvider>().inizializzaDati();
      }
    });
  }

  Future<void> _caricaDati() async {
    // Rimuovi il setState qui se il provider gestisce già il suo isLoading
    try {
      await context.read<FleetProvider>().inizializzaDati();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Errore nel caricamento: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FleetProvider>();

    // FILTRO: Tutte le manutenzioni che non hanno ancora una data di fine
    final manutenzioniAttive =
        provider.manutenzioni.where((m) => m.oraFine == null).toList();

    return Scaffold(
      backgroundColor: AppColors.grey100,
      appBar: AppBar(
        title: const Text("Gestione Manutenzioni",
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.secondary,
        foregroundColor: AppColors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _caricaDati,
          )
        ],
      ),
      body: (_isLoading || provider.isLoading)
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildSummaryHeader(manutenzioniAttive.length),
                Expanded(
                  child: manutenzioniAttive.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          itemCount: manutenzioniAttive.length,
                          itemBuilder: (context, index) {
                            final m = manutenzioniAttive[index];
                            final v = provider.veicoli.firstWhere(
                              (veicolo) => veicolo.targa == m.targa,
                              orElse: () => Veicolo(
                                  targa: m.targa,
                                  marca: "N.D.",
                                  modello: "",
                                  km: 0,
                                  annoImmatricolazione: 0,
                                  tipoVeicolo: TipoVeicolo.auto,
                                  statoVeicolo: StatoVeicolo.disponibile),
                            );
                            return _buildMaintenanceCard(m, v, provider);
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton:
          provider.utenteLoggato?.ruoloUtente == RuoloUtente.manager
              ? FloatingActionButton.extended(
                  onPressed: () => _showMaintenanceForm(context),
                  backgroundColor: AppColors.secondary,
                  icon: const Icon(Icons.build, color: AppColors.white),
                  label: const Text("NUOVO INTERVENTO",
                      style: TextStyle(
                          color: AppColors.white, fontWeight: FontWeight.bold)),
                )
              : null,
    );
  }

  Widget _buildSummaryHeader(int count) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.white,
        boxShadow: [
          BoxShadow(
              color: AppColors.grey900.withValues(alpha: 0.05), blurRadius: 10)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "$count Interventi in Agenda",
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const Text("Lista degli interventi attivi e programmati",
              style: TextStyle(color: AppColors.grey600)),
        ],
      ),
    );
  }

  Widget _buildMaintenanceCard(
      Manutenzione m, Veicolo v, FleetProvider provider) {
    final isFuture = m.data.isAfter(DateTime.now());
    final df = DateFormat('dd/MM HH:mm');

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: isFuture ? 1 : 4,
      color: isFuture ? Colors.orange[50] : AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusDefault),
        side: BorderSide(
          color: isFuture ? AppColors.secondaryLight : AppColors.secondary,
          width: isFuture ? 1 : 2,
        ),
      ),
      child: ListTile(
        onTap: () => _showMaintenanceDetails(v, provider),
        leading: CircleAvatar(
          backgroundColor: isFuture ? Colors.orange[100] : AppColors.secondary,
          child: Icon(
            v.tipoVeicolo == TipoVeicolo.furgone
                ? Icons.local_shipping
                : Icons.directions_car,
            color: isFuture ? AppColors.secondary : AppColors.white,
          ),
        ),
        title: Text("${v.marca} ${v.modello}",
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Targa: ${v.targa} | ${df.format(m.data.toLocal())}"),
            Text(
                isFuture
                    ? "PROGRAMMATA - presso ${m.luogo}"
                    : "IN CORSO - presso ${m.luogo}",
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: isFuture ? FontWeight.normal : FontWeight.bold,
                    color:
                        isFuture ? Colors.orange[900] : AppColors.secondary)),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }

  void _showMaintenanceDetails(Veicolo v, FleetProvider provider) {
    final intervento = provider.manutenzioni.firstWhere(
      (m) => m.targa == v.targa && m.oraFine == null,
    );

    final kmController = TextEditingController(text: v.km.toString());

    showDialog(
      context: context,
      builder: (dialogContext) => DetailsPopUp(
        title: "Dettaglio Intervento",
        titleIcon: Icons.build_circle,
        details: [
          _detailRow(Icons.pin, "Targa", v.targa),
          _detailRow(Icons.speed, "Km attuali", "${v.km} km"),
          _detailRow(Icons.location_on, "Luogo", intervento.luogo),
          _detailRow(Icons.calendar_today, "Data prevista",
              DateFormat('dd/MM/yyyy HH:mm').format(intervento.data.toLocal())),
          _detailRow(Icons.description, "Motivo", intervento.descrizione),
        ],
        extraSectionTitle: "Chiusura",
        extraContent: Column(
          children: [
            const Text("Inserisci i km al rientro per liberare il veicolo:",
                style: TextStyle(fontSize: 12, color: Colors.black54)),
            TextField(
              controller: kmController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Km finali"),
            ),
          ],
        ),
        actionsSectionTitle: "Intervento",
        actions: [
          if (provider.utenteLoggato?.ruoloUtente == RuoloUtente.manager)
            OutlinedButton.icon(
              icon: const Icon(Icons.edit),
              label: const Text("MODIFICA"),
              style: AppButtonStyles.outlined(color: AppColors.secondary),
              onPressed: () {
                Navigator.pop(dialogContext);
                _showMaintenanceForm(context,
                    manutenzioneEsistente: intervento);
              },
            ),
          OutlinedButton(
            onPressed: () async {
              int nuoviKm = int.tryParse(kmController.text) ?? v.km;
              final navigator = Navigator.of(dialogContext);
              await provider.chiudiManutenzione(
                  intervento.idManutenzione, v.targa,
                  nuoviKm: nuoviKm);
              if (mounted) navigator.pop();
            },
            style: AppButtonStyles.outlined(color: AppColors.success),
            child: const Text("RIENTRO VEICOLO"),
          ),
        ],
      ),
    );
  }

  // ... (Widget _detailRow e _buildEmptyState rimangono identici a prima)

  void _showMaintenanceForm(BuildContext context,
      {Manutenzione? manutenzioneEsistente}) {
    final provider = context.read<FleetProvider>();
    final isEditing = manutenzioneEsistente != null;

    final veicoliDisponibili = provider.veicoli
        .where((v) =>
            v.statoVeicolo != StatoVeicolo.inManutenzione ||
            (isEditing && v.targa == manutenzioneEsistente.targa))
        .toList();

    Veicolo? veicoloSelezionato = isEditing
        ? provider.veicoli
            .firstWhere((v) => v.targa == manutenzioneEsistente.targa)
        : null;

    TipoManutenzione tipoSelezionato =
        manutenzioneEsistente?.tipoManutenzione ?? TipoManutenzione.ordinaria;
    final descController =
        TextEditingController(text: manutenzioneEsistente?.descrizione ?? "");
    final luogoController =
        TextEditingController(text: manutenzioneEsistente?.luogo ?? "");
    DateTime dataSelezionata = manutenzioneEsistente?.data ?? DateTime.now();
    TimeOfDay oraSelezionata = TimeOfDay.fromDateTime(dataSelezionata);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              left: 20,
              right: 20,
              top: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(isEditing ? "Modifica Intervento" : "Nuova Manutenzione",
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center),
              const SizedBox(height: 20),
              DropdownButtonFormField<Veicolo>(
                initialValue: veicoloSelezionato,
                items: veicoliDisponibili
                    .map(
                        (v) => DropdownMenuItem(value: v, child: Text(v.targa)))
                    .toList(),
                onChanged: isEditing ? null : (val) => veicoloSelezionato = val,
                decoration: const InputDecoration(
                    labelText: "Veicolo", border: OutlineInputBorder()),
              ),
              const SizedBox(height: 15),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      child: Text(
                          DateFormat('dd/MM/yyyy').format(dataSelezionata)),
                      onPressed: () async {
                        final picked = await showDatePicker(
                            context: context,
                            initialDate: dataSelezionata,
                            firstDate: DateTime.now(),
                            lastDate: DateTime(2100));
                        if (picked != null) {
                          setModalState(() => dataSelezionata = picked);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      child: Text(oraSelezionata.format(context)),
                      onPressed: () async {
                        final picked = await showTimePicker(
                            context: context, initialTime: oraSelezionata);
                        if (picked != null) {
                          setModalState(() => oraSelezionata = picked);
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              TextField(
                  controller: luogoController,
                  decoration: const InputDecoration(
                      labelText: "Officina", border: OutlineInputBorder())),
              const SizedBox(height: 15),
              TextField(
                  controller: descController,
                  decoration: const InputDecoration(
                      labelText: "Descrizione", border: OutlineInputBorder()),
                  maxLines: 2),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final dataCompleta = DateTime(
                        dataSelezionata.year,
                        dataSelezionata.month,
                        dataSelezionata.day,
                        oraSelezionata.hour,
                        oraSelezionata.minute);
                    final navigator = Navigator.of(sheetContext);
                    if (isEditing) {
                      await provider.modificaManutenzione(
                          idManutenzione: manutenzioneEsistente.idManutenzione,
                          descrizione: descController.text,
                          luogo: luogoController.text,
                          data: dataCompleta,
                          tipo: tipoSelezionato);
                    } else {
                      await provider.programmareManutenzione(
                          veicoloSelezionato!,
                          dataCompleta,
                          tipoSelezionato,
                          descController.text,
                          luogo: luogoController.text);
                    }
                    navigator.pop();
                  },
                  style: AppButtonStyles.elevated(color: AppColors.secondary),
                  child: Text(isEditing ? "SALVA MODIFICHE" : "PROGRAMMA"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.grey400),
          const SizedBox(width: 10),
          Text(
            "$label: ",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(child: Text("Nessun intervento in programma"));
  }
}
