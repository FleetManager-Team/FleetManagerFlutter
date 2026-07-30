import 'dart:math' as math;

import 'package:fleetmanager/core/theme/index.dart';
import 'package:fleetmanager/models/enums/ruolo_utente.dart';
import 'package:fleetmanager/models/enums/tipo_veicolo.dart';
import 'package:fleetmanager/models/prenotazione.dart';
import 'package:fleetmanager/models/restituzione.dart';
import 'package:fleetmanager/models/utente.dart';
import 'package:fleetmanager/models/veicolo.dart';
import 'package:fleetmanager/provider/fleet_provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

enum _CostCategory { carburante, pedaggi }

enum _CostSort { totaleDesc, carburanteDesc, pedaggiDesc, nomeAsc }

enum _PeriodPreset { today, week, month, quarter, year, custom }

class GraficiCostiScreen extends StatefulWidget {
  final String periodLabel;
  final double carburante;
  final double pedaggi;
  final int movimenti;
  final List<CostChartAmount> driverData;
  final List<CostChartAmount> vehicleData;
  final List<CostChartDay> dailyData;
  final List<CostChartAmount> weekdayData;
  final DateTimeRange? initialRange;
  final Set<int>? initialDriverIds;
  final Set<String>? initialVehiclePlates;
  final TipoVeicolo? initialVehicleType;
  final Set<String>? initialCategories;
  final String? initialSort;
  final String? initialPeriodPreset;

  const GraficiCostiScreen({
    super.key,
    required this.periodLabel,
    required this.carburante,
    required this.pedaggi,
    required this.movimenti,
    required this.driverData,
    required this.vehicleData,
    required this.dailyData,
    required this.weekdayData,
    this.initialRange,
    this.initialDriverIds,
    this.initialVehiclePlates,
    this.initialVehicleType,
    this.initialCategories,
    this.initialSort,
    this.initialPeriodPreset,
  });

  @override
  State<GraficiCostiScreen> createState() => _GraficiCostiScreenState();
}

class _GraficiCostiScreenState extends State<GraficiCostiScreen> {
  final _fullDate = DateFormat('dd/MM/yyyy');

  late DateTimeRange _rangeSelezionato;
  late final Set<_CostCategory> _categorie;
  late _PeriodPreset _periodPreset;
  late Set<int>? _driverSelezionati;
  late Set<String>? _targheSelezionate;
  late TipoVeicolo? _tipoVeicoloSelezionato;
  late _CostSort _ordinamento;
  bool _filtriEspansi = false;

  @override
  void initState() {
    super.initState();

    _rangeSelezionato = widget.initialRange ??
        DateTimeRange(
          start: DateTime.now().subtract(const Duration(days: 30)),
          end: DateTime.now(),
        );
    _categorie = _categoriesFromNames(widget.initialCategories);
    _periodPreset = _periodPresetFromName(widget.initialPeriodPreset);
    _driverSelezionati = {...?widget.initialDriverIds};
    _targheSelezionate = {...?widget.initialVehiclePlates};
    _tipoVeicoloSelezionato = widget.initialVehicleType;
    _ordinamento = _sortFromName(widget.initialSort);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FleetProvider>();
    final records = _buildRecords(provider);
    final filteredRecords = _filterRecords(records);
    final summaries = _buildSummaries(filteredRecords);
    final vehicleSummaries = _buildVehicleSummaries(filteredRecords);
    final totals = _CostTotals.fromSummaries(summaries);

    return _GraficiCostiDashboardContent(
      periodLabel:
          '${_fullDate.format(_rangeSelezionato.start)} - ${_fullDate.format(_rangeSelezionato.end)}',
      carburante: totals.carburante,
      pedaggi: totals.pedaggi,
      movimenti: filteredRecords.length,
      driverData: summaries
          .map(
            (summary) => CostChartAmount(
              label: summary.nomeDriver.split(' ').first,
              subtitle: summary.nomeDriver,
              carburante: summary.carburante,
              pedaggi: summary.pedaggi,
            ),
          )
          .toList(),
      vehicleData: vehicleSummaries
          .map(
            (summary) => CostChartAmount(
              label: summary.targa,
              subtitle: summary.vehicleLabel,
              carburante: summary.carburante,
              pedaggi: summary.pedaggi,
            ),
          )
          .toList(),
      dailyData: _buildDailyChartData(filteredRecords),
      weekdayData: _buildWeekdayChartData(filteredRecords),
      filters: _buildFilters(provider),
    );
  }

  Set<_CostCategory> _categoriesFromNames(Set<String>? names) {
    if (names == null) {
      return {_CostCategory.carburante, _CostCategory.pedaggi};
    }

    return {
      if (names.contains(_CostCategory.carburante.name))
        _CostCategory.carburante,
      if (names.contains(_CostCategory.pedaggi.name)) _CostCategory.pedaggi,
    };
  }

  _PeriodPreset _periodPresetFromName(String? name) {
    return _PeriodPreset.values.firstWhere(
      (preset) => preset.name == name,
      orElse: () => _PeriodPreset.month,
    );
  }

  _CostSort _sortFromName(String? name) {
    return _CostSort.values.firstWhere(
      (sort) => sort.name == name,
      orElse: () => _CostSort.totaleDesc,
    );
  }

