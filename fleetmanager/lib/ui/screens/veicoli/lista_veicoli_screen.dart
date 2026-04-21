import 'package:FleetManager/models/enums/ruolo_utente.dart';
import 'package:FleetManager/models/enums/stato_prenotazione.dart';
import 'package:FleetManager/models/enums/tipo_manutenzione.dart';
import 'package:FleetManager/models/manutenzione.dart';
import 'package:FleetManager/models/prenotazione.dart';
import 'package:FleetManager/core/theme/index.dart';
import 'package:FleetManager/ui/screens/prenotazioni/nuova_prenotazione_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:FleetManager/models/enums/stato_veicolo.dart';
import 'package:FleetManager/models/enums/tipo_veicolo.dart';
import 'package:FleetManager/provider/fleet_provider.dart';
import 'package:FleetManager/models/veicolo.dart';
import 'package:FleetManager/ui/widgets/details_pop_up.dart';

class VehicleListScreen extends StatefulWidget {
  const VehicleListScreen({super.key});

  @override
  State<VehicleListScreen> createState() => _VehicleListScreenState();
}

class _VehicleListScreenState extends State<VehicleListScreen> {
  StatoVeicolo? filtroSelezionato;

  @override
  Widget build(BuildContext context) {
    // watch permette alla lista di aggiornarsi in tempo reale se cambiano i dati sul DB
    final provider = context.watch<FleetProvider>();

    final veicoliFiltrati = filtroSelezionato == null
        ? provider.veicoli
        : provider.veicoli
            .where((v) => v.statoVeicolo == filtroSelezionato)
            .toList();

    return Scaffold(
      backgroundColor: AppColors.grey100,
      appBar: AppBar(
        title: const Text("Parco Veicoli",
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primaryDark,
        foregroundColor: AppColors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: provider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : veicoliFiltrati.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        itemCount: veicoliFiltrati.length,
                        itemBuilder: (context, index) =>
                            _buildVehicleCard(veicoliFiltrati[index]),
                      ),
          ),
        ],
      ),
      floatingActionButton:
          provider.utenteLoggato?.ruoloUtente == RuoloUtente.manager
              ? FloatingActionButton(
                  onPressed: () => _showAddVehicleForm(context),
                  backgroundColor: AppColors.primary,
                  child: const Icon(Icons.add, color: AppColors.white),
                )
              : null,
    );
  }

  Widget _buildFilterBar() {
    return Container(
      height: 60,
      width: double.infinity,
      color: AppColors.white,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          _filterChip(null, "TUTTI"),
          _filterChip(StatoVeicolo.disponibile, "DISPONIBILI"),
          _filterChip(StatoVeicolo.prenotato, "PRENOTATI"),
          _filterChip(StatoVeicolo.inManutenzione, "IN SERVICE"),
          _filterChip(StatoVeicolo.fuoriServizio, "NON DISPONIBILI"),
        ],
      ),
    );
  }

  Widget _filterChip(StatoVeicolo? stato, String label) {
    final isSelected = filtroSelezionato == stato;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        labelStyle: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : AppColors.primaryDark),
        selected: isSelected,
        selectedColor: AppColors.primaryDark,
        backgroundColor: AppColors.grey50,
        onSelected: (val) =>
            setState(() => filtroSelezionato = val ? stato : null),
      ),
    );
  }

  Widget _buildVehicleCard(Veicolo v) {
    final provider = context.watch<FleetProvider>();

    // Cerchiamo se c'è una manutenzione programmata (non ancora chiusa e futura)
    final manutenzioneProgrammata =
        provider.manutenzioni.cast<Manutenzione?>().firstWhere(
              (m) =>
                  m?.targa == v.targa &&
                  m?.oraFine == null &&
                  m!.data.isAfter(DateTime.now()),
              orElse: () => null,
            );

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusDefault)),
      child: ListTile(
        onTap: () => _showVehicleDetails(v),
        leading: Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: _getStatusColor(v.statoVeicolo).withOpacity(0.1),
            borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
          ),
          child: Icon(
            v.tipoVeicolo == TipoVeicolo.furgone
                ? Icons.local_shipping
                : Icons.directions_car,
            color: _getStatusColor(v.statoVeicolo),
          ),
        ),
        title: Text("${v.marca} ${v.modello}",
            style: const TextStyle(fontWeight: FontWeight.bold)),

        // MODIFICA QUI: Subtitle multi-riga per mostrare i KM e l'eventuale avviso
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Targa: ${v.targa} • ${v.km} km"),

            // Se c'è una manutenzione in arrivo, mostriamo l'avviso arancione
            if (manutenzioneProgrammata != null)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Row(
                  children: [
                    const Icon(Icons.event_busy,
                        color: AppColors.secondary, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      "Manutenzione: ${manutenzioneProgrammata.data.day}/${manutenzioneProgrammata.data.month} ore ${manutenzioneProgrammata.data.hour}:${manutenzioneProgrammata.data.minute.toString().padLeft(2, '0')}",
                      style: const TextStyle(
                          color: AppColors.secondary,
                          fontSize: 11,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
          ],
        ),
        trailing: _buildStatusChip(v.statoVeicolo),
      ),
    );
  }

  void _showVehicleDetails(Veicolo v) {
    final provider = context.read<FleetProvider>();
    final bool isManager =
        provider.utenteLoggato?.ruoloUtente == RuoloUtente.manager;

    // Calcolo prossima prenotazione per questo veicolo
    List<Prenotazione> future = provider.prenotazioni
        .where((p) =>
            p.targa == v.targa &&
            p.statoPrenotazione != StatoPrenotazione.annullata &&
            p.dataFine.isAfter(DateTime.now()))
        .toList();

    future.sort((a, b) => a.dataInizio.compareTo(b.dataInizio));
    Prenotazione? prossima = future.isNotEmpty ? future.first : null;

    showDialog(
      context: context,
      builder: (context) => DetailsPopUp(
        title: "${v.marca} ${v.modello}",
        titleIcon: v.tipoVeicolo == TipoVeicolo.furgone
            ? Icons.local_shipping
            : Icons.directions_car,
        details: [
          _detailRow(Icons.tag, "Targa", v.targa),
          _detailRow(
              Icons.calendar_today, "Anno", v.annoImmatricolazione.toString()),
          _detailRow(Icons.speed, "Km attuali", "${v.km} km"),
          _detailRow(Icons.info_outline, "Stato",
              v.statoVeicolo.nameToDisplay.toUpperCase()),
        ],
        extraSectionTitle: isManager ? "GESTIONE STATO" : "PROSSIMO IMPEGNO",
        extraContent: isManager
            ? _buildManagerActions(
                v, provider) // Sezione speciale per il Manager
            : (prossima != null
                ? Column(
                    children: [
                      _detailRow(
                          Icons.person, "Driver ID", "#${prossima.idUtente}"),
                      _detailRow(
                          Icons.event,
                          "Inizio",
                          DateFormat('dd/MM HH:mm')
                              .format(prossima.dataInizio)),
                      _detailRow(Icons.event_available, "Fine",
                          DateFormat('dd/MM HH:mm').format(prossima.dataFine)),
                    ],
                  )
                : const Text(
                    "Nessuna prenotazione futura.",
                    style: TextStyle(
                        fontSize: 13,
                        color: AppColors.success,
                        fontStyle: FontStyle.italic),
                  )),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("CHIUDI")),

          // Bottone Prenota (solo per Driver e se disponibile)
          if (!isManager && v.statoVeicolo == StatoVeicolo.disponibile)
            ElevatedButton(
              style:
                  ElevatedButton.styleFrom(backgroundColor: AppColors.primaryDark),
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const NuovaPrenotazioneScreen()),
                );
              },
              child: const Text("PRENOTA ORA",
                  style: TextStyle(color: AppColors.white)),
            ),
        ],
      ),
    );
  }

  Widget _buildManagerActions(Veicolo v, FleetProvider provider) {
    // Verifichiamo se il veicolo è attualmente in uno stato di blocco
    bool isAttualmenteFermo = v.statoVeicolo == StatoVeicolo.fuoriServizio ||
        v.statoVeicolo == StatoVeicolo.inManutenzione;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),

        // 1. TASTO ARANCIONE (Sempre presente)
        // Serve per aprire il form e programmare l'intervento tecnico
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.build_circle_outlined, color: AppColors.white),
            label: const Text("METTI IN MANUTENZIONE",
                style: TextStyle(
                    color: AppColors.white, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.secondary,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusDefault)),
            ),
            onPressed: () {
              Navigator.pop(context); // Chiude il popup dei dettagli
              _showMaintenanceFormFromVehicle(
                  context, v); // Apre il form di inserimento
            },
          ),
        ),

        const SizedBox(height: 12),

        // 2. TASTO DINAMICO (Cambia in base allo stato)
        SizedBox(
          width: double.infinity,
          child: isAttualmenteFermo
              ? ElevatedButton.icon(
                  // STATO: RIPRISTINA (Verde)
                  icon: const Icon(Icons.check_circle_outline,
                      color: AppColors.white),
                  label: const Text("RIPRISTINA DISPONIBILITÀ",
                      style: TextStyle(
                          color: AppColors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppSpacing.radiusDefault)),
                  ),
                  onPressed: () async {
                    await provider.aggiornaStatoVeicolo(
                        v.targa, StatoVeicolo.disponibile);
                    if (mounted) Navigator.pop(context);
                  },
                )
              : OutlinedButton.icon(
                  // STATO: SEGNALA FUORI SERVIZIO (Bordo Rosso)
                  icon: const Icon(Icons.error_outline, color: AppColors.error),
                  label: const Text("SEGNALA FUORI SERVIZIO",
                      style: TextStyle(
                          color: AppColors.error, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: const BorderSide(color: AppColors.error, width: 1.5),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppSpacing.radiusDefault)),
                  ),
                  onPressed: () async {
                    await provider.aggiornaStatoVeicolo(
                        v.targa, StatoVeicolo.fuoriServizio);
                    if (mounted) Navigator.pop(context);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 60, color: AppColors.grey400),
          SizedBox(height: 16),
          Text("Nessun veicolo corrisponde al filtro",
              style: TextStyle(color: AppColors.grey600, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.grey400),
          const SizedBox(width: 10),
          Text("$label: ",
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  Widget _buildStatusChip(StatoVeicolo stato) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _getStatusColor(stato),
        borderRadius: BorderRadius.circular(AppSpacing.radiusDefault),
      ),
      child: Text(
        stato.name.toUpperCase(),
        style: const TextStyle(
            fontSize: 9, color: AppColors.white, fontWeight: FontWeight.bold),
      ),
    );
  }

  Color _getStatusColor(StatoVeicolo stato) {
    switch (stato) {
      case StatoVeicolo.disponibile:
        return AppColors.success;
      case StatoVeicolo.prenotato:
        return AppColors.primaryDark;
      case StatoVeicolo.inManutenzione:
        return AppColors.secondary;
      case StatoVeicolo.fuoriServizio:
        return AppColors.error;
    }
  }

  void _showAddVehicleForm(BuildContext context) {
    final targaController = TextEditingController();
    final marcaController = TextEditingController();
    final modelloController = TextEditingController();
    final kmController = TextEditingController();
    final annoController =
        TextEditingController(text: DateTime.now().year.toString());
    TipoVeicolo tipoSelezionato = TipoVeicolo.auto;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 20,
          right: 20,
          top: 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("AGGIUNGI NUOVO VEICOLO",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 20),
              TextField(
                  controller: targaController,
                  decoration: const InputDecoration(labelText: "Targa")),
              TextField(
                  controller: marcaController,
                  decoration: const InputDecoration(labelText: "Marca")),
              TextField(
                  controller: modelloController,
                  decoration: const InputDecoration(labelText: "Modello")),
              TextField(
                controller: annoController,
                decoration:
                    const InputDecoration(labelText: "Anno Immatricolazione"),
                keyboardType: TextInputType.number,
              ),
              TextField(
                  controller: kmController,
                  decoration:
                      const InputDecoration(labelText: "Kilometri attuali"),
                  keyboardType: TextInputType.number),
              const SizedBox(height: 15),
              DropdownButtonFormField<TipoVeicolo>(
                initialValue: tipoSelezionato,
                decoration: const InputDecoration(labelText: "Tipo Veicolo"),
                items: TipoVeicolo.values
                    .map((t) => DropdownMenuItem(
                        value: t, child: Text(t.name.toUpperCase())))
                    .toList(),
                onChanged: (val) => tipoSelezionato = val!,
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  backgroundColor: AppColors.primary,
                ),
                onPressed: () async {
                  final provider = context.read<FleetProvider>();

                  try {
                    await provider.aggiungiNuovoVeicolo(
                      targa: targaController.text,
                      marca: marcaController.text,
                      modello: modelloController.text,
                      tipo: tipoSelezionato.name,
                      anno: annoController.text,
                      kmAttuali: kmController.text,
                    );

                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text("Veicolo aggiunto con successo!")),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Errore: ${e.toString()}")),
                      );
                    }
                  }
                },
                child: const Text("SALVA VEICOLO",
                    style: TextStyle(color: AppColors.white)),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _showMaintenanceFormFromVehicle(BuildContext context, Veicolo v) {
    final provider = context.read<FleetProvider>();

    final descController = TextEditingController();
    final luogoController = TextEditingController();
    DateTime dataSelezionata = DateTime.now();
    TimeOfDay oraSelezionata = TimeOfDay.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StatefulBuilder(
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
              Text("Programma Intervento: ${v.targa}",
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center),
              const SizedBox(height: 20),

              // Data e Ora
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.calendar_today),
                      label: Text(
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
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.access_time),
                      label: Text(oraSelezionata.format(context)),
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
                      labelText: "Officina / Luogo",
                      border: OutlineInputBorder())),
              const SizedBox(height: 15),
              TextField(
                  controller: descController,
                  decoration: const InputDecoration(
                      labelText: "Descrizione guasto/intervento",
                      border: OutlineInputBorder()),
                  maxLines: 2),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secondary,
                    foregroundColor: AppColors.white),
                onPressed: () async {
                  final dataCompleta = DateTime(
                      dataSelezionata.year,
                      dataSelezionata.month,
                      dataSelezionata.day,
                      oraSelezionata.hour,
                      oraSelezionata.minute);

                  // Chiamata al metodo del provider che già usi nella dashboard
                  await provider.programmareManutenzione(
                      v,
                      dataCompleta,
                      TipoManutenzione
                          .ordinaria, // Puoi aggiungere un dropdown se vuoi distinguere
                      descController.text,
                      luogo: luogoController.text);

                  if (context.mounted) Navigator.pop(context);
                },
                child: const Text("CONFERMA E METTI IN SERVICE"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
