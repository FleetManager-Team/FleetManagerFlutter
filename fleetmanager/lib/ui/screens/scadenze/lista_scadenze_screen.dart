import 'package:fleetmanager/models/enums/tipo_scadenza.dart';
import 'package:fleetmanager/core/theme/index.dart';
import 'package:fleetmanager/models/scadenza.dart';
import 'package:fleetmanager/provider/fleet_provider.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class ListaScadenzeScreen extends StatefulWidget {
  const ListaScadenzeScreen({super.key});

  @override
  State<ListaScadenzeScreen> createState() => _ListaScadenzeScreenState();
}

class _ListaScadenzeScreenState extends State<ListaScadenzeScreen> {
  TipoScadenza? filtroSelezionato;

  // Ordina: prima le scadute, poi per data crescente, le chiuse in fondo
  List<Scadenza> _ordinaScadenze(List<Scadenza> lista) {
    final aperte = lista.where((s) => !s.chiusa).toList()
      ..sort((a, b) => a.data.compareTo(b.data));
    final chiuse = lista.where((s) => s.chiusa).toList()
      ..sort((a, b) => b.data.compareTo(a.data));
    return [...aperte, ...chiuse];
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FleetProvider>();

    final tutteLeScadenze = filtroSelezionato == null
        ? provider.scadenze
        : provider.scadenze
            .where((s) => s.tipoScadenza == filtroSelezionato)
            .toList();

    final scadenzeFiltrate = _ordinaScadenze(tutteLeScadenze);

    // Contatori per i badge sui chip
    Map<TipoScadenza, int> contatoriUrgenti = {};
    for (var tipo in TipoScadenza.values) {
      contatoriUrgenti[tipo] = provider.scadenze
          .where((s) =>
              s.tipoScadenza == tipo &&
              !s.chiusa &&
              s.data.difference(DateTime.now()).inDays <= 30)
          .length;
    }
    final totaleUrgenti = provider.scadenze
        .where(
            (s) => !s.chiusa && s.data.difference(DateTime.now()).inDays <= 30)
        .length;

    return Scaffold(
      backgroundColor: AppColors.grey100,
      appBar: AppBar(
        title: const Text("Scadenze",
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primaryDark,
        foregroundColor: AppColors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // --- BARRA FILTRI A CHIP ---
          _buildChipFilterBar(contatoriUrgenti, totaleUrgenti),

          // --- LISTA ---
          Expanded(
            child: scadenzeFiltrate.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_outline,
                            size: 64, color: AppColors.grey400),
                        SizedBox(height: 12),
                        Text("Nessuna scadenza presente",
                            style: TextStyle(
                                color: AppColors.textSecondary, fontSize: 16)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(
                        AppSpacing.md, AppSpacing.sm, AppSpacing.md, 80),
                    itemCount: scadenzeFiltrate.length,
                    itemBuilder: (context, index) {
                      final scadenza = scadenzeFiltrate[index];

                      // Separatore visivo tra aperte e chiuse
                      final bool isFirstClosed = scadenza.chiusa &&
                          (index == 0 || !scadenzeFiltrate[index - 1].chiusa);

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (isFirstClosed)
                            const Padding(
                              padding:
                                  EdgeInsets.only(top: 16, bottom: 8, left: 4),
                              child: Row(
                                children: [
                                  Icon(Icons.history,
                                      size: 16, color: AppColors.grey500),
                                  SizedBox(width: 6),
                                  Text(
                                    "INTERVENTI COMPLETATI",
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.grey500,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          _buildScadenzaCard(scadenza),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _mostraFormCreazioneScadenza(context),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add),
        label: const Text("Nuova scadenza"),
      ),
    );
  }

  Widget _buildChipFilterBar(
      Map<TipoScadenza, int> contatoriUrgenti, int totaleUrgenti) {
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Chip "Tutti"
            _buildFilterChip(
              label: "Tutti",
              icon: Icons.grid_view_rounded,
              isSelected: filtroSelezionato == null,
              urgenti: totaleUrgenti,
              onTap: () => setState(() => filtroSelezionato = null),
            ),
            const SizedBox(width: 8),
            // Chip per ogni tipo
            ...TipoScadenza.values.map((tipo) {
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _buildFilterChip(
                  label: _labelTipo(tipo),
                  icon: _iconTipo(tipo),
                  isSelected: filtroSelezionato == tipo,
                  urgenti: contatoriUrgenti[tipo] ?? 0,
                  onTap: () => setState(() => filtroSelezionato = tipo),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required IconData icon,
    required bool isSelected,
    required int urgenti,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.grey100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.grey300,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 16,
                color: isSelected ? AppColors.white : AppColors.grey600),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? AppColors.white : AppColors.textPrimary,
              ),
            ),
            // Badge rosso se ci sono urgenti
            if (urgenti > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.white.withValues(alpha:0.3)
                      : AppColors.error,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$urgenti',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? AppColors.white : AppColors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildScadenzaCard(Scadenza scadenza) {
    final now = DateTime.now();
    final isScaduta = scadenza.data.isBefore(now);
    final giorniRimanenti = scadenza.data.difference(now).inDays;
    final isClosed = scadenza.chiusa;

    Color urgenzaColor;
    Color urgenzaBg;
    String urgenzaLabel;
    IconData urgenzaIcon;

    if (isClosed) {
      urgenzaColor = AppColors.grey500;
      urgenzaBg = AppColors.grey100;
      urgenzaLabel = "Completata";
      urgenzaIcon = Icons.check_circle;
    } else if (isScaduta) {
      urgenzaColor = AppColors.error;
      urgenzaBg = AppColors.error.withValues(alpha: 0.08);
      urgenzaLabel = "Scaduta";
      urgenzaIcon = Icons.error_outline;
    } else if (giorniRimanenti <= 7) {
      urgenzaColor = AppColors.error;
      urgenzaBg = AppColors.error.withValues(alpha: 0.08);
      urgenzaLabel =
          giorniRimanenti == 0 ? "Scade oggi" : "Scade in $giorniRimanenti gg";
      urgenzaIcon = Icons.warning_amber_rounded;
    } else if (giorniRimanenti <= 30) {
      urgenzaColor = AppColors.warning;
      urgenzaBg = AppColors.warning.withValues(alpha: 0.08);
      urgenzaLabel = "Scade in $giorniRimanenti gg";
      urgenzaIcon = Icons.schedule;
    } else {
      urgenzaColor = AppColors.success;
      urgenzaBg = AppColors.success.withValues(alpha: 0.08);
      urgenzaLabel = "Scade in $giorniRimanenti gg";
      urgenzaIcon = Icons.check_circle_outline;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: isClosed ? 0 : 2,
      color: isClosed ? AppColors.grey100 : AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusDefault),
        side: BorderSide(
          color: isClosed ? AppColors.grey300 : urgenzaColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusDefault),
        onTap: () => _mostraDettagliScadenza(scadenza),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Icona tipo con sfondo colorato
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isClosed ? AppColors.grey200 : urgenzaBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _iconTipo(scadenza.tipoScadenza),
                  color: isClosed ? AppColors.grey400 : urgenzaColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),

              // Contenuto centrale
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            "${_labelTipo(scadenza.tipoScadenza)} — ${scadenza.targa}",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              decoration:
                                  isClosed ? TextDecoration.lineThrough : null,
                              color: isClosed
                                  ? AppColors.grey500
                                  : AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Scadenza: ${DateFormat('dd/MM/yyyy').format(scadenza.data)}",
                      style: TextStyle(
                        fontSize: 12,
                        color: isClosed
                            ? AppColors.grey400
                            : AppColors.textSecondary,
                      ),
                    ),
                    if (isClosed && scadenza.dataChiusura != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        "Chiusa il ${DateFormat('dd/MM/yyyy').format(scadenza.dataChiusura!)} · €${scadenza.costoChiusura?.toStringAsFixed(2) ?? '0.00'}",
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.success,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),

              // Badge urgenza a destra
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: urgenzaBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(urgenzaIcon, size: 12, color: urgenzaColor),
                        const SizedBox(width: 4),
                        Text(
                          urgenzaLabel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: urgenzaColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (scadenza.notificata) ...[
                    const SizedBox(height: 6),
                    const Icon(Icons.notifications_active,
                        size: 16, color: AppColors.warning),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- HELPER ---
  String _labelTipo(TipoScadenza tipo) {
    switch (tipo) {
      case TipoScadenza.assicurazione:
        return "Assicurazione";
      case TipoScadenza.bollo:
        return "Bollo";
      case TipoScadenza.revisione:
        return "Revisione";
      case TipoScadenza.tagliando:
        return "Tagliando";
    }
  }

  IconData _iconTipo(TipoScadenza tipo) {
    switch (tipo) {
      case TipoScadenza.assicurazione:
        return Icons.security;
      case TipoScadenza.bollo:
        return Icons.receipt;
      case TipoScadenza.revisione:
        return Icons.build;
      case TipoScadenza.tagliando:
        return Icons.oil_barrel;
    }
  }

  // --- DIALOG DETTAGLIO ---
  void _mostraDettagliScadenza(Scadenza scadenza) {
    final provider = context.read<FleetProvider>();
    
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text("${_labelTipo(scadenza.tipoScadenza)} - ${scadenza.targa}"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  "Data scadenza: ${DateFormat('dd/MM/yyyy').format(scadenza.data)}"),
              const SizedBox(height: AppSpacing.sm),
              Text("Notificata: ${scadenza.notificata ? 'Sì' : 'No'}"),
              if (scadenza.descrizione != null &&
                  scadenza.descrizione!.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Text("Descrizione: ${scadenza.descrizione}"),
              ],
              if (scadenza.chiusa) ...[
                const Divider(),
                const SizedBox(height: AppSpacing.sm),
                const Text("INTERVENTO CHIUSO",
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: AppColors.success)),
                const SizedBox(height: AppSpacing.sm),
                Text(
                    "Data chiusura: ${DateFormat('dd/MM/yyyy').format(scadenza.dataChiusura!)}"),
                Text(
                    "Costo: €${scadenza.costoChiusura?.toStringAsFixed(2) ?? '0.00'}"),
                const SizedBox(height: AppSpacing.sm),
                Text("Dettagli: ${scadenza.dettagliChiusura ?? 'N/A'}"),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Chiudi"),
          ),
          if (!scadenza.chiusa) ...[
            if (!scadenza.notificata)
              ElevatedButton(
                onPressed: () async {
                  final navigator = Navigator.of(dialogContext);
                  await provider.segnaScadenzaNotificata(scadenza.idScadenza);
                  if (mounted) navigator.pop();
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.warning),
                child: const Text("Notificata"),
              ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _mostraFormModificaScadenza(context, scadenza);
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.info),
              child: const Text("Modifica"),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _mostraFormChiusuraIntervento(context, scadenza);
              },
              style:
                  ElevatedButton.styleFrom(backgroundColor: AppColors.success),
              child: const Text("Chiudi"),
            ),
            ElevatedButton(
              onPressed: () async {
                final navigator = Navigator.of(dialogContext);
                final messenger = ScaffoldMessenger.of(dialogContext);
                final conferma = await _mostraConfermaEliminazione(context);
                if (!conferma) return;
                if (mounted) navigator.pop();
                if (mounted) {
                  try {
                    await provider.eliminaScadenza(scadenza.idScadenza);
                    messenger.showSnackBar(
                      const SnackBar(content: Text("Scadenza eliminata")),
                    );
                  } catch (e) {
                    messenger.showSnackBar(
                      SnackBar(content: Text("Errore: $e")),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
              child: const Text("Elimina"),
            ),
          ],
        ],
      ),
    );
  }

  // --- FORM CREAZIONE ---
  void _mostraFormCreazioneScadenza(BuildContext context) {
    String? targaSelezionata;
    TipoScadenza? tipoSelezionato;
    DateTime? dataScadenza;
    int? km;
    int? mesi;
    String descrizione = '';

    final provider = context.read<FleetProvider>();

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text("Crea nuova scadenza"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButton<String?>(
                  value: targaSelezionata,
                  hint: const Text("Seleziona veicolo"),
                  isExpanded: true,
                  items: provider.veicoli
                      .map((v) => DropdownMenuItem(
                            value: v.targa,
                            child: Text(v.targa),
                          ))
                      .toList(),
                  onChanged: (value) =>
                      setState(() => targaSelezionata = value),
                ),
                const SizedBox(height: AppSpacing.md),
                DropdownButton<TipoScadenza?>(
                  value: tipoSelezionato,
                  hint: const Text("Seleziona tipo scadenza"),
                  isExpanded: true,
                  items: TipoScadenza.values
                      .map((t) => DropdownMenuItem(
                            value: t,
                            child: Text(_labelTipo(t)),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      tipoSelezionato = value;
                      mesi = null;
                      km = null;
                      descrizione = '';
                      if (value == TipoScadenza.bollo) mesi = 12;
                      if (value == TipoScadenza.assicurazione) mesi = 12;
                      if (value == TipoScadenza.revisione) mesi = 24;
                    });
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                ListTile(
                  title: const Text("Data scadenza"),
                  subtitle: Text(dataScadenza == null
                      ? "Seleziona data"
                      : DateFormat('dd/MM/yyyy').format(dataScadenza!)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final selected = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 3650)),
                    );
                    if (selected != null) {
                      setState(() => dataScadenza = selected);
                    }
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                if (tipoSelezionato == TipoScadenza.tagliando) ...[
                  TextField(
                    decoration: const InputDecoration(
                      labelText: "Descrizione manutenzione",
                      hintText: "Es: Cambio olio, Sostituzione filtri",
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                    onChanged: (value) => descrizione = value,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    decoration: const InputDecoration(
                      labelText: "KM prossimo tagliando (opzionale)",
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) => km = int.tryParse(value),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    decoration: const InputDecoration(
                      labelText: "Mesi prossimo tagliando",
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) => mesi = int.tryParse(value),
                  ),
                ] else if (tipoSelezionato != null) ...[
                  TextField(
                    decoration: InputDecoration(
                      labelText: "Mesi validità",
                      border: const OutlineInputBorder(),
                      helperText: tipoSelezionato == TipoScadenza.revisione
                          ? "Generalmente 24 mesi"
                          : "Generalmente 12 mesi",
                    ),
                    keyboardType: TextInputType.number,
                    controller:
                        TextEditingController(text: mesi?.toString() ?? ''),
                    onChanged: (value) => mesi = int.tryParse(value),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Annulla"),
            ),
            ElevatedButton(
              onPressed: () async {
                if (targaSelezionata == null ||
                    tipoSelezionato == null ||
                    dataScadenza == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text("Riempire i campi obbligatori")),
                  );
                  return;
                }
                if (tipoSelezionato == TipoScadenza.tagliando &&
                    descrizione.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text("Inserire descrizione per il tagliando")),
                  );
                  return;
                }
                final navigator = Navigator.of(context);
                final messenger = ScaffoldMessenger.of(context);
                try {
                  await provider.creaScadenza(
                    targa: targaSelezionata!,
                    tipoScadenza: tipoSelezionato!,
                    data: dataScadenza!,
                    kmScadenza: km,
                    mesiScadenza: mesi,
                    descrizione: descrizione.isNotEmpty ? descrizione : null,
                  );
                  if (mounted) {
                    navigator.pop();
                    messenger.showSnackBar(
                      const SnackBar(content: Text("Scadenza creata")),
                    );
                  }
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(content: Text("Errore: $e")),
                  );
                }
              },
              child: const Text("Crea"),
            ),
          ],
        ),
      ),
    );
  }

