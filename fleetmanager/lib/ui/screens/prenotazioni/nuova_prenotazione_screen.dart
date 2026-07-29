import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fleetmanager/provider/fleet_provider.dart';
import 'package:fleetmanager/provider/impostazioni_provider.dart';
import 'package:fleetmanager/models/veicolo.dart';
import 'package:fleetmanager/models/enums/tipo_veicolo.dart';
import 'package:fleetmanager/core/theme/index.dart';

class NuovaPrenotazioneScreen extends StatefulWidget {
  const NuovaPrenotazioneScreen({super.key});

  @override
  State<NuovaPrenotazioneScreen> createState() =>
      _NuovaPrenotazioneScreenState();
}

class _NuovaPrenotazioneScreenState extends State<NuovaPrenotazioneScreen> {
  String? _targaSelezionata;
  bool _soloDisponibili = true;

  DateTime _inizio = DateTime.now()
      .add(const Duration(days: 1))
      .copyWith(hour: 9, minute: 0, second: 0, millisecond: 0);
  DateTime _fine = DateTime.now()
      .add(const Duration(days: 1))
      .copyWith(hour: 18, minute: 0, second: 0, millisecond: 0);

  Future<void> _selectDateTime(bool isStart) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: isStart ? _inizio : _fine,
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
      locale: const Locale('it', 'IT'),
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      cancelText: 'Annulla',
      confirmText: 'Conferma data',
      helpText: isStart ? 'Inizio prenotazione' : 'Fine prenotazione',
      builder: _buildDatePickerTheme,
    );

    if (pickedDate != null && mounted) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(isStart ? _inizio : _fine),
        cancelText: 'Annulla',
        confirmText: 'Conferma ora',
        helpText: isStart ? 'Ora di ritiro' : 'Ora di riconsegna',
        builder: _buildTimePickerTheme,
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
          // Reset selezione se il veicolo scelto non è più disponibile
          if (_targaSelezionata != null) {
            final provider = context.read<FleetProvider>();
            if (!provider.isVeicoloDisponibile(
                _targaSelezionata!, _inizio, _fine)) {
              _targaSelezionata = null;
            }
          }
        });
      }
    }
  }

  Widget _buildDatePickerTheme(BuildContext context, Widget? child) {
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(
        colorScheme: theme.colorScheme.copyWith(
          primary: AppColors.primary,
          onPrimary: AppColors.white,
          surface: AppColors.white,
          onSurface: AppColors.textPrimary,
        ),
        dialogTheme: DialogThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
          ),
        ),
        datePickerTheme: DatePickerThemeData(
          backgroundColor: AppColors.white,
          headerBackgroundColor: AppColors.primary,
          headerForegroundColor: AppColors.white,
          headerHelpStyle: AppTextStyles.labelMedium.copyWith(
            color: AppColors.white.withValues(alpha: 0.78),
            fontWeight: FontWeight.w700,
          ),
          headerHeadlineStyle: AppTextStyles.headlineMedium.copyWith(
            color: AppColors.white,
            fontWeight: FontWeight.w800,
          ),
          dayForegroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return AppColors.white;
            if (states.contains(WidgetState.disabled)) return AppColors.grey400;
            return AppColors.textPrimary;
          }),
          dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AppColors.primary;
            }
            return Colors.transparent;
          }),
          todayForegroundColor:
              WidgetStateProperty.all<Color>(AppColors.primary),
          todayBorder: const BorderSide(color: AppColors.primary, width: 1.2),
          cancelButtonStyle: AppButtonStyles.text(color: AppColors.grey700),
          confirmButtonStyle: AppButtonStyles.elevated(),
        ),
      ),
      child: child ?? const SizedBox.shrink(),
    );
  }

  Widget _buildTimePickerTheme(BuildContext context, Widget? child) {
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(
        colorScheme: theme.colorScheme.copyWith(
          primary: AppColors.primary,
          onPrimary: AppColors.white,
          surface: AppColors.white,
          onSurface: AppColors.textPrimary,
        ),
        dialogTheme: DialogThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
          ),
        ),
        timePickerTheme: TimePickerThemeData(
          backgroundColor: AppColors.white,
          hourMinuteColor: AppColors.primary.withValues(alpha: 0.08),
          hourMinuteTextColor: AppColors.primary,
          dayPeriodColor: AppColors.primary.withValues(alpha: 0.08),
          dayPeriodTextColor: AppColors.primary,
          dialHandColor: AppColors.primary,
          dialBackgroundColor: AppColors.grey100,
          entryModeIconColor: AppColors.primary,
          cancelButtonStyle: AppButtonStyles.text(color: AppColors.grey700),
          confirmButtonStyle: AppButtonStyles.elevated(),
        ),
      ),
      child: child ?? const SizedBox.shrink(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FleetProvider>();
    final veicoli = provider.veicoli;

    final veicoliFiltrati = _soloDisponibili
        ? veicoli
            .where(
                (v) => provider.isVeicoloDisponibile(v.targa, _inizio, _fine))
            .toList()
        : veicoli;

    final veicoloSelezionato = _targaSelezionata != null
        ? veicoli.cast<Veicolo?>().firstWhere(
            (v) => v!.targa == _targaSelezionata,
            orElse: () => null)
        : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Prenota Veicolo"),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Header periodo
                Container(
                  color: AppColors.white,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Seleziona il periodo:",
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _buildDateChip(
                              icon: Icons.login,
                              color: AppColors.success,
                              label: "Inizio",
                              value:
                                  DateFormat('dd/MM/yy HH:mm').format(_inizio),
                              onTap: () => _selectDateTime(true),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildDateChip(
                              icon: Icons.logout,
                              color: AppColors.error,
                              label: "Fine",
                              value: DateFormat('dd/MM/yy HH:mm').format(_fine),
                              onTap: () => _selectDateTime(false),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "${veicoliFiltrati.length} veicoli mostrati",
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.grey600),
                          ),
                          Row(
                            children: [
                              const Text("Solo disponibili",
                                  style: TextStyle(fontSize: 12)),
                              const SizedBox(width: 4),
                              Switch(
                                value: _soloDisponibili,
                                activeThumbColor: AppColors.success,
                                onChanged: (v) {
                                  setState(() {
                                    _soloDisponibili = v;
                                    if (_targaSelezionata != null && v) {
                                      final ok = provider.isVeicoloDisponibile(
                                          _targaSelezionata!, _inizio, _fine);
                                      if (!ok) _targaSelezionata = null;
                                    }
                                  });
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                // Lista veicoli
                Expanded(
                  child: veicoliFiltrati.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          itemCount: veicoliFiltrati.length,
                          itemBuilder: (context, index) {
                            final v = veicoliFiltrati[index];
                            final disponibile = provider.isVeicoloDisponibile(
                                v.targa, _inizio, _fine);
                            final isSelected = _targaSelezionata == v.targa;
                            return _buildVehicleRow(
                                v, disponibile, isSelected, provider);
                          },
                        ),
                ),

                // Bottom bar con veicolo scelto e bottone conferma
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 8,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (veicoloSelezionato != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle,
                                  color: AppColors.success, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                "${veicoloSelezionato.marca} ${veicoloSelezionato.modello} (${veicoloSelezionato.targa})",
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.success),
                              ),
                            ],
                          ),
                        ),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: (_targaSelezionata == null ||
                                  _fine.isBefore(_inizio))
                              ? null
                              : () => _confermaPrenotazione(provider),
                          child: const Text("INVIA RICHIESTA PRENOTAZIONE"),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildDateChip({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return OutlinedButton(
      onPressed: onTap,
      style: AppButtonStyles.outlined(color: color).copyWith(
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTextStyles.labelSmall),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.edit_calendar_outlined, size: 14),
        ],
      ),
    );
  }

  Widget _buildVehicleRow(
      Veicolo v, bool disponibile, bool isSelected, FleetProvider provider) {
    final color = disponibile ? AppColors.success : AppColors.error;

    return Card(
      elevation: isSelected ? 3 : 1,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusDefault),
        side: isSelected
            ? const BorderSide(color: AppColors.primary, width: 2)
            : BorderSide(
                color: disponibile
                    ? Colors.transparent
                    : AppColors.error.withValues(alpha: 0.3),
                width: 1),
      ),
      child: ListTile(
        onTap: disponibile
            ? () => setState(() => _targaSelezionata = v.targa)
            : null,
        leading: Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
          ),
          child: Icon(
            v.tipoVeicolo == TipoVeicolo.furgone
                ? Icons.local_shipping
                : Icons.directions_car,
            color: color,
          ),
        ),
        title: Text(
          "${v.marca} ${v.modello}",
          style: TextStyle(
              fontWeight: FontWeight.bold,
              color: disponibile ? Colors.black87 : AppColors.grey500),
        ),
        subtitle: Text(
          "Targa: ${v.targa} • ${v.km} km",
          style: TextStyle(color: disponibile ? null : AppColors.grey400),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(AppSpacing.radiusDefault),
              ),
              child: Text(
                disponibile ? "LIBERO" : "OCCUPATO",
                style: const TextStyle(
                    fontSize: 9,
                    color: AppColors.white,
                    fontWeight: FontWeight.bold),
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: 6),
              const Icon(Icons.check_circle,
                  color: AppColors.primary, size: 20),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.search_off, size: 60, color: AppColors.grey400),
          const SizedBox(height: 16),
          const Text("Nessun veicolo disponibile in questo periodo",
              style: TextStyle(color: AppColors.grey600, fontSize: 15),
              textAlign: TextAlign.center),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => setState(() => _soloDisponibili = false),
            child: const Text("Mostra tutti i veicoli"),
          ),
        ],
      ),
    );
  }

  Future<void> _confermaPrenotazione(FleetProvider provider) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    try {
      if (provider.utenteLoggato == null) throw "Utente non loggato";

      final veicolo =
          provider.veicoli.firstWhere((v) => v.targa == _targaSelezionata);

      final disponibile =
          provider.isVeicoloDisponibile(veicolo.targa, _inizio, _fine);

      if (!disponibile) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: const Text("Veicolo non disponibile"),
              content: const Text(
                  "In questo orario il veicolo è impegnato.\n\nProva a cambiare orario o seleziona un altro mezzo."),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text("HO CAPITO"))
              ],
            ),
          );
        }
        return;
      }

      final imp = context.read<ImpostazioniProvider>();
      await imp.ensureLoaded();
      await provider.creaPrenotazione(
        provider.utenteLoggato!,
        veicolo,
        _inizio,
        _fine,
        autoConferma: !imp.approvazioneRichiesta,
        checkupObbligatorio: imp.checkupObbligatorio,
      );

      if (mounted) {
        final msg = imp.approvazioneRichiesta
            ? "Richiesta inviata! In attesa di approvazione."
            : "Prenotazione confermata automaticamente!";
        messenger.showSnackBar(SnackBar(content: Text(msg)));
        navigator.pop();
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
              content: Text("Errore: ${e.toString()}"),
              backgroundColor: AppColors.error),
        );
      }
    }
  }
}