  Widget _buildFilters(FleetProvider provider) {
    final drivers = provider.utenti
        .where((u) => u.ruoloUtente == RuoloUtente.driver)
        .toList()
      ..sort((a, b) => _driverName(a).compareTo(_driverName(b)));

    final veicoli = [...provider.veicoli]
      ..sort((a, b) => a.targa.compareTo(b.targa));

    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tune_rounded, color: AppColors.primaryDark),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Filtri analisi',
                        style: AppTextStyles.headlineSmall),
                    if (!_filtriEspansi) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        _activeFiltersSummary(drivers, veicoli),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.grey600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Pulisci filtri',
                onPressed: _resetFilters,
                icon: const Icon(Icons.filter_alt_off_rounded),
              ),
              IconButton(
                tooltip: _filtriEspansi ? 'Chiudi filtri' : 'Apri filtri',
                onPressed: () =>
                    setState(() => _filtriEspansi = !_filtriEspansi),
                icon: Icon(
                  _filtriEspansi
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                ),
              ),
            ],
          ),
          if (_filtriEspansi) ...[
            const SizedBox(height: AppSpacing.md),
            _filterBlockTitle('Periodo'),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                _periodChip(_PeriodPreset.today),
                _periodChip(_PeriodPreset.week),
                _periodChip(_PeriodPreset.month),
                _periodChip(_PeriodPreset.quarter),
                _periodChip(_PeriodPreset.year),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            _selectionTile(
              label: 'Periodo personalizzato',
              icon: Icons.date_range_rounded,
              value:
                  '${_fullDate.format(_rangeSelezionato.start)} - ${_fullDate.format(_rangeSelezionato.end)}',
              isActive: _periodPreset == _PeriodPreset.custom,
              onTap: _pickDateRange,
            ),
            const SizedBox(height: AppSpacing.lg),
            _filterBlockTitle('Categorie costo'),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                _filterChip(
                  label: 'Carburante',
                  icon: Icons.local_gas_station,
                  selected: _categorie.contains(_CostCategory.carburante),
                  activeColor: AppColors.secondary,
                  onSelected: (selected) =>
                      _toggleCategory(_CostCategory.carburante, selected),
                ),
                _filterChip(
                  label: 'Pedaggi',
                  icon: Icons.route_rounded,
                  selected: _categorie.contains(_CostCategory.pedaggi),
                  activeColor: AppColors.primaryLight,
                  onSelected: (selected) =>
                      _toggleCategory(_CostCategory.pedaggi, selected),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            _filterBlockTitle('Ambito analisi'),
            const SizedBox(height: AppSpacing.sm),
            _buildFilterGrid(
              children: [
                _selectionTile(
                  label: 'Driver',
                  icon: Icons.person_outline,
                  value: _selectedDriversLabel(drivers),
                  onTap: () => _showDriverPicker(drivers),
                ),
                _selectionTile(
                  label: 'Veicoli',
                  icon: Icons.directions_car_outlined,
                  value: _selectedVehicleLabel(veicoli),
                  onTap: () => _showVehiclePicker(veicoli),
                ),
                _selectionTile(
                  label: 'Tipo veicolo',
                  icon: Icons.category_outlined,
                  value: _tipoVeicoloSelezionato == null
                      ? 'Tutti'
                      : _enumLabel(_tipoVeicoloSelezionato!.name),
                  onTap: () => _showSingleSelectMenu<TipoVeicolo>(
                    includeAll: true,
                    currentValue: _tipoVeicoloSelezionato,
                    entries: TipoVeicolo.values
                        .map((tipo) =>
                            _SelectOption(tipo, _enumLabel(tipo.name)))
                        .toList(),
                    onSelected: (value) =>
                        setState(() => _tipoVeicoloSelezionato = value),
                  ),
                ),
                _selectionTile(
                  label: 'Ordinamento',
                  icon: Icons.sort_rounded,
                  value: _sortLabel(_ordinamento),
                  onTap: () => _showSingleSelectMenu<_CostSort>(
                    currentValue: _ordinamento,
                    entries: _CostSort.values
                        .map((sort) => _SelectOption(sort, _sortLabel(sort)))
                        .toList(),
                    onSelected: (value) {
                      if (value != null) {
                        setState(() => _ordinamento = value);
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _sectionCard({required Widget child}) {
    final borderRadius = BorderRadius.circular(AppSpacing.radiusLarge);

    return Material(
      color: AppColors.white,
      borderRadius: borderRadius,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: borderRadius,
          border: Border.all(color: AppColors.grey200),
          boxShadow: [
            BoxShadow(
              color: AppColors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: child,
      ),
    );
  }

  Widget _filterBlockTitle(String label) {
    return Text(
      label.toUpperCase(),
      style: AppTextStyles.overline.copyWith(
        color: AppColors.grey500,
        letterSpacing: 1.1,
      ),
    );
  }

  Widget _selectionTile({
    required String label,
    required IconData icon,
    required String value,
    required VoidCallback onTap,
    bool isActive = false,
  }) {
    return Material(
      color: isActive
          ? AppColors.primaryLight.withValues(alpha: 0.08)
          : AppColors.white,
      borderRadius: BorderRadius.circular(AppSpacing.radiusDefault),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusDefault),
        child: Container(
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            border: Border.all(
              color: isActive ? AppColors.primaryLight : AppColors.border,
              width: isActive ? 1.5 : 1,
            ),
            borderRadius: BorderRadius.circular(AppSpacing.radiusDefault),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isActive ? AppColors.primaryDark : AppColors.grey600,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.grey600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: isActive
                            ? AppColors.primaryDark
                            : AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.keyboard_arrow_down_rounded,
                  color: AppColors.grey500),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterGrid({required List<Widget> children}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 760 ? 2 : 1;
        return _responsiveRows(children: children, columns: columns);
      },
    );
  }

  Widget _responsiveRows({
    required List<Widget> children,
    required int columns,
  }) {
    final rows = <Widget>[];

    for (var index = 0; index < children.length; index += columns) {
      final rowChildren = children.skip(index).take(columns).toList();
      rows.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < rowChildren.length; i++) ...[
              Expanded(child: rowChildren[i]),
              if (i < rowChildren.length - 1)
                const SizedBox(width: AppSpacing.md),
            ],
            if (rowChildren.length < columns)
              for (var i = rowChildren.length; i < columns; i++) ...[
                if (rowChildren.isNotEmpty || i > 0)
                  const SizedBox(width: AppSpacing.md),
                const Expanded(child: SizedBox.shrink()),
              ],
          ],
        ),
      );

      if (index + columns < children.length) {
        rows.add(const SizedBox(height: AppSpacing.md));
      }
    }

    return Column(children: rows);
  }

  Widget _periodChip(_PeriodPreset preset) {
    final selected = _periodPreset == preset;

    return ChoiceChip(
      label: Text(_periodPresetLabel(preset)),
      avatar: Icon(
        Icons.calendar_today_outlined,
        size: 16,
        color: AppButtonStyles.chipForeground(selected),
      ),
      selected: selected,
      color: AppButtonStyles.chipColor(selected),
      selectedColor: AppButtonStyles.chipBackground(selected),
      backgroundColor: AppButtonStyles.chipBackground(false),
      labelStyle: AppButtonStyles.chipLabelStyle(selected),
      side: AppButtonStyles.chipSide(selected),
      onSelected: (_) => _setPreset(preset),
      shape: AppButtonStyles.chipShape,
      padding: AppButtonStyles.chipPadding,
    );
  }

  String _periodPresetLabel(_PeriodPreset preset) {
    switch (preset) {
      case _PeriodPreset.today:
        return 'Oggi';
      case _PeriodPreset.week:
        return '7 giorni';
      case _PeriodPreset.month:
        return '30 giorni';
      case _PeriodPreset.quarter:
        return 'Trimestre';
      case _PeriodPreset.year:
        return 'Anno';
      case _PeriodPreset.custom:
        return 'Personalizzato';
    }
  }

  int _periodPresetDays(_PeriodPreset preset) {
    switch (preset) {
      case _PeriodPreset.today:
      case _PeriodPreset.custom:
        return 0;
      case _PeriodPreset.week:
        return 7;
      case _PeriodPreset.month:
        return 30;
      case _PeriodPreset.quarter:
        return 90;
      case _PeriodPreset.year:
        return 365;
    }
  }

  Widget _filterChip({
    required String label,
    required IconData icon,
    required bool selected,
    required ValueChanged<bool> onSelected,
    required Color activeColor,
  }) {
    return FilterChip(
      avatar: Icon(
        icon,
        size: 18,
        color: AppButtonStyles.chipForeground(selected, color: activeColor),
      ),
      label: Text(label),
      selected: selected,
      color: AppButtonStyles.chipColor(selected, color: activeColor),
      selectedColor:
          AppButtonStyles.chipBackground(selected, color: activeColor),
      checkmarkColor: AppColors.white,
      labelStyle: AppButtonStyles.chipLabelStyle(selected, color: activeColor),
      side: AppButtonStyles.chipSide(selected, color: activeColor),
      onSelected: onSelected,
      shape: AppButtonStyles.chipShape,
      padding: AppButtonStyles.chipPadding,
    );
  }

  String _selectedVehicleLabel(List<Veicolo> veicoli) {
    final targheSelezionate = _targheSelezionateSicure;
    if (targheSelezionate.isEmpty) return 'Tutti i veicoli';

    final selectedLabels = veicoli
        .where((veicolo) => targheSelezionate.contains(veicolo.targa))
        .map((veicolo) => veicolo.targa)
        .toList();

    if (selectedLabels.isEmpty) return '${targheSelezionate.length} veicoli';
    if (selectedLabels.length == 1) return selectedLabels.first;
    if (selectedLabels.length == 2) return selectedLabels.join(', ');
    return '${selectedLabels.length} veicoli selezionati';
  }

  String _activeFiltersSummary(List<Utente> drivers, List<Veicolo> veicoli) {
    final period = _periodPreset == _PeriodPreset.custom
        ? '${_fullDate.format(_rangeSelezionato.start)} - ${_fullDate.format(_rangeSelezionato.end)}'
        : _periodPresetLabel(_periodPreset);
    final categories = _categorie.length == 2
        ? 'Tutte le categorie'
        : _categorie.isEmpty
            ? 'Nessuna categoria'
            : _categorie.contains(_CostCategory.carburante)
                ? 'Carburante'
                : 'Pedaggi';

    return '$period - $categories - ${_selectedDriversLabel(drivers)} - ${_selectedVehicleLabel(veicoli)}';
  }

  List<_CostRecord> _buildRecords(FleetProvider provider) {
    return provider.restituzioni.map((restituzione) {
      Prenotazione? prenotazione;
      Utente? driver;
      Veicolo? veicolo;

      try {
        prenotazione = provider.prenotazioni.firstWhere(
          (p) => p.idPrenotazione == restituzione.idPrenotazione,
        );
      } catch (_) {}

      if (prenotazione != null) {
        try {
          driver = provider.utenti.firstWhere(
            (u) => u.idUtente == prenotazione!.idUtente,
          );
        } catch (_) {}

        try {
          veicolo = provider.veicoli.firstWhere(
            (v) => v.targa == prenotazione!.targa,
          );
        } catch (_) {}
      }

      return _CostRecord(
        restituzione: restituzione,
        prenotazione: prenotazione,
        driver: driver,
        veicolo: veicolo,
      );
    }).toList();
  }

  List<_CostRecord> _filterRecords(List<_CostRecord> records) {
    final endOfDay = DateTime(
      _rangeSelezionato.end.year,
      _rangeSelezionato.end.month,
      _rangeSelezionato.end.day,
      23,
      59,
      59,
    );

    return records.where((record) {
      final date = record.restituzione.dataRestituzione;
      final inRange =
          !date.isBefore(_rangeSelezionato.start) && !date.isAfter(endOfDay);
      if (!inRange) return false;

      if (_categorie.isEmpty || _visibleTotal(record) <= 0) return false;
      final driverSelezionati = _driverSelezionatiSicuri;
      if (driverSelezionati.isNotEmpty &&
          !driverSelezionati.contains(record.prenotazione?.idUtente)) {
        return false;
      }
      final targheSelezionate = _targheSelezionateSicure;
      if (targheSelezionate.isNotEmpty &&
          !targheSelezionate.contains(record.targa)) {
        return false;
      }
      if (_tipoVeicoloSelezionato != null &&
          record.veicolo?.tipoVeicolo != _tipoVeicoloSelezionato) {
        return false;
      }
      return true;
    }).toList();
  }

  List<_DriverCostSummary> _buildSummaries(List<_CostRecord> records) {
    final Map<int, _DriverCostSummary> byDriver = {};

    for (final record in records) {
      final key = record.prenotazione?.idUtente ?? -1;
      byDriver.putIfAbsent(
        key,
        () => _DriverCostSummary(
          driverId: key,
          nomeDriver: record.driverName,
        ),
      );
      byDriver[key]!.add(record, _categorie);
    }

    final summaries = byDriver.values.toList();

    switch (_ordinamento) {
      case _CostSort.totaleDesc:
        summaries.sort((a, b) => b.totaleVisibile.compareTo(a.totaleVisibile));
        break;
      case _CostSort.carburanteDesc:
        summaries.sort((a, b) => b.carburante.compareTo(a.carburante));
        break;
      case _CostSort.pedaggiDesc:
        summaries.sort((a, b) => b.pedaggi.compareTo(a.pedaggi));
        break;
      case _CostSort.nomeAsc:
        summaries.sort((a, b) => a.nomeDriver.compareTo(b.nomeDriver));
        break;
    }

    return summaries;
  }

  List<_VehicleCostSummary> _buildVehicleSummaries(List<_CostRecord> records) {
    final Map<String, _VehicleCostSummary> byVehicle = {};

    for (final record in records) {
      final key = record.targa;
      byVehicle.putIfAbsent(
        key,
        () => _VehicleCostSummary(
          targa: key,
          vehicleLabel: record.vehicleLabel,
        ),
      );
      byVehicle[key]!.add(record, _categorie);
    }

    final summaries = byVehicle.values.toList();

    switch (_ordinamento) {
      case _CostSort.totaleDesc:
        summaries.sort((a, b) => b.totaleVisibile.compareTo(a.totaleVisibile));
        break;
      case _CostSort.carburanteDesc:
        summaries.sort((a, b) => b.carburante.compareTo(a.carburante));
        break;
      case _CostSort.pedaggiDesc:
        summaries.sort((a, b) => b.pedaggi.compareTo(a.pedaggi));
        break;
      case _CostSort.nomeAsc:
        summaries.sort((a, b) => a.targa.compareTo(b.targa));
        break;
    }

    return summaries;
  }

  List<CostChartDay> _buildDailyChartData(List<_CostRecord> records) {
    final byDay = <DateTime, _ChartAmountAccumulator>{};

    for (final record in records) {
      final date = record.restituzione.dataRestituzione;
      final key = DateTime(date.year, date.month, date.day);
      final accumulator = byDay.putIfAbsent(key, _ChartAmountAccumulator.new);
      accumulator.add(record, _categorie);
    }

    final days = byDay.keys.toList()..sort();

    return days
        .map(
          (day) => CostChartDay(
            date: day,
            carburante: byDay[day]!.carburante,
            pedaggi: byDay[day]!.pedaggi,
          ),
        )
        .toList();
  }

  List<CostChartAmount> _buildWeekdayChartData(List<_CostRecord> records) {
    const labels = ['Lun', 'Mar', 'Mer', 'Gio', 'Ven', 'Sab', 'Dom'];
    final byWeekday = List.generate(7, (_) => _ChartAmountAccumulator());

    for (final record in records) {
      final weekday = record.restituzione.dataRestituzione.weekday - 1;
      if (weekday < 0 || weekday >= byWeekday.length) continue;
      byWeekday[weekday].add(record, _categorie);
    }

    return List.generate(
      labels.length,
      (index) => CostChartAmount(
        label: labels[index],
        carburante: byWeekday[index].carburante,
        pedaggi: byWeekday[index].pedaggi,
      ),
    );
  }

  void _toggleCategory(_CostCategory category, bool selected) {
    setState(() {
      if (selected) {
        _categorie.add(category);
      } else {
        _categorie.remove(category);
      }
    });
  }

  void _setPreset(_PeriodPreset preset) {
    final now = DateTime.now();
    final days = _periodPresetDays(preset);
    final start = days == 0
        ? DateTime(now.year, now.month, now.day)
        : now.subtract(Duration(days: days));

    setState(() {
      _periodPreset = preset;
      _rangeSelezionato = DateTimeRange(start: start, end: now);
    });
  }

  Future<void> _pickDateRange() async {
    DateTime start = _rangeSelezionato.start;
    DateTime end = _rangeSelezionato.end;

    final picked = await showDialog<DateTimeRange>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> pickDate({required bool isStart}) async {
              final selected = await _pickSingleDate(
                initialDate: isStart ? start : end,
                firstDate: DateTime(DateTime.now().year - 5),
                lastDate: DateTime.now().add(const Duration(days: 1)),
              );

              if (selected == null) return;

              setDialogState(() {
                if (isStart) {
                  start = selected;
                  if (start.isAfter(end)) end = start;
                } else {
                  end = selected;
                  if (end.isBefore(start)) start = end;
                }
              });
            }

            return AlertDialog(
              title: const Text('Periodo personalizzato'),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _datePickerRow(
                      label: 'Dal',
                      value: _fullDate.format(start),
                      onTap: () => pickDate(isStart: true),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _datePickerRow(
                      label: 'Al',
                      value: _fullDate.format(end),
                      onTap: () => pickDate(isStart: false),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('ANNULLA'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(
                    dialogContext,
                    DateTimeRange(start: start, end: end),
                  ),
                  child: const Text('APPLICA'),
                ),
              ],
            );
          },
        );
      },
    );

    if (picked != null) {
      setState(() {
        _periodPreset = _PeriodPreset.custom;
        _rangeSelezionato = picked;
      });
    }
  }

  Future<DateTime?> _pickSingleDate({
    required DateTime initialDate,
    required DateTime firstDate,
    required DateTime lastDate,
  }) {
    return showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      cancelText: 'Annulla',
      confirmText: 'Seleziona',
      builder: (context, child) {
        final theme = Theme.of(context);

        return Theme(
          data: theme.copyWith(
            datePickerTheme: DatePickerThemeData(
              headerBackgroundColor: AppColors.primaryDark,
              headerForegroundColor: AppColors.white,
              headerHelpStyle: AppTextStyles.labelMedium.copyWith(
                color: AppColors.white.withValues(alpha: 0.8),
              ),
              headerHeadlineStyle: AppTextStyles.headlineMedium.copyWith(
                color: AppColors.white,
              ),
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }

  Widget _datePickerRow({
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return Material(
      color: AppColors.grey50,
      borderRadius: BorderRadius.circular(AppSpacing.radiusDefault),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusDefault),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.grey200),
            borderRadius: BorderRadius.circular(AppSpacing.radiusDefault),
          ),
          child: Row(
            children: [
              const Icon(Icons.calendar_today_outlined,
                  color: AppColors.primaryDark),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.grey600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      value,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.edit_calendar_outlined,
                  color: AppColors.grey500),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showDriverPicker(List<Utente> drivers) async {
    await _showMultiSelectPicker<int>(
      title: 'Seleziona driver',
      allLabel: 'Tutti i driver',
      titleIcon: Icons.person_outline,
      selectedValues: _driverSelezionatiSicuri,
      options: drivers
          .map(
            (driver) => _MultiSelectOption<int>(
              value: driver.idUtente,
              title: _driverName(driver),
              subtitle: driver.email.isEmpty ? null : driver.email,
              icon: Icons.person_outline,
            ),
          )
          .toList(),
      onApply: (selected) {
        setState(() {
          _driverSelezionatiSicuri
            ..clear()
            ..addAll(selected);
        });
      },
    );
  }

  Future<void> _showVehiclePicker(List<Veicolo> veicoli) async {
    await _showMultiSelectPicker<String>(
      title: 'Seleziona veicoli',
      allLabel: 'Tutti i veicoli',
      titleIcon: Icons.directions_car_outlined,
      selectedValues: _targheSelezionateSicure,
      options: veicoli
          .map(
            (veicolo) => _MultiSelectOption<String>(
              value: veicolo.targa,
              title: veicolo.targa,
              subtitle: '${veicolo.marca} ${veicolo.modello}',
              icon: Icons.directions_car_outlined,
            ),
          )
          .toList(),
      onApply: (selected) {
        setState(() {
          _targheSelezionateSicure
            ..clear()
            ..addAll(selected);
        });
      },
    );
  }

  Future<void> _showMultiSelectPicker<T>({
    required String title,
    required String allLabel,
    required IconData titleIcon,
    required Set<T> selectedValues,
    required List<_MultiSelectOption<T>> options,
    required ValueChanged<Set<T>> onApply,
  }) async {
    final selected = {...selectedValues};

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(titleIcon, color: AppColors.primaryDark),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: Text(title)),
                ],
              ),
              contentPadding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                0,
              ),
              content: SizedBox(
                width: 460,
                height: math.min(
                  MediaQuery.of(context).size.height * 0.72,
                  540.0,
                ),
                child: Column(
                  children: [
                    _multiSelectRow<T>(
                      title: allLabel,
                      subtitle: 'Nessun filtro applicato',
                      icon: Icons.select_all_rounded,
                      selected: selected.isEmpty,
                      onTap: () => setDialogState(selected.clear),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    const Divider(height: 1),
                    const SizedBox(height: AppSpacing.sm),
                    Expanded(
                      child: ListView.separated(
                        itemCount: options.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: AppSpacing.sm),
                        itemBuilder: (context, index) {
                          final option = options[index];
                          final isSelected = selected.contains(option.value);

                          return _multiSelectRow<T>(
                            title: option.title,
                            subtitle: option.subtitle,
                            icon: option.icon,
                            selected: isSelected,
                            onTap: () {
                              setDialogState(() {
                                if (isSelected) {
                                  selected.remove(option.value);
                                } else {
                                  selected.add(option.value);
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('ANNULLA'),
                ),
                ElevatedButton(
                  onPressed: () {
                    onApply(selected);
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('APPLICA'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _multiSelectRow<T>({
    required String title,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
    String? subtitle,
  }) {
    return Material(
      color: selected
          ? AppColors.primaryLight.withValues(alpha: 0.08)
          : AppColors.grey50,
      borderRadius: BorderRadius.circular(AppSpacing.radiusDefault),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusDefault),
        child: Container(
          constraints: const BoxConstraints(minHeight: 62),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            border: Border.all(
              color: selected ? AppColors.primaryLight : AppColors.grey200,
              width: selected ? 1.5 : 1,
            ),
            borderRadius: BorderRadius.circular(AppSpacing.radiusDefault),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.primaryLight.withValues(alpha: 0.14)
                      : AppColors.white,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: selected ? AppColors.primaryDark : AppColors.grey500,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.titleMedium.copyWith(
                        color: selected
                            ? AppColors.primaryDark
                            : AppColors.grey900,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.grey600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                color: selected ? AppColors.primaryDark : AppColors.grey400,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showSingleSelectMenu<T>({
    required List<_SelectOption<T>> entries,
    required ValueChanged<T?> onSelected,
    T? currentValue,
    bool includeAll = false,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          contentPadding: const EdgeInsets.only(top: AppSpacing.sm),
          content: SizedBox(
            width: 420,
            height: math.min(
              MediaQuery.of(dialogContext).size.height * 0.7,
              460.0,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (includeAll)
                    _singleSelectRow<T>(
                      label: 'Tutti',
                      selected: currentValue == null,
                      onTap: () {
                        onSelected(null);
                        Navigator.pop(dialogContext);
                      },
                    ),
                  ...entries.map(
                    (entry) => _singleSelectRow<T>(
                      label: entry.label,
                      selected: entry.value == currentValue,
                      onTap: () {
                        onSelected(entry.value);
                        Navigator.pop(dialogContext);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _singleSelectRow<T>({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(
        selected ? Icons.check_circle_rounded : Icons.circle_outlined,
        color: selected ? AppColors.primaryDark : AppColors.grey400,
      ),
      title: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: onTap,
    );
  }

  void _resetFilters() {
    setState(() {
      _rangeSelezionato = DateTimeRange(
        start: DateTime.now().subtract(const Duration(days: 30)),
        end: DateTime.now(),
      );
      _categorie
        ..clear()
        ..addAll({_CostCategory.carburante, _CostCategory.pedaggi});
      _driverSelezionatiSicuri.clear();
      _targheSelezionateSicure.clear();
      _tipoVeicoloSelezionato = null;
      _ordinamento = _CostSort.totaleDesc;
      _periodPreset = _PeriodPreset.month;
    });
  }

  String _driverName(Utente user) => '${user.nome} ${user.cognome}'.trim();

  String _selectedDriversLabel(List<Utente> drivers) {
    final driverSelezionati = _driverSelezionatiSicuri;
    if (driverSelezionati.isEmpty) return 'Tutti i driver';

    final selectedNames = drivers
        .where((driver) => driverSelezionati.contains(driver.idUtente))
        .map(_driverName)
        .toList();

    if (selectedNames.isEmpty) return '${driverSelezionati.length} driver';
    if (selectedNames.length == 1) return selectedNames.first;
    if (selectedNames.length == 2) return selectedNames.join(', ');
    return '${selectedNames.length} driver selezionati';
  }

  Set<int> get _driverSelezionatiSicuri {
    return _driverSelezionati ??= <int>{};
  }

  Set<String> get _targheSelezionateSicure {
    return _targheSelezionate ??= <String>{};
  }

  String _enumLabel(String value) {
    final spaced = value.replaceAllMapped(
      RegExp(r'([a-z])([A-Z])'),
      (match) => '${match.group(1)} ${match.group(2)}',
    );
    return spaced[0].toUpperCase() + spaced.substring(1);
  }

  String _sortLabel(_CostSort sort) {
    switch (sort) {
      case _CostSort.totaleDesc:
        return 'Totale piu alto';
      case _CostSort.carburanteDesc:
        return 'Carburante piu alto';
      case _CostSort.pedaggiDesc:
        return 'Pedaggi piu alti';
      case _CostSort.nomeAsc:
        return 'Nome A-Z';
    }
  }

  double _visibleTotal(_CostRecord record) {
    double total = 0;
    if (_categorie.contains(_CostCategory.carburante)) {
      total += record.carburante;
    }
    if (_categorie.contains(_CostCategory.pedaggi)) {
      total += record.pedaggi;
    }
    return total;
  }
}

class _GraficiCostiDashboardContent extends StatelessWidget {
  static const Color _dailyTotalColor = AppColors.success;
  static const FlLine _dailyHoverLine = FlLine(
    color: _dailyTotalColor,
    strokeWidth: 1,
    dashArray: [5, 5],
  );

  final String periodLabel;
  final double carburante;
  final double pedaggi;
  final int movimenti;
  final List<CostChartAmount> driverData;
  final List<CostChartAmount> vehicleData;
  final List<CostChartDay> dailyData;
  final List<CostChartAmount> weekdayData;
  final Widget? filters;

  _GraficiCostiDashboardContent({
    required this.periodLabel,
    required this.carburante,
    required this.pedaggi,
    required this.movimenti,
    required this.driverData,
    required this.vehicleData,
    required this.dailyData,
    required this.weekdayData,
    this.filters,
  });

  final _money = NumberFormat.currency(locale: 'it_IT', symbol: '\u20AC');
  final _shortDate = DateFormat('dd/MM');

  double get totale => carburante + pedaggi;
  double get carburanteShare => totale <= 0 ? 0 : carburante / totale;
  double get pedaggiShare => totale <= 0 ? 0 : pedaggi / totale;
  CostChartAmount? get topDriver =>
      _bestOf(driverData.where((entry) => entry.totale > 0));
  CostChartAmount? get topVehicle =>
      _bestOf(vehicleData.where((entry) => entry.totale > 0));
  CostChartDay? get dayPeak => _bestDay(dailyData);

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final pagePadding = screenWidth < 600 ? AppSpacing.md : AppSpacing.lg;

    return Scaffold(
      backgroundColor: AppColors.grey100,
      appBar: AppBar(
        title: const Text('Grafici costi'),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(pagePadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(),
            if (filters != null) ...[
              const SizedBox(height: AppSpacing.lg),
              filters!,
            ],
            const SizedBox(height: AppSpacing.lg),
            _insightStrip(),
            const SizedBox(height: AppSpacing.lg),
            _kpiGrid(),
            const SizedBox(height: AppSpacing.lg),
            _responsiveGrid(
              minHeight: 390,
              children: [
                _chartCard(
                  title: 'Composizione costi',
                  subtitle: 'Peso delle categorie sul totale filtrato',
                  icon: Icons.donut_large_rounded,
                  accent: AppColors.secondary,
                  child: _compositionChart(),
                ),
                _chartCard(
                  title: 'Andamento giornaliero',
                  subtitle: 'Totale e carburante nel periodo',
                  icon: Icons.show_chart_rounded,
                  accent: _dailyTotalColor,
                  titleColor: _dailyTotalColor,
                  child: _dailyTrendChart(),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            _responsiveGrid(
              minHeight: 390,
              children: [
                _chartCard(
                  title: 'Distribuzione driver',
                  subtitle: 'Incidenza dei costi per driver',
                  icon: Icons.person_outline,
                  accent: AppColors.primaryLight,
                  child: _AmountDistributionPieChart(
                    entries: driverData,
                    hue: 218,
                    totalLabel: 'Totale driver',
                  ),
                ),
                _chartCard(
                  title: 'Distribuzione veicoli',
                  subtitle: 'Incidenza dei costi per veicolo',
                  icon: Icons.directions_car_outlined,
                  accent: AppColors.success,
                  child: _AmountDistributionPieChart(
                    entries: vehicleData,
                    hue: 158,
                    totalLabel: 'Totale veicoli',
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            _responsiveGrid(
              minHeight: 390,
              children: [
                _chartCard(
                  title: 'Distribuzione settimanale',
                  subtitle: 'Concentrazione dei costi per giorno',
                  icon: Icons.calendar_view_week_outlined,
                  accent: AppColors.primaryDark,
                  child: _AmountDistributionPieChart(
                    entries: weekdayData,
                    hue: 38,
                    totalLabel: 'Totale settimana',
                  ),
                ),
                _chartCard(
                  title: 'Giorno di picco',
                  subtitle: 'Massimo costo giornaliero nel periodo',
                  icon: Icons.event_available_outlined,
                  accent: AppColors.success,
                  child: _peakDayAnalysis(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    final topDriverLabel = topDriver?.subtitle ?? topDriver?.label ?? '-';
    final topVehicleLabel = topVehicle?.label ?? '-';

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        final narrow = constraints.maxWidth < 420;

        return Container(
          width: double.infinity,
          padding: EdgeInsets.all(narrow ? AppSpacing.lg : AppSpacing.xl),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primaryDark,
                AppColors.primaryLight,
                AppColors.primary.withValues(alpha: 0.94),
              ],
            ),
            borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryDark.withValues(alpha: 0.24),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Builder(
            builder: (context) {
              final title = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.white.withValues(alpha: 0.14),
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusRound),
                    ),
                    child: Text(
                      periodLabel,
                      style: AppTextStyles.labelMedium.copyWith(
                        color: AppColors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Dashboard grafici',
                    style: (narrow
                            ? AppTextStyles.headlineLarge
                            : AppTextStyles.displaySmall)
                        .copyWith(color: AppColors.white),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Costi consolidati per categoria, driver, veicolo e periodo.',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.white.withValues(alpha: 0.82),
                    ),
                  ),
                ],
              );

              final summary = Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
                  border: Border.all(
                    color: AppColors.white.withValues(alpha: 0.18),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _money.format(totale),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.displayMedium.copyWith(
                        color: AppColors.white,
                        fontSize: narrow ? 26 : null,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '$movimenti movimenti analizzati',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.white.withValues(alpha: 0.78),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _headerMetric('Driver principale', topDriverLabel),
                    const SizedBox(height: AppSpacing.sm),
                    _headerMetric('Veicolo principale', topVehicleLabel),
                  ],
                ),
              );

              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    title,
                    const SizedBox(height: AppSpacing.lg),
                    summary,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(flex: 7, child: title),
                  const SizedBox(width: AppSpacing.xl),
                  Expanded(flex: 4, child: summary),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _headerMetric(String label, String value) {
    return Row(
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: const BoxDecoration(
            color: AppColors.secondaryLight,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.white.withValues(alpha: 0.70),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Flexible(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: AppTextStyles.labelMedium.copyWith(
              color: AppColors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }

  Widget _insightStrip() {
    final peak = dayPeak;
    final peakLabel = peak == null
        ? '-'
        : '${_shortDate.format(peak.date)} - ${_money.format(peak.totale)}';

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 980 ? 3 : 1;
        final width =
            (constraints.maxWidth - AppSpacing.md * (columns - 1)) / columns;
        final items = [
          _insightPill(
            icon: Icons.local_gas_station_outlined,
            label: 'Carburante',
            value: '${(carburanteShare * 100).round()}% del totale',
            color: AppColors.secondary,
          ),
          _insightPill(
            icon: Icons.toll_outlined,
            label: 'Pedaggi',
            value: '${(pedaggiShare * 100).round()}% del totale',
            color: AppColors.primaryLight,
          ),
          _insightPill(
            icon: Icons.event_available_outlined,
            label: 'Picco giornaliero',
            value: peakLabel,
            color: AppColors.success,
          ),
        ];

        return Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children:
              items.map((item) => SizedBox(width: width, child: item)).toList(),
        );
      },
    );
  }

  Widget _insightPill({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.labelMedium.copyWith(
                    color: color,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.titleMedium.copyWith(
                    color: AppColors.grey900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _kpiGrid() {
    final average = movimenti == 0 ? 0.0 : totale / movimenti;

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900
            ? 4
            : constraints.maxWidth >= 560
                ? 2
                : 1;
        final items = [
          _kpiCard('Totale', _money.format(totale), Icons.payments_outlined,
              AppColors.primaryLight),
          _kpiCard('Carburante', _money.format(carburante),
              Icons.local_gas_station_outlined, AppColors.secondary),
          _kpiCard('Pedaggi', _money.format(pedaggi), Icons.toll_outlined,
              AppColors.primaryLight),
          _kpiCard('Media movimento', _money.format(average),
              Icons.stacked_line_chart_rounded, AppColors.success),
        ];

        return Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: items
              .map(
                (item) => SizedBox(
                  width:
                      (constraints.maxWidth - AppSpacing.md * (columns - 1)) /
                          columns,
                  child: item,
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _responsiveGrid({
    required List<Widget> children,
    required double minHeight,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final mobile = constraints.maxWidth < 600;
        final cardHeight = mobile ? math.max(minHeight, 400.0) : minHeight;

        if (constraints.maxWidth < 980) {
          return Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                SizedBox(height: cardHeight, child: children[i]),
                if (i != children.length - 1)
                  const SizedBox(height: AppSpacing.lg),
              ],
            ],
          );
        }

        return SizedBox(
          height: cardHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                Expanded(child: children[i]),
                if (i != children.length - 1)
                  const SizedBox(width: AppSpacing.lg),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _chartCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accent,
    required Widget child,
    Color? titleColor,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 420;
        final padding = compact ? AppSpacing.md : AppSpacing.lg;
        final iconSize = compact ? 34.0 : 38.0;

        return Container(
          width: double.infinity,
          padding: EdgeInsets.all(padding),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
            border: Border.all(color: AppColors.grey200),
            boxShadow: [
              BoxShadow(
                color: AppColors.black.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 4,
                width: compact ? 40 : 48,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusRound),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: iconSize,
                    height: iconSize,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.11),
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusMedium),
                    ),
                    child: Icon(icon, color: accent, size: compact ? 18 : 20),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: (compact
                                  ? AppTextStyles.titleLarge
                                  : AppTextStyles.headlineSmall)
                              .copyWith(
                            color: titleColor ?? AppColors.grey900,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.grey600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: compact ? AppSpacing.md : AppSpacing.lg),
              Expanded(child: child),
            ],
          ),
        );
      },
    );
  }

  Widget _kpiCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
        border: Border.all(color: AppColors.grey200),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.grey600,
                        )),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.titleLarge,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.radiusRound),
            child: LinearProgressIndicator(
              value: totale <= 0
                  ? 0
                  : label == 'Carburante'
                      ? carburanteShare
                      : label == 'Pedaggi'
                          ? pedaggiShare
                          : 1,
              minHeight: 4,
              backgroundColor: AppColors.grey100,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _compositionChart() {
    if (totale <= 0) return _emptyChart('Nessun dato disponibile');

    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final side =
                  math.min(constraints.maxWidth, constraints.maxHeight);
              final radius = math.min(72.0, side * 0.30);
              final centerRadius = math.min(62.0, side * 0.25);

              return Stack(
                alignment: Alignment.center,
                children: [
                  PieChart(
                    PieChartData(
                      sectionsSpace: 4,
                      centerSpaceRadius: centerRadius,
                      sections: [
                        if (carburante > 0)
                          PieChartSectionData(
                            value: carburante,
                            color: AppColors.secondary,
                            radius: radius,
                            title: '${(carburanteShare * 100).round()}%',
                            titleStyle: const TextStyle(
                              color: AppColors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        if (pedaggi > 0)
                          PieChartSectionData(
                            value: pedaggi,
                            color: AppColors.primaryLight,
                            radius: radius,
                            title: '${(pedaggiShare * 100).round()}%',
                            titleStyle: const TextStyle(
                              color: AppColors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _money.format(totale),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.titleLarge.copyWith(
                          color: AppColors.grey900,
                          fontSize: side < 240 ? 16 : null,
                        ),
                      ),
                      Text(
                        'totale',
                        style: AppTextStyles.captionSmall.copyWith(
                          color: AppColors.grey500,
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _legendRow('Carburante', carburante, AppColors.secondary),
        const SizedBox(height: AppSpacing.sm),
        _legendRow('Pedaggi', pedaggi, AppColors.primaryLight),
      ],
    );
  }

  Widget _dailyTrendChart() {
    if (dailyData.isEmpty) return _emptyChart('Nessun andamento disponibile');

    final maxY = dailyData.map((day) => day.totale).fold<double>(0, math.max);
    final chartMaxY = maxY <= 0 ? 10.0 : maxY * 1.18;
    final interval = _chartInterval(maxY);

    return Column(
      children: [
        Expanded(
          child: LineChart(
            LineChartData(
              minY: 0,
              maxY: chartMaxY,
              gridData: FlGridData(
                drawVerticalLine: false,
                horizontalInterval: interval,
                getDrawingHorizontalLine: (_) => const FlLine(
                  color: AppColors.grey200,
                  strokeWidth: 1,
                ),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 48,
                    interval: interval,
                    getTitlesWidget: (value, meta) {
                      if (value <= 0) return const SizedBox.shrink();
                      return Text(
                        _compactMoney(value),
                        style: AppTextStyles.captionSmall.copyWith(
                          color: AppColors.grey500,
                        ),
                      );
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 34,
                    interval:
                        math.max(1, (dailyData.length / 4).ceil()).toDouble(),
                    getTitlesWidget: (value, meta) {
                      final index = value.round();
                      if (index < 0 || index >= dailyData.length) {
                        return const SizedBox.shrink();
                      }
                      return SideTitleWidget(
                        axisSide: meta.axisSide,
                        space: 8,
                        child: Text(
                          _shortDate.format(dailyData[index].date),
                          style: AppTextStyles.captionSmall.copyWith(
                            color: AppColors.grey600,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              lineTouchData: LineTouchData(
                touchSpotThreshold: 48,
                mouseCursorResolver: (event, response) {
                  final hasSpot = response?.lineBarSpots?.isNotEmpty ?? false;
                  return hasSpot
                      ? SystemMouseCursors.click
                      : SystemMouseCursors.basic;
                },
                getTouchLineStart: (_, __) => 0,
                getTouchLineEnd: (_, __) => chartMaxY,
                getTouchedSpotIndicator: (barData, spotIndexes) {
                  final dotColor = barData.color ?? _dailyTotalColor;

                  return spotIndexes.map((index) {
                    return TouchedSpotIndicatorData(
                      _dailyHoverLine,
                      FlDotData(
                        getDotPainter: (spot, percent, bar, index) {
                          return FlDotCirclePainter(
                            color: dotColor,
                            radius: 4,
                            strokeColor: AppColors.white,
                            strokeWidth: 2,
                          );
                        },
                      ),
                    );
                  }).toList();
                },
                touchTooltipData: LineTouchTooltipData(
                  tooltipBgColor: AppColors.grey800,
                  tooltipRoundedRadius: AppSpacing.radiusMedium,
                  fitInsideHorizontally: true,
                  fitInsideVertically: true,
                  getTooltipItems: (spots) {
                    if (spots.isEmpty) return [];

                    final index = spots.first.x.round();
                    if (index < 0 || index >= dailyData.length) {
                      return spots.map((_) => null).toList();
                    }

                    final day = dailyData[index];
                    final item = LineTooltipItem(
                      '${_shortDate.format(day.date)}\n',
                      const TextStyle(
                        color: AppColors.white,
                        fontWeight: FontWeight.w800,
                      ),
                      children: [
                        TextSpan(
                          text: 'Totale ${_money.format(day.totale)}\n',
                          style: const TextStyle(
                            color: _dailyTotalColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        TextSpan(
                          text: 'Carburante ${_money.format(day.carburante)}\n',
                          style: const TextStyle(
                            color: AppColors.secondaryLight,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        TextSpan(
                          text: 'Pedaggi ${_money.format(day.pedaggi)}',
                          style: const TextStyle(
                            color: AppColors.primaryLight,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    );

                    return List<LineTooltipItem?>.generate(
                      spots.length,
                      (index) => index == 0 ? item : null,
                    );
                  },
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: List.generate(
                    dailyData.length,
                    (index) =>
                        FlSpot(index.toDouble(), dailyData[index].totale),
                  ),
                  isCurved: true,
                  color: _dailyTotalColor,
                  barWidth: 3,
                  dotData: FlDotData(
                    show: dailyData.length <= 12,
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    color: _dailyTotalColor.withValues(alpha: 0.10),
                  ),
                ),
                LineChartBarData(
                  spots: List.generate(
                    dailyData.length,
                    (index) =>
                        FlSpot(index.toDouble(), dailyData[index].carburante),
                  ),
                  isCurved: true,
                  color: AppColors.secondary,
                  barWidth: 2,
                  dotData: const FlDotData(show: false),
                ),
                LineChartBarData(
                  spots: List.generate(
                    dailyData.length,
                    (index) =>
                        FlSpot(index.toDouble(), dailyData[index].pedaggi),
                  ),
                  isCurved: true,
                  color: AppColors.primaryLight,
                  barWidth: 2,
                  dotData: const FlDotData(show: false),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.xs,
          children: [
            _compactLegend('Totale', _dailyTotalColor),
            _compactLegend('Carburante', AppColors.secondary),
            _compactLegend('Pedaggi', AppColors.primaryLight),
          ],
        ),
      ],
    );
  }

  Widget _compactLegend(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 18,
          height: 4,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(AppSpacing.radiusRound),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          label,
          style: AppTextStyles.captionSmall.copyWith(
            color: AppColors.grey600,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _peakDayAnalysis() {
    final peak = dayPeak;
    if (peak == null || peak.totale <= 0) {
      return _emptyChart('Nessun picco disponibile');
    }

    final peakShare = totale <= 0 ? 0.0 : peak.totale / totale;
    final fuelShare = peak.totale <= 0 ? 0.0 : peak.carburante / peak.totale;
    final tollShare = peak.totale <= 0 ? 0.0 : peak.pedaggi / peak.totale;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 420;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(compact ? AppSpacing.sm : AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.09),
                borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
                border: Border.all(
                  color: AppColors.success.withValues(alpha: 0.22),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: compact ? 38 : 44,
                    height: compact ? 38 : 44,
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.15),
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusMedium),
                    ),
                    child: const Icon(
                      Icons.calendar_today_outlined,
                      color: AppColors.success,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _shortDate.format(peak.date),
                          style: AppTextStyles.labelMedium.copyWith(
                            color: AppColors.success,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          _money.format(peak.totale),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: (compact
                                  ? AppTextStyles.titleLarge
                                  : AppTextStyles.headlineLarge)
                              .copyWith(
                            color: AppColors.grey900,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          '${(peakShare * 100).toStringAsFixed(1)}% del totale periodo',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.grey600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _peakBreakdownRow(
              label: 'Carburante',
              value: peak.carburante,
              share: fuelShare,
              color: AppColors.secondary,
            ),
            const SizedBox(height: AppSpacing.sm),
            _peakBreakdownRow(
              label: 'Pedaggi',
              value: peak.pedaggi,
              share: tollShare,
              color: AppColors.primaryLight,
            ),
            const SizedBox(height: AppSpacing.sm),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: AppColors.grey50,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                border: Border.all(color: AppColors.grey200),
              ),
              child: Text(
                peak.totale >= totale
                    ? 'Il picco coincide con tutto il costo filtrato.'
                    : 'Picco calcolato sui dati giornalieri filtrati.',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.grey600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _peakBreakdownRow({
    required String label,
    required double value,
    required double share,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: AppTextStyles.labelMedium.copyWith(
                  color: color,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              _money.format(value),
              style: AppTextStyles.labelMedium.copyWith(
                color: AppColors.grey900,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.radiusRound),
          child: LinearProgressIndicator(
            value: share.clamp(0.0, 1.0).toDouble(),
            minHeight: 6,
            backgroundColor: AppColors.grey100,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '${(share * 100).toStringAsFixed(1)}% del giorno di picco',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.captionSmall.copyWith(
            color: AppColors.grey500,
          ),
        ),
      ],
    );
  }

  Widget _legendRow(String label, double value, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Text(label, style: AppTextStyles.bodyMedium)),
        Text(
          _money.format(value),
          style: AppTextStyles.labelMedium.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _emptyChart(String text) {
    return Center(
      child: Text(
        text,
        style: AppTextStyles.bodyMedium.copyWith(color: AppColors.grey500),
      ),
    );
  }

  double _chartInterval(double maxY) {
    if (maxY <= 50) return 25;
    if (maxY <= 150) return 50;
    if (maxY <= 500) return 100;
    return 250;
  }

  String _compactMoney(double value) {
    if (value >= 1000) {
      return '\u20AC${(value / 1000).toStringAsFixed(1)}k';
    }
    return '\u20AC${value.round()}';
  }

  CostChartAmount? _bestOf(Iterable<CostChartAmount> entries) {
    CostChartAmount? best;

    for (final entry in entries) {
      if (best == null || entry.totale > best.totale) {
        best = entry;
      }
    }

    return best;
  }

  CostChartDay? _bestDay(List<CostChartDay> entries) {
    CostChartDay? best;

    for (final entry in entries) {
      if (best == null || entry.totale > best.totale) {
        best = entry;
      }
    }

    return best;
  }
}

class _CostRecord {
  final Restituzione restituzione;
  final Prenotazione? prenotazione;
  final Utente? driver;
  final Veicolo? veicolo;

  _CostRecord({
    required this.restituzione,
    required this.prenotazione,
    required this.driver,
    required this.veicolo,
  });

  double get carburante => restituzione.importoEuro ?? 0;
  double get pedaggi => restituzione.importoPedaggi ?? 0;
  String get targa => prenotazione?.targa ?? 'N/D';

  String get driverName {
    if (driver == null) return 'Sconosciuto';
    return '${driver!.nome} ${driver!.cognome}'.trim();
  }

  String get vehicleLabel {
    if (veicolo == null) return 'Veicolo non trovato';
    return '${veicolo!.marca} ${veicolo!.modello}';
  }
}

class _SelectOption<T> {
  final T value;
  final String label;

  const _SelectOption(this.value, this.label);
}

class _MultiSelectOption<T> {
  final T value;
  final String title;
  final String? subtitle;
  final IconData icon;

  const _MultiSelectOption({
    required this.value,
    required this.title,
    required this.icon,
    this.subtitle,
  });
}

class _DriverCostSummary {
  final int driverId;
  final String nomeDriver;
  double carburante = 0;
  double pedaggi = 0;
  int movimenti = 0;

  _DriverCostSummary({
    required this.driverId,
    required this.nomeDriver,
  });

  double get totaleVisibile => carburante + pedaggi;

  void add(_CostRecord record, Set<_CostCategory> categories) {
    if (categories.contains(_CostCategory.carburante)) {
      carburante += record.carburante;
    }
    if (categories.contains(_CostCategory.pedaggi)) {
      pedaggi += record.pedaggi;
    }
    movimenti++;
  }
}

class _VehicleCostSummary {
  final String targa;
  final String vehicleLabel;
  double carburante = 0;
  double pedaggi = 0;
  int movimenti = 0;

  _VehicleCostSummary({
    required this.targa,
    required this.vehicleLabel,
  });

  double get totaleVisibile => carburante + pedaggi;

  void add(_CostRecord record, Set<_CostCategory> categories) {
    if (categories.contains(_CostCategory.carburante)) {
      carburante += record.carburante;
    }
    if (categories.contains(_CostCategory.pedaggi)) {
      pedaggi += record.pedaggi;
    }
    movimenti++;
  }
}

class _ChartAmountAccumulator {
  double carburante = 0;
  double pedaggi = 0;

  void add(_CostRecord record, Set<_CostCategory> categories) {
    if (categories.contains(_CostCategory.carburante)) {
      carburante += record.carburante;
    }
    if (categories.contains(_CostCategory.pedaggi)) {
      pedaggi += record.pedaggi;
    }
  }
}

class _CostTotals {
  final double carburante;
  final double pedaggi;

  const _CostTotals({
    required this.carburante,
    required this.pedaggi,
  });

  double get totale => carburante + pedaggi;

  factory _CostTotals.fromSummaries(List<_DriverCostSummary> summaries) {
    return _CostTotals(
      carburante: summaries.fold(0.0, (sum, item) => sum + item.carburante),
      pedaggi: summaries.fold(0.0, (sum, item) => sum + item.pedaggi),
    );
  }
}

class _AmountDistributionPieChart extends StatefulWidget {
  final List<CostChartAmount> entries;
  final double hue;
  final String totalLabel;

  const _AmountDistributionPieChart({
    required this.entries,
    required this.hue,
    required this.totalLabel,
  });

  @override
  State<_AmountDistributionPieChart> createState() =>
      _AmountDistributionPieChartState();
}

class _AmountDistributionPieChartState
    extends State<_AmountDistributionPieChart> {
  final _money = NumberFormat.currency(locale: 'it_IT', symbol: '\u20AC');
  int _touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final visibleEntries =
        widget.entries.where((entry) => entry.totale > 0).toList();
    if (visibleEntries.isEmpty) {
      return const _DistributionPieEmptyChart();
    }

    final total =
        visibleEntries.fold<double>(0, (sum, entry) => sum + entry.totale);
    final minValue = visibleEntries
        .map((entry) => entry.totale)
        .fold<double>(double.infinity, math.min);
    final maxValue =
        visibleEntries.map((entry) => entry.totale).fold<double>(0, math.max);
    final selectedEntry =
        _touchedIndex >= 0 && _touchedIndex < visibleEntries.length
            ? visibleEntries[_touchedIndex]
            : null;

    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final side =
                  math.min(constraints.maxWidth, constraints.maxHeight);
              final radius = math.min(74.0, side * 0.30);
              final selectedRadius = math.min(radius + 5, side * 0.34);
              final centerRadius = math.min(64.0, side * 0.25);
              final infoSize = math.min(124.0, side * 0.48);

              return Center(
                child: SizedBox.square(
                  dimension: side,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      PieChart(
                        PieChartData(
                          pieTouchData: PieTouchData(
                            mouseCursorResolver: (event, response) {
                              final hasSection =
                                  response?.touchedSection?.touchedSection !=
                                      null;
                              return hasSection
                                  ? SystemMouseCursors.click
                                  : SystemMouseCursors.basic;
                            },
                            touchCallback: (event, response) {
                              setState(() {
                                if (!event.isInterestedForInteractions ||
                                    response == null ||
                                    response.touchedSection == null) {
                                  _touchedIndex = -1;
                                  return;
                                }
                                _touchedIndex = response
                                    .touchedSection!.touchedSectionIndex;
                              });
                            },
                          ),
                          sectionsSpace: 0,
                          centerSpaceRadius: centerRadius,
                          sections:
                              List.generate(visibleEntries.length, (index) {
                            final entry = visibleEntries[index];
                            final selected = index == _touchedIndex;
                            final share = total <= 0 ? 0 : entry.totale / total;

                            return PieChartSectionData(
                              value: entry.totale,
                              color: _colorForAmount(
                                entry.totale,
                                minValue,
                                maxValue,
                              ),
                              radius: selected ? selectedRadius : radius,
                              title: selected || share >= 0.08
                                  ? '${(share * 100).round()}%'
                                  : '',
                              titlePositionPercentageOffset: 0.62,
                              titleStyle: TextStyle(
                                color: AppColors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: selected ? 12 : 11,
                              ),
                              borderSide: BorderSide.none,
                            );
                          }),
                        ),
                      ),
                      _DistributionPieInfo(
                        entry: selectedEntry,
                        total: total,
                        money: _money,
                        totalLabel: widget.totalLabel,
                        size: infoSize,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Color _colorForAmount(double value, double minValue, double maxValue) {
    if (maxValue <= minValue) {
      return HSLColor.fromAHSL(1, widget.hue, 0.72, 0.40).toColor();
    }

    final normalized =
        ((value - minValue) / (maxValue - minValue)).clamp(0.0, 1.0).toDouble();
    final lightness = 0.72 - normalized * 0.42;

    return HSLColor.fromAHSL(1, widget.hue, 0.72, lightness).toColor();
  }
}

class _DistributionPieInfo extends StatelessWidget {
  final CostChartAmount? entry;
  final double total;
  final NumberFormat money;
  final String totalLabel;
  final double size;

  const _DistributionPieInfo({
    required this.entry,
    required this.total,
    required this.money,
    required this.totalLabel,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final selected = entry;
    final title = selected?.subtitle ?? selected?.label ?? totalLabel;
    final amount = selected?.totale ?? total;
    final share =
        selected == null || total <= 0 ? null : selected.totale / total;

    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size < 112 ? AppSpacing.sm : AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.94),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              maxLines: selected == null ? 1 : 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: AppTextStyles.captionSmall.copyWith(
                color: AppColors.grey600,
                fontWeight: FontWeight.w800,
                fontSize: size < 112 ? 9 : null,
              ),
            ),
            SizedBox(height: size < 112 ? 2 : AppSpacing.xs),
            Text(
              money.format(amount),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: AppTextStyles.titleSmall.copyWith(
                color: AppColors.grey900,
                fontWeight: FontWeight.w900,
                fontSize: size < 112 ? 11 : null,
              ),
            ),
            if (share != null) ...[
              SizedBox(height: size < 112 ? 2 : AppSpacing.xs),
              Text(
                '${(share * 100).toStringAsFixed(1)}% totale',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: AppTextStyles.captionSmall.copyWith(
                  color: AppColors.primaryDark,
                  fontWeight: FontWeight.w800,
                  fontSize: size < 112 ? 9 : null,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Carb. ${money.format(selected!.carburante)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: AppTextStyles.captionSmall.copyWith(
                  color: AppColors.secondary,
                  fontSize: size < 112 ? 8 : null,
                ),
              ),
              Text(
                'Ped. ${money.format(selected.pedaggi)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: AppTextStyles.captionSmall.copyWith(
                  color: AppColors.primaryLight,
                  fontSize: size < 112 ? 8 : null,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DistributionPieEmptyChart extends StatelessWidget {
  const _DistributionPieEmptyChart();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Nessun dato disponibile',
        style: AppTextStyles.bodyMedium.copyWith(color: AppColors.grey500),
      ),
    );
  }
}

class CostChartAmount {
  final String label;
  final String? subtitle;
  final double carburante;
  final double pedaggi;

  const CostChartAmount({
    required this.label,
    this.subtitle,
    this.carburante = 0,
    this.pedaggi = 0,
  });

  double get totale => carburante + pedaggi;
}

class CostChartDay {
  final DateTime date;
  final double carburante;
  final double pedaggi;

  const CostChartDay({
    required this.date,
    required this.carburante,
    required this.pedaggi,
  });

  double get totale => carburante + pedaggi;
}