  // --- FORM MODIFICA ---
  void _mostraFormModificaScadenza(BuildContext context, Scadenza scadenza) {
    String targaSelezionata = scadenza.targa;
    TipoScadenza tipoSelezionato = scadenza.tipoScadenza;
    DateTime dataScadenza = scadenza.data;
    int? km = scadenza.kmScadenza;
    int? mesi = scadenza.mesiScadenza;
    String descrizione = scadenza.descrizione ?? '';

    final provider = context.read<FleetProvider>();

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text("Modifica scadenza"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButton<String>(
                  value: targaSelezionata,
                  isExpanded: true,
                  items: provider.veicoli
                      .map((v) => DropdownMenuItem(
                            value: v.targa,
                            child: Text(v.targa),
                          ))
                      .toList(),
                  onChanged: (value) => setState(
                      () => targaSelezionata = value ?? scadenza.targa),
                ),
                const SizedBox(height: AppSpacing.md),
                DropdownButton<TipoScadenza>(
                  value: tipoSelezionato,
                  isExpanded: true,
                  items: TipoScadenza.values
                      .map((t) => DropdownMenuItem(
                            value: t,
                            child: Text(_labelTipo(t)),
                          ))
                      .toList(),
                  onChanged: (value) => setState(
                      () => tipoSelezionato = value ?? scadenza.tipoScadenza),
                ),
                const SizedBox(height: AppSpacing.md),
                ListTile(
                  title: const Text("Data scadenza"),
                  subtitle: Text(DateFormat('dd/MM/yyyy').format(dataScadenza)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final selected = await showDatePicker(
                      context: context,
                      initialDate: dataScadenza,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 3650)),
                    );
                    if (selected != null) {
                      setState(() => dataScadenza = selected);
                    }
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                if (tipoSelezionato == TipoScadenza.tagliando) ...[
                  TextField(
                    decoration: const InputDecoration(
                      labelText: "Descrizione manutenzione",
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                    controller: TextEditingController(text: descrizione),
                    onChanged: (value) => descrizione = value,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    decoration: const InputDecoration(
                      labelText: "KM prossimo tagliando (opzionale)",
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    controller:
                        TextEditingController(text: km?.toString() ?? ''),
                    onChanged: (value) => km = int.tryParse(value),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    decoration: const InputDecoration(
                      labelText: "Mesi prossimo tagliando",
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    controller:
                        TextEditingController(text: mesi?.toString() ?? ''),
                    onChanged: (value) => mesi = int.tryParse(value),
                  ),
                ] else ...[
                  TextField(
                    decoration: InputDecoration(
                      labelText: "Mesi validità",
                      border: const OutlineInputBorder(),
                      helperText: tipoSelezionato == TipoScadenza.revisione
                          ? "Generalmente 24 mesi"
                          : "Generalmente 12 mesi",
                    ),
                    keyboardType: TextInputType.number,
                    controller:
                        TextEditingController(text: mesi?.toString() ?? ''),
                    onChanged: (value) => mesi = int.tryParse(value),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Annulla"),
            ),
            ElevatedButton(
              onPressed: () async {
                final navigator = Navigator.of(context);
                final messenger = ScaffoldMessenger.of(context);
                try {
                  await provider.modificaScadenza(
                    idScadenza: scadenza.idScadenza,
                    targa: targaSelezionata,
                    tipoScadenza: tipoSelezionato,
                    data: dataScadenza,
                    kmScadenza: km,
                    mesiScadenza: mesi,
                    descrizione: descrizione.isNotEmpty ? descrizione : null,
                  );
                  if (mounted) {
                    navigator.pop();
                    messenger.showSnackBar(
                      const SnackBar(content: Text("Scadenza modificata")),
                    );
                  }
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(content: Text("Errore: $e")),
                  );
                }
              },
              child: const Text("Salva"),
            ),
          ],
        ),
      ),
    );
  }

