import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:FleetManager/provider/fleet_provider.dart';
import 'package:FleetManager/models/enums/stato_veicolo.dart';
import 'package:FleetManager/core/theme/index.dart';
class NuovaPrenotazioneScreen extends StatefulWidget {
  const NuovaPrenotazioneScreen({super.key});

  @override
  State<NuovaPrenotazioneScreen> createState() =>
      _NuovaPrenotazioneScreenState();
}

class _NuovaPrenotazioneScreenState extends State<NuovaPrenotazioneScreen> {
  String? _targaSelezionata;

  // Impostiamo di default domani alle 09:00
  DateTime _inizio = DateTime.now()
      .add(const Duration(days: 1))
      .copyWith(hour: 9, minute: 0, second: 0, millisecond: 0);
  DateTime _fine = DateTime.now()
      .add(const Duration(days: 1))
      .copyWith(hour: 18, minute: 0, second: 0, millisecond: 0);

  // Helper per selezionare data e ora
  Future<void> _selectDateTime(BuildContext context, bool isStart) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: isStart ? _inizio : _fine,
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
      locale: const Locale('it', 'IT'),
    );

    if (pickedDate != null && mounted) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(isStart ? _inizio : _fine),
      );

      if (pickedTime != null) {
        setState(() {
          final selected = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
          if (isStart) {
            _inizio = selected;
            if (_fine.isBefore(_inizio)) {
              _fine = _inizio.add(const Duration(hours: 1));
            }
          } else {
            _fine = selected;
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Usiamo watch per reagire ai cambiamenti del provider (es. caricamento completato)
    final provider = context.watch<FleetProvider>();

    // Filtriamo solo i veicoli realmente disponibili nel DB
    final veicoliDisponibili = provider.veicoli
        .where((v) => v.statoVeicolo == StatoVeicolo.disponibile)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Prenota Veicolo"),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
      ),
      body: provider.isLoading
          ? const Center(
              child:
                  CircularProgressIndicator()) // Mostra caricamento se il provider sta lavorando
          : Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text("Scegli un veicolo dalla flotta:",
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),

                  // Dropdown Veicoli
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.directions_car),
                    ),
                    hint: const Text("Seleziona Veicolo"),
                    initialValue: _targaSelezionata,
                    onChanged: (val) => setState(() => _targaSelezionata = val),
                    items: veicoliDisponibili
                        .map((v) => DropdownMenuItem(
                              value: v.targa,
                              child:
                                  Text("${v.marca} ${v.modello} (${v.targa})"),
                            ))
                        .toList(),
                  ),

                  const SizedBox(height: 24),
                  const Text("Seleziona periodo:",
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),

                  // Data Inizio
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.login, color: AppColors.success),
                      title: const Text("Inizio"),
                      subtitle:
                          Text(DateFormat('dd/MM/yyyy HH:mm').format(_inizio)),
                      onTap: () => _selectDateTime(context, true),
                    ),
                  ),

                  // Data Fine
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.logout, color: AppColors.error),
                      title: const Text("Fine"),
                      subtitle:
                          Text(DateFormat('dd/MM/yyyy HH:mm').format(_fine)),
                      onTap: () => _selectDateTime(context, false),
                    ),
                  ),

                  const Spacer(),

                  // Pulsante Conferma
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppSpacing.radiusMedium)),
                    ),
                    onPressed: (_targaSelezionata == null ||
                            _fine.isBefore(_inizio))
                        ? null
                        : () async {
                            try {
                              if (provider.utenteLoggato == null) {
                                throw "Utente non loggato";
                              }

                              // 1. Troviamo il veicolo che l'utente sta cercando di prenotare
                              final veicolo = veicoliDisponibili.firstWhere(
                                  (v) => v.targa == _targaSelezionata);

                              // 2. CONTROLLO INTELLIGENTE: Il veicolo è davvero libero in quelle date?
                              // (Considerando sia altre prenotazioni che manutenzioni programmate)
                              bool disponibile = provider.isVeicoloDisponibile(
                                  veicolo.targa, _inizio, _fine);

                              if (!disponibile) {
                                // Se c'è un conflitto, fermiamo tutto qui e avvisiamo l'utente
                                if (mounted) {
                                  showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title:
                                          const Text("Veicolo non disponibile"),
                                      content: const Text(
                                          "In questo orario il veicolo è impegnato per un'altra prenotazione o per una manutenzione programmata.\n\nProva a cambiare orario o seleziona un altro mezzo."),
                                      actions: [
                                        TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context),
                                            child: const Text("HO CAPITO"))
                                      ],
                                    ),
                                  );
                                }
                                return; // Esci dalla funzione, non creare la prenotazione
                              }

                              // 3. Se il controllo passa, procediamo con la creazione
                              await provider.creaPrenotazione(
                                provider.utenteLoggato!,
                                veicolo,
                                _inizio,
                                _fine,
                              );

                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          "Richiesta inviata! In attesa di approvazione.")),
                                );
                                Navigator.pop(context);
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text("Errore: ${e.toString()}"),
                                      backgroundColor: AppColors.error),
                                );
                              }
                            }
                          },
                    child: const Text("INVIA RICHIESTA PRENOTAZIONE",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
    );
  }
}
