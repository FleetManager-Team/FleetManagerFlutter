import 'dart:math' as math;

import 'package:fleetmanager/core/theme/index.dart';
import 'package:fleetmanager/models/prenotazione.dart';
import 'package:fleetmanager/provider/fleet_provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

enum _PeriodPreset { today, week, month, quarter, year, custom }

class DettaglioCostiVeicolo extends StatefulWidget {
  final String targa;
  final String nomeVeicolo;
  final DateTimeRange rangeIniziale;

  const DettaglioCostiVeicolo({
    super.key,
    required this.targa,
    required this.nomeVeicolo,
    required this.rangeIniziale,
  });

  @override
  State<DettaglioCostiVeicolo> createState() => _DettaglioCostiVeicoloState();
}

class _DettaglioCostiVeicoloState extends State<DettaglioCostiVeicolo> {
  final _money = NumberFormat.currency(locale: 'it_IT', symbol: '\u20AC');
  final _shortDate = DateFormat('dd/MM/yy');
  final _fullDate = DateFormat('dd/MM/yyyy');

  late DateTimeRange _rangeSelezionato;
  bool _mostraCarburante = true;
  bool _mostraPedaggi = true;
  _PeriodPreset _periodPreset = _PeriodPreset.month;

  @override
  void initState() {
    super.initState();
    _rangeSelezionato = widget.rangeIniziale;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FleetProvider>();
    final datiTemporali = _buildTemporalData(provider);
    final totals = _CostTotals.fromData(datiTemporali.values);
    final visibleTotals = _visibleTotals(totals);
    final giorniConCosti = _filteredEntries(datiTemporali).length;

    return Scaffold(
      backgroundColor: AppColors.grey100,
      appBar: AppBar(
        title: const Text('Dettaglio costi veicolo'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(visibleTotals, giorniConCosti),
            const SizedBox(height: AppSpacing.lg),
            _buildFilters(),
            const SizedBox(height: AppSpacing.lg),
            _buildKpiGrid(totals, visibleTotals, giorniConCosti),
            const SizedBox(height: AppSpacing.lg),
            if (giorniConCosti == 0)
              _buildEmptyState()
            else ...[
              _buildChartCard(datiTemporali),
              const SizedBox(height: AppSpacing.lg),
              _buildDailyMovements(datiTemporali),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(_CostTotals totals, int giorniConCosti) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primaryDark, AppColors.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.18),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'COSTI VEICOLO',
            style: AppTextStyles.overline.copyWith(
              color: AppColors.white.withValues(alpha: 0.72),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            widget.targa,
            style: AppTextStyles.headlineLarge.copyWith(
              color: AppColors.white,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            widget.nomeVeicolo,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.white.withValues(alpha: 0.82),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            _money.format(totals.totale),
            style: AppTextStyles.displayLarge.copyWith(
              color: AppColors.white,
              fontSize: 34,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '${_shortDate.format(_rangeSelezionato.start)} - ${_shortDate.format(_rangeSelezionato.end)} - $giorniConCosti giorni con costi',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.white.withValues(alpha: 0.82),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.tune_rounded, color: AppColors.primaryDark),
              SizedBox(width: AppSpacing.sm),
              Text('Filtri dettaglio', style: AppTextStyles.headlineSmall),
            ],
          ),
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
                selected: _mostraCarburante,
                activeColor: AppColors.secondary,
                onSelected: (selected) =>
                    setState(() => _mostraCarburante = selected),
              ),
              _filterChip(
                label: 'Pedaggi',
                icon: Icons.route_rounded,
                selected: _mostraPedaggi,
                activeColor: AppColors.primaryLight,
                onSelected: (selected) =>
                    setState(() => _mostraPedaggi = selected),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKpiGrid(
    _CostTotals totals,
    _CostTotals visibleTotals,
    int giorniConCosti,
  ) {
    final mediaGiorno =
        giorniConCosti == 0 ? 0.0 : visibleTotals.totale / giorniConCosti;

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 820 ? 4 : 2;
        final cards = [
          _kpiCard(
            'Carburante',
            _money.format(_mostraCarburante ? totals.carburante : 0),
            Icons.local_gas_station,
            AppColors.secondary,
          ),
          _kpiCard(
            'Pedaggi',
            _money.format(_mostraPedaggi ? totals.pedaggi : 0),
            Icons.route_rounded,
            AppColors.primaryLight,
          ),
          _kpiCard(
            'Media giorno',
            _money.format(mediaGiorno),
            Icons.speed_rounded,
            AppColors.success,
          ),
          _kpiCard(
            'Giorni',
            giorniConCosti.toString(),
            Icons.calendar_month_outlined,
            AppColors.grey700,
          ),
        ];

        return _responsiveRows(children: cards, columns: columns);
      },
    );
  }

  Widget _buildChartCard(Map<DateTime, _DailyVehicleCost> dati) {
    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Andamento giornaliero',
              style: AppTextStyles.headlineSmall),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(height: 310, child: _buildGraficoTemporale(dati)),
          const SizedBox(height: AppSpacing.md),
          _legendRow('Carburante', AppColors.secondary),
          const SizedBox(height: AppSpacing.sm),
          _legendRow('Pedaggi', AppColors.primaryLight),
        ],
      ),
    );
  }

  Widget _buildGraficoTemporale(Map<DateTime, _DailyVehicleCost> dati) {
    final entries = _filteredEntries(dati);

    if (entries.isEmpty) {
      return Center(
        child: Text(
          'Nessun dato disponibile con i filtri selezionati',
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.grey500),
        ),
      );
    }

    final maxY = entries
        .map((entry) => _visibleTotal(entry.value))
        .fold<double>(0, math.max);

    return BarChart(
      BarChartData(
        maxY: maxY <= 0 ? 10 : maxY * 1.18,
        alignment: BarChartAlignment.spaceAround,
        gridData: FlGridData(
          drawVerticalLine: false,
          horizontalInterval: _chartInterval(maxY),
          getDrawingHorizontalLine: (value) => const FlLine(
            color: AppColors.grey200,
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            tooltipBgColor: AppColors.grey800,
            tooltipRoundedRadius: AppSpacing.radiusMedium,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final entry = entries[groupIndex];
              final drivers = entry.value.sourcesLabel;
              return BarTooltipItem(
                '${_fullDate.format(entry.key)}\n$drivers\n${_money.format(rod.toY)}',
                AppTextStyles.labelMedium.copyWith(
                  color: AppColors.white,
                  fontWeight: FontWeight.w700,
                ),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 38,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= entries.length) {
                  return const SizedBox.shrink();
                }

                return SideTitleWidget(
                  axisSide: meta.axisSide,
                  space: AppSpacing.sm,
                  child: Text(
                    _shortDate.format(entries[index].key),
                    style: AppTextStyles.captionSmall.copyWith(
                      color: AppColors.grey600,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 48,
              interval: _chartInterval(maxY),
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
        ),
        barGroups: List.generate(entries.length, (index) {
          final spesa = entries[index].value;
          final altezza = _visibleTotal(spesa);

          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: altezza,
                width: 22,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(5)),
                rodStackItems: [
                  if (_mostraCarburante)
                    BarChartRodStackItem(
                      0,
                      spesa.carburante,
                      AppColors.secondary,
                    ),
                  if (_mostraPedaggi)
                    BarChartRodStackItem(
                      _mostraCarburante ? spesa.carburante : 0,
                      altezza,
                      AppColors.primaryLight,
                    ),
                ],
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildDailyMovements(Map<DateTime, _DailyVehicleCost> dati) {
    final entries = _filteredEntries(dati).reversed.toList();

    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Movimenti per giorno',
              style: AppTextStyles.headlineSmall),
          const SizedBox(height: AppSpacing.md),
          ...entries.map((entry) {
            final spesa = entry.value;
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(
                Icons.receipt_long_outlined,
                color: AppColors.primaryDark,
              ),
              title: Text(
                _fullDate.format(entry.key),
                style: AppTextStyles.titleMedium,
              ),
              subtitle: Text(
                '${spesa.sourcesLabel} - Carburante ${_money.format(spesa.carburante)} - Pedaggi ${_money.format(spesa.pedaggi)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Text(
                _money.format(_visibleTotal(spesa)),
                style: AppTextStyles.titleMedium.copyWith(
                  color: AppColors.primaryDark,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return _sectionCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
        child: Center(
          child: Column(
            children: [
              const Icon(
                Icons.filter_alt_off_outlined,
                size: 42,
                color: AppColors.grey400,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Nessun risultato con questi filtri',
                style: AppTextStyles.headlineSmall.copyWith(
                  color: AppColors.grey700,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Allarga il periodo o riattiva una categoria costo.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.grey500,
                ),
              ),
            ],
          ),
        ),
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
      selectedColor: AppButtonStyles.chipBackground(selected),
      backgroundColor: AppButtonStyles.chipBackground(false),
      labelStyle: AppButtonStyles.chipLabelStyle(selected),
      side: AppButtonStyles.chipSide(selected),
      onSelected: (_) => _setPreset(preset),
      shape: AppButtonStyles.chipShape,
      padding: AppButtonStyles.chipPadding,
    );
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
              const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: AppColors.grey500,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
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
      child: child,
    );
  }

  Widget _kpiCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
        border: Border.all(color: AppColors.grey200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const Spacer(),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.headlineMedium.copyWith(
              color: AppColors.grey900,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(color: AppColors.grey500),
          ),
        ],
      ),
    );
  }

  Widget _legendRow(String label, Color color) {
    final disabled = (label == 'Carburante' && !_mostraCarburante) ||
        (label == 'Pedaggi' && !_mostraPedaggi);

    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: disabled ? AppColors.grey300 : color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          label,
          style: AppTextStyles.bodyMedium.copyWith(
            color: disabled ? AppColors.grey500 : AppColors.textPrimary,
          ),
        ),
      ],
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

  Map<DateTime, _DailyVehicleCost> _buildTemporalData(FleetProvider provider) {
    final Map<DateTime, _DailyVehicleCost> data = {};
    final endOfDay = DateTime(
      _rangeSelezionato.end.year,
      _rangeSelezionato.end.month,
      _rangeSelezionato.end.day,
      23,
      59,
      59,
    );

    for (final restituzione in provider.restituzioni) {
      Prenotazione? prenotazione;

      try {
        prenotazione = provider.prenotazioni.firstWhere(
          (p) => p.idPrenotazione == restituzione.idPrenotazione,
        );
      } catch (_) {}

      if (prenotazione?.targa != widget.targa) continue;

      final date = restituzione.dataRestituzione;
      if (date.isBefore(_rangeSelezionato.start) || date.isAfter(endOfDay)) {
        continue;
      }

      final day = DateTime(date.year, date.month, date.day);
      data.putIfAbsent(day, _DailyVehicleCost.new);
      data[day]!.carburante += restituzione.importoEuro ?? 0;
      data[day]!.pedaggi += restituzione.importoPedaggi ?? 0;
      data[day]!.drivers.add(_driverName(provider, prenotazione!.idUtente));
    }

    return data;
  }

  String _driverName(FleetProvider provider, int idDriver) {
    try {
      final driver =
          provider.utenti.firstWhere((utente) => utente.idUtente == idDriver);
      final fullName = '${driver.nome} ${driver.cognome}'.trim();
      return fullName.isEmpty ? 'Driver $idDriver' : fullName;
    } catch (_) {
      return 'Driver $idDriver';
    }
  }

  List<MapEntry<DateTime, _DailyVehicleCost>> _filteredEntries(
    Map<DateTime, _DailyVehicleCost> dati,
  ) {
    final entries = dati.entries.where((entry) {
      return _visibleTotal(entry.value) > 0;
    }).toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return entries;
  }

  _CostTotals _visibleTotals(_CostTotals totals) {
    return _CostTotals(
      carburante: _mostraCarburante ? totals.carburante : 0,
      pedaggi: _mostraPedaggi ? totals.pedaggi : 0,
    );
  }

  double _visibleTotal(_DailyVehicleCost spesa) {
    double totale = 0;
    if (_mostraCarburante) totale += spesa.carburante;
    if (_mostraPedaggi) totale += spesa.pedaggi;
    return totale;
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
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: _rangeSelezionato,
      firstDate: DateTime(DateTime.now().year - 5),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      helpText: 'Periodo',
      cancelText: 'Annulla',
      confirmText: 'Applica',
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

    if (picked != null) {
      setState(() {
        _periodPreset = _PeriodPreset.custom;
        _rangeSelezionato = picked;
      });
    }
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
        return 0;
      case _PeriodPreset.week:
        return 7;
      case _PeriodPreset.month:
        return 30;
      case _PeriodPreset.quarter:
        return 90;
      case _PeriodPreset.year:
        return 365;
      case _PeriodPreset.custom:
        return 0;
    }
  }

  String _compactMoney(double value) {
    if (value >= 1000) return '\u20AC${(value / 1000).toStringAsFixed(1)}k';
    return '\u20AC${value.toInt()}';
  }

  double _chartInterval(double maxY) {
    if (maxY <= 50) return 10;
    if (maxY <= 250) return 50;
    if (maxY <= 1000) return 200;
    return 500;
  }
}

class _DailyVehicleCost {
  double carburante = 0;
  double pedaggi = 0;
  final Set<String> drivers = {};

  String get sourcesLabel {
    if (drivers.isEmpty) return 'Driver non trovato';
    if (drivers.length <= 2) return drivers.join(', ');
    return '${drivers.length} driver';
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

  factory _CostTotals.fromData(Iterable<_DailyVehicleCost> items) {
    return _CostTotals(
      carburante: items.fold(0.0, (sum, item) => sum + item.carburante),
      pedaggi: items.fold(0.0, (sum, item) => sum + item.pedaggi),
    );
  }
}