  // --- FORM CHIUSURA ---
  void _mostraFormChiusuraIntervento(BuildContext context, Scadenza scadenza) {
    double costo = 0;
    String dettagli = '';
    final provider = context.read<FleetProvider>();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Chiudi intervento"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "${_labelTipo(scadenza.tipoScadenza)} - ${scadenza.targa}",
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: AppSpacing.md),
              const Text("Registra i dettagli dell'intervento completato:",
                  style: TextStyle(fontSize: 14)),
              const SizedBox(height: AppSpacing.md),
              TextField(
                decoration: const InputDecoration(
                  labelText: "Costo intervento (€)",
                  border: OutlineInputBorder(),
                  prefixText: "€ ",
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                onChanged: (value) => costo = double.tryParse(value) ?? 0,
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                decoration: const InputDecoration(
                  labelText: "Dettagli intervento",
                  border: OutlineInputBorder(),
                  hintText: "Es: Cambio olio, Sostituzione batteria, ...",
                ),
                maxLines: 3,
                onChanged: (value) => dettagli = value,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Annulla"),
          ),
          ElevatedButton(
            onPressed: () async {
              if (dettagli.isEmpty) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(
                      content: Text("Inserire i dettagli dell'intervento")),
                );
                return;
              }
              final navigator = Navigator.of(dialogContext);
              final messenger = ScaffoldMessenger.of(dialogContext);
              try {
                await provider.chiudiScadenza(
                  idScadenza: scadenza.idScadenza,
                  costo: costo,
                  dettagli: dettagli,
                );
                if (!context.mounted || !dialogContext.mounted) return;
                navigator.pop();
                _mostraFormProssimaScadenza(context, scadenza, provider);
              } catch (e) {
                if (!dialogContext.mounted) return;
                messenger.showSnackBar(
                  SnackBar(content: Text("Errore: $e")),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
            child: const Text("Completa"),
          ),
        ],
      ),
    );
  }

  // --- FORM PROSSIMA SCADENZA ---
  void _mostraFormProssimaScadenza(
      BuildContext context, Scadenza scadenzaChiusa, FleetProvider provider) {
    // Valori default intelligenti in base al tipo
    int mesiDefault;
    int? kmDefault;
    switch (scadenzaChiusa.tipoScadenza) {
      case TipoScadenza.tagliando:
        mesiDefault = scadenzaChiusa.mesiScadenza ?? 12;
        kmDefault = scadenzaChiusa.kmScadenza;
        break;
      case TipoScadenza.revisione:
        mesiDefault = 24;
        break;
      case TipoScadenza.bollo:
      case TipoScadenza.assicurazione:
        mesiDefault = 12;
        break;
    }

    int mesi = mesiDefault;
    int? km = kmDefault;
    final ora = DateTime.now();
    DateTime dataCalcolata = DateTime(ora.year, ora.month + mesi, ora.day);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) {
          void aggiornaData(int nuoviMesi) {
            setState(() {
              mesi = nuoviMesi;
              dataCalcolata =
                  DateTime(ora.year, ora.month + nuoviMesi, ora.day);
            });
          }

          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(_iconTipo(scadenzaChiusa.tipoScadenza),
                      color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text("Prossima scadenza",
                      style:
                          TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Info contestuale
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.info.withValues(alpha:0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: AppColors.info.withValues(alpha:0.3), width: 1),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline,
                            size: 18, color: AppColors.info),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "Stai pianificando il prossimo ${_labelTipo(scadenzaChiusa.tipoScadenza)} per ${scadenzaChiusa.targa}",
                            style: const TextStyle(
                                fontSize: 13, color: AppColors.info),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Controllo mesi con +/-
                  const Text("Tra quanti mesi?",
                      style:
                          TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      SizedBox(
                        width: 40,
                        height: 40,
                        child: OutlinedButton(
                          onPressed:
                              mesi > 1 ? () => aggiornaData(mesi - 1) : null,
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Icon(Icons.remove, size: 18),
                        ),
                      ),
                      Expanded(
                        child: Center(
                          child: Text(
                            "$mesi mesi",
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 40,
                        height: 40,
                        child: OutlinedButton(
                          onPressed: () => aggiornaData(mesi + 1),
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Icon(Icons.add, size: 18),
                        ),
                      ),
                    ],
                  ),
                  // Chip scorciatoie
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: _scorciatoieMesi(scadenzaChiusa.tipoScadenza)
                        .map((m) => GestureDetector(
                              onTap: () => aggiornaData(m),
                              child: Chip(
                                label: Text("$m mesi"),
                                backgroundColor: mesi == m
                                    ? AppColors.primary
                                    : AppColors.grey100,
                                labelStyle: TextStyle(
                                  fontSize: 12,
                                  color: mesi == m
                                      ? AppColors.white
                                      : AppColors.textPrimary,
                                ),
                              ),
                            ))
                        .toList(),
                  ),

                  // KM solo per tagliando
                  if (scadenzaChiusa.tipoScadenza ==
                      TipoScadenza.tagliando) ...[
                    const SizedBox(height: AppSpacing.lg),
                    const Text("Tra quanti km? (opzionale)",
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 8),
                    TextField(
                      decoration: const InputDecoration(
                        hintText: "Es: 10000",
                        border: OutlineInputBorder(),
                        suffixText: "km",
                      ),
                      keyboardType: TextInputType.number,
                      controller:
                          TextEditingController(text: km?.toString() ?? ''),
                      onChanged: (value) =>
                          setState(() => km = int.tryParse(value)),
                    ),
                  ],

                  const SizedBox(height: AppSpacing.lg),

                  // Data risultante calcolata
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: AppColors.success.withValues(alpha: 0.3), width: 1),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.event_available,
                            color: AppColors.success, size: 22),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Prossima scadenza fissata al:",
                                style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary)),
                            Text(
                              DateFormat('dd MMMM yyyy', 'it')
                                  .format(dataCalcolata),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.success,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Salta"),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  final navigator = Navigator.of(context);
                  final messenger = ScaffoldMessenger.of(context);
                  try {
                    await provider.creaScadenza(
                      targa: scadenzaChiusa.targa,
                      tipoScadenza: scadenzaChiusa.tipoScadenza,
                      data: dataCalcolata,
                      kmScadenza: km,
                      mesiScadenza: mesi,
                      descrizione: scadenzaChiusa.descrizione,
                    );
                    if (mounted) {
                      navigator.pop();
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            "Prossimo ${_labelTipo(scadenzaChiusa.tipoScadenza)} fissato al ${DateFormat('dd/MM/yyyy').format(dataCalcolata)}",
                          ),
                          backgroundColor: AppColors.success,
                        ),
                      );
                    }
                  } catch (e) {
                    messenger.showSnackBar(
                      SnackBar(content: Text("Errore: $e")),
                    );
                  }
                },
                icon: const Icon(Icons.add_task),
                label: const Text("Crea scadenza"),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary),
              ),
            ],
          );
        },
      ),
    );
  }

  // Scorciatoie mesi suggerite per tipo
  List<int> _scorciatoieMesi(TipoScadenza tipo) {
    switch (tipo) {
      case TipoScadenza.tagliando:
        return [6, 12, 18];
      case TipoScadenza.revisione:
        return [12, 24, 48];
      case TipoScadenza.bollo:
      case TipoScadenza.assicurazione:
        return [6, 12];
    }
  }

  Future<bool> _mostraConfermaEliminazione(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Eliminare scadenza?"),
            content: const Text("Questa azione non può essere annullata."),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("Annulla"),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style:
                    ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                child: const Text("Elimina"),
              ),
            ],
          ),
        ) ??
        false;
  }
}
