import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../provider/fleet_provider.dart';
import '../../models/prenotazione.dart';
import '../../models/enums/tipo_prenotazione.dart';
import '../../models/enums/stato_prenotazione.dart';
import '../../models/enums/stato_veicolo.dart';

class NuovaPrenotazioneScreen extends StatefulWidget {
  @override
  _NuovaPrenotazioneScreenState createState() => _NuovaPrenotazioneScreenState();
}

class _NuovaPrenotazioneScreenState extends State<NuovaPrenotazioneScreen> {
  String? _targaSelezionata;
  DateTime _inizio = DateTime.now().add(Duration(days: 1)).copyWith(hour: 9, minute: 0);
  DateTime _fine = DateTime.now().add(Duration(days: 1)).copyWith(hour: 18, minute: 0);

  Future<void> _selectDateTime(BuildContext context, bool isStart) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: isStart ? _inizio : _fine,
      firstDate: isStart ? DateTime.now() : _inizio,
      lastDate: DateTime(2030),
      locale: const Locale('it', 'IT'),
    );
    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(isStart ? _inizio : _fine),
        builder: (BuildContext context, Widget? child) {
          return Localizations.override(
            context: context,
            locale: const Locale('it', 'IT'),
            child: child,
          );
        },
      );
      if (pickedTime != null) {
        final DateTime selectedDateTime = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          pickedTime.hour,
          pickedTime.minute,
        );
        setState(() {
          if (isStart) {
            _inizio = selectedDateTime;
            if (_fine.isBefore(_inizio)) {
              _fine = _inizio.add(Duration(hours: 1));
            }
          } else {
            _fine = selectedDateTime;
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FleetProvider>(context);
    final veicoliDisponibili = provider.veicoli.where((v) => v.statoVeicolo == StatoVeicolo.disponibile).toList();
    
    return Scaffold(
      appBar: AppBar(title: Text("Prenota Veicolo")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Menu a tendina Veicoli disponibili
            DropdownButtonFormField<String>(
              decoration: InputDecoration(labelText: "Seleziona Veicolo Disponibile"),
              value: _targaSelezionata,
              onChanged: (val) => setState(() => _targaSelezionata = val),
              items: veicoliDisponibili.map((v) => 
                DropdownMenuItem(value: v.targa, child: Text("${v.marca} ${v.modello} (${v.targa})"))
              ).toList(),
              validator: (value) => value == null ? 'Seleziona un veicolo' : null,
            ),
            
            SizedBox(height: 20),
            
            // Selettore Data e Ora Inizio
            ListTile(
              title: Text("Inizio: ${DateFormat('dd/MM/yyyy HH:mm').format(_inizio)}"),
              trailing: Icon(Icons.calendar_today),
              onTap: () => _selectDateTime(context, true),
            ),
            
            // Selettore Data e Ora Fine
            ListTile(
              title: Text("Fine: ${DateFormat('dd/MM/yyyy HH:mm').format(_fine)}"),
              trailing: Icon(Icons.calendar_today),
              onTap: () => _selectDateTime(context, false),
            ),
            
            Spacer(),
            
            ElevatedButton(
              onPressed: _targaSelezionata == null || _fine.isBefore(_inizio)
                  ? null
                  : () async {
                      try {
                        await provider.creaPrenotazione(
                          provider.utenteLoggato!,
                          veicoliDisponibili.firstWhere((v) => v.targa == _targaSelezionata!),
                          _inizio,
                          _fine,
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Prenotazione creata con successo!")),
                        );
                        Navigator.pop(context);
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Errore: ${e.toString()}")),
                        );
                      }
                    },
              child: const Text("CONFERMA PRENOTAZIONE"),
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
            )
          ],
        ),
      ),
    );
  }
}