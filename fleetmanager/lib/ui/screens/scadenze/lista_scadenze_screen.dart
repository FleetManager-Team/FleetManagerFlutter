import 'package:FleetManager/models/enums/tipo_scadenza.dart';
import 'package:FleetManager/core/theme/index.dart';
import 'package:FleetManager/models/scadenza.dart';
import 'package:FleetManager/provider/fleet_provider.dart';
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

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FleetProvider>();

    final scadenzeFiltrate = filtroSelezionato == null
        ? provider.scadenze
        : provider.scadenze
            .where((s) => s.tipoScadenza == filtroSelezionato)
            .toList();

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
          _buildFilterBar(),
          Expanded(
            child: scadenzeFiltrate.isEmpty
                ? const Center(
                    child: Text("Nessuna scadenza presente",
                        style: TextStyle(color: AppColors.textSecondary)))
                : ListView.builder(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: scadenzeFiltrate.length,
                    itemBuilder: (context, index) {
                      final scadenza = scadenzeFiltrate[index];
                      return _buildScadenzaCard(scadenza);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _mostraFormCreazioneScadenza(context),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      color: AppColors.white,
      child: Row(
        children: [
          const Text("Filtra per tipo:",
              style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: DropdownButton<TipoScadenza?>(
              value: filtroSelezionato,
              hint: const Text("Tutti"),
              isExpanded: true,
              items: [
                const DropdownMenuItem(value: null, child: Text("Tutti")),
                ...TipoScadenza.values.map((tipo) => DropdownMenuItem(
                      value: tipo,
                      child: Text(tipo.name.toUpperCase()),
                    )),
              ],
              onChanged: (value) => setState(() => filtroSelezionato = value),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScadenzaCard(Scadenza scadenza) {
    final isScaduta = scadenza.data.isBefore(DateTime.now());
    final giorniRimanenti = scadenza.data.difference(DateTime.now()).inDays;
    final isClosed = scadenza.chiusa;

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      color: isClosed ? AppColors.grey100 : AppColors.white,
      child: ListTile(
        leading: Icon(
          _getIconForTipo(scadenza.tipoScadenza),
          color: isClosed 
              ? AppColors.grey400 
              : (isScaduta ? AppColors.error : AppColors.primary),
        ),
        title: Text(
          "${scadenza.tipoScadenza.name.toUpperCase()} - ${scadenza.targa}",
          style: TextStyle(
            fontWeight: FontWeight.w600,
            decoration: isClosed ? TextDecoration.lineThrough : null,
            color: isClosed ? AppColors.grey500 : null,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Data: ${DateFormat('dd/MM/yyyy').format(scadenza.data)}"),
            if (isClosed)
              Text(
                "Chiusa il ${DateFormat('dd/MM/yyyy').format(scadenza.dataChiusura!)} - Costo: €${scadenza.costoChiusura?.toStringAsFixed(2) ?? '0.00'}",
                style: const TextStyle(
                  color: AppColors.success,
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                ),
              )
            else
              Text(
                isScaduta
                    ? "SCADUTA"
                    : giorniRimanenti == 0
                        ? "Scade oggi"
                        : "Scade tra $giorniRimanenti giorni",
                style: TextStyle(
                  color: isScaduta ? AppColors.error : AppColors.success,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
        trailing: scadenza.notificata
            ? const Icon(Icons.notifications_active, color: AppColors.warning)
            : const Icon(Icons.notifications_none, color: AppColors.grey400),
        onTap: () => _mostraDettagliScadenza(scadenza),
      ),
    );
  }

  IconData _getIconForTipo(TipoScadenza tipo) {
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

  void _mostraDettagliScadenza(Scadenza scadenza) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("${scadenza.tipoScadenza.name.toUpperCase()} - ${scadenza.targa}"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Data scadenza: ${DateFormat('dd/MM/yyyy').format(scadenza.data)}"),
              const SizedBox(height: AppSpacing.sm),
              Text("Notificata: ${scadenza.notificata ? 'Sì' : 'No'}"),
              const SizedBox(height: AppSpacing.sm),
              if (scadenza.chiusa) ...[
                const Divider(),
                const SizedBox(height: AppSpacing.sm),
                const Text("INTERVENTO CHIUSO", style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.success)),
                const SizedBox(height: AppSpacing.sm),
                Text("Data chiusura: ${DateFormat('dd/MM/yyyy').format(scadenza.dataChiusura!)}"),
                Text("Costo: €${scadenza.costoChiusura?.toStringAsFixed(2) ?? '0.00'}"),
                const SizedBox(height: AppSpacing.sm),
                Text("Dettagli: ${scadenza.dettagliChiusura ?? 'N/A'}"),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Chiudi"),
          ),
          if (!scadenza.chiusa) ...[
            if (!scadenza.notificata)
              ElevatedButton(
                onPressed: () async {
                  await context.read<FleetProvider>().segnaScadenzaNotificata(scadenza.idScadenza);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.warning,
                ),
                child: const Text("Notificata"),
              ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _mostraFormModificaScadenza(context, scadenza);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.info,
              ),
              child: const Text("Modifica"),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _mostraFormChiusuraIntervento(context, scadenza);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
              ),
              child: const Text("Chiudi"),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                if (await _mostraConfermaEliminazione(context)) {
                  if (mounted) {
                    try {
                      await context.read<FleetProvider>().eliminaScadenza(scadenza.idScadenza);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Scadenza eliminata")),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Errore: $e")),
                      );
                    }
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
              ),
              child: const Text("Elimina"),
            ),
          ],
        ],
      ),
    );
  }

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
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text("Crea nuova scadenza"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Selezione veicolo
                DropdownButton<String?>(
                  value: targaSelezionata,
                  hint: const Text("Seleziona veicolo"),
                  isExpanded: true,
                  items: provider.veicoli.map((v) => DropdownMenuItem(
                        value: v.targa,
                        child: Text(v.targa),
                      )).toList(),
                  onChanged: (value) => setState(() => targaSelezionata = value),
                ),
                const SizedBox(height: AppSpacing.md),
                
                // Selezione tipo scadenza
                DropdownButton<TipoScadenza?>(
                  value: tipoSelezionato,
                  hint: const Text("Seleziona tipo scadenza"),
                  isExpanded: true,
                  items: TipoScadenza.values.map((t) => DropdownMenuItem(
                        value: t,
                        child: Text(t.name.toUpperCase()),
                      )).toList(),
                  onChanged: (value) {
                    setState(() {
                      tipoSelezionato = value;
                      // Reset campi quando cambia il tipo
                      mesi = null;
                      km = null;
                      descrizione = '';
                      
                      // Pre-compilazione mesi in base al tipo
                      if (value == TipoScadenza.bollo) {
                        mesi = 12; // Bollo ogni 12 mesi
                      } else if (value == TipoScadenza.assicurazione) {
                        mesi = 12; // Assicurazione ogni 12 mesi
                      } else if (value == TipoScadenza.revisione) {
                        mesi = 24; // Revisione ogni 24 mesi
                      }
                    });
                  },
                ),
                const SizedBox(height: AppSpacing.md),

                // Selezione data
                ListTile(
                  title: const Text("Data scadenza"),
                  subtitle: Text(dataScadenza == null 
                      ? "Seleziona data" 
                      : DateFormat('dd/MM/yyyy').format(dataScadenza!)),
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

                // TAGLIANDO: mostra descrizione, km e mesi
                if (tipoSelezionato == TipoScadenza.tagliando) ...[
                  TextField(
                    decoration: const InputDecoration(
                      labelText: "Descrizione manutenzione",
                      hintText: "Es: Cambio olio, Sostituzione filtri, ecc.",
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
                ] else if (tipoSelezionato == TipoScadenza.bollo) ...[
                  // BOLLO: solo mesi (pre-compilati a 12)
                  TextField(
                    decoration: const InputDecoration(
                      labelText: "Mesi validità bollo",
                      border: OutlineInputBorder(),
                      helperText: "Generalmente 12 mesi",
                    ),
                    keyboardType: TextInputType.number,
                    controller: TextEditingController(text: mesi?.toString() ?? '12'),
                    onChanged: (value) => mesi = int.tryParse(value) ?? 12,
                  ),
                ] else if (tipoSelezionato == TipoScadenza.assicurazione) ...[
                  // ASSICURAZIONE: solo mesi (pre-compilati a 12)
                  TextField(
                    decoration: const InputDecoration(
                      labelText: "Mesi copertura assicurazione",
                      border: OutlineInputBorder(),
                      helperText: "Generalmente 12 mesi",
                    ),
                    keyboardType: TextInputType.number,
                    controller: TextEditingController(text: mesi?.toString() ?? '12'),
                    onChanged: (value) => mesi = int.tryParse(value) ?? 12,
                  ),
                ] else if (tipoSelezionato == TipoScadenza.revisione) ...[
                  // REVISIONE: solo mesi (pre-compilati a 24)
                  TextField(
                    decoration: const InputDecoration(
                      labelText: "Mesi validità revisione",
                      border: OutlineInputBorder(),
                      helperText: "Generalmente 24 mesi",
                    ),
                    keyboardType: TextInputType.number,
                    controller: TextEditingController(text: mesi?.toString() ?? '24'),
                    onChanged: (value) => mesi = int.tryParse(value) ?? 24,
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
                if (targaSelezionata != null && tipoSelezionato != null && dataScadenza != null) {
                  // Per tagliando è obbligatorio indicare almeno mesi o km
                  if (tipoSelezionato == TipoScadenza.tagliando && descrizione.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Inserire descrizione per il tagliando")),
                    );
                    return;
                  }
                  
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
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Scadenza creata")),
                      );
                    }
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Errore: $e")),
                    );
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Riempire i campi obbligatori")),
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
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text("Modifica scadenza"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Selezione veicolo
                DropdownButton<String>(
                  value: targaSelezionata,
                  isExpanded: true,
                  items: provider.veicoli.map((v) => DropdownMenuItem(
                        value: v.targa,
                        child: Text(v.targa),
                      )).toList(),
                  onChanged: (value) => setState(() => targaSelezionata = value ?? scadenza.targa),
                ),
                const SizedBox(height: AppSpacing.md),
                
                // Selezione tipo scadenza
                DropdownButton<TipoScadenza>(
                  value: tipoSelezionato,
                  isExpanded: true,
                  items: TipoScadenza.values.map((t) => DropdownMenuItem(
                        value: t,
                        child: Text(t.name.toUpperCase()),
                      )).toList(),
                  onChanged: (value) => setState(() => tipoSelezionato = value ?? scadenza.tipoScadenza),
                ),
                const SizedBox(height: AppSpacing.md),
                
                // Selezione data
                ListTile(
                  title: const Text("Data scadenza"),
                  subtitle: Text(DateFormat('dd/MM/yyyy').format(dataScadenza)),
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

                // TAGLIANDO: mostra descrizione, km e mesi
                if (tipoSelezionato == TipoScadenza.tagliando) ...[
                  TextField(
                    decoration: const InputDecoration(
                      labelText: "Descrizione manutenzione",
                      hintText: "Es: Cambio olio, Sostituzione filtri, ecc.",
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
                ] else if (tipoSelezionato == TipoScadenza.bollo) ...[
                  // BOLLO: solo mesi
                  TextField(
                    decoration: const InputDecoration(
                      labelText: "Mesi validità bollo",
                      border: OutlineInputBorder(),
                      helperText: "Generalmente 12 mesi",
                    ),
                    keyboardType: TextInputType.number,
                    controller: TextEditingController(text: mesi?.toString() ?? '12'),
                    onChanged: (value) => mesi = int.tryParse(value) ?? 12,
                  ),
                ] else if (tipoSelezionato == TipoScadenza.assicurazione) ...[
                  // ASSICURAZIONE: solo mesi
                  TextField(
                    decoration: const InputDecoration(
                      labelText: "Mesi copertura assicurazione",
                      border: OutlineInputBorder(),
                      helperText: "Generalmente 12 mesi",
                    ),
                    keyboardType: TextInputType.number,
                    controller: TextEditingController(text: mesi?.toString() ?? '12'),
                    onChanged: (value) => mesi = int.tryParse(value) ?? 12,
                  ),
                ] else if (tipoSelezionato == TipoScadenza.revisione) ...[
                  // REVISIONE: solo mesi
                  TextField(
                    decoration: const InputDecoration(
                      labelText: "Mesi validità revisione",
                      border: OutlineInputBorder(),
                      helperText: "Generalmente 24 mesi",
                    ),
                    keyboardType: TextInputType.number,
                    controller: TextEditingController(text: mesi?.toString() ?? '24'),
                    onChanged: (value) => mesi = int.tryParse(value) ?? 24,
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
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Scadenza modificata")),
                    );
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
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

  void _mostraFormChiusuraIntervento(BuildContext context, Scadenza scadenza) {
    double costo = 0;
    String dettagli = '';

    final provider = context.read<FleetProvider>();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text("Chiudi intervento"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "${scadenza.tipoScadenza.name.toUpperCase()} - ${scadenza.targa}",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: AppSpacing.md),
                const Text(
                  "Registra i dettagli dell'intervento completato:",
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  decoration: const InputDecoration(
                    labelText: "Costo intervento (€)",
                    border: OutlineInputBorder(),
                    prefixText: "€ ",
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
              onPressed: () => Navigator.pop(context),
              child: const Text("Annulla"),
            ),
            ElevatedButton(
              onPressed: () async {
                if (dettagli.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Inserire i dettagli dell'intervento")),
                  );
                  return;
                }
                
                try {
                  await provider.chiudiScadenza(
                    idScadenza: scadenza.idScadenza,
                    costo: costo,
                    dettagli: dettagli,
                  );
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Intervento completato")),
                    );
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Errore: $e")),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
              ),
              child: const Text("Completa"),
            ),
          ],
        ),
      ),
    );
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
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text("Elimina"),
          ),
        ],
      ),
    ) ?? false;
  }
}