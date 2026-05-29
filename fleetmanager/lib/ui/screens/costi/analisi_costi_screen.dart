import 'dart:math' as math;

import 'package:fleetmanager/core/theme/index.dart';
import 'package:fleetmanager/models/enums/ruolo_utente.dart';
import 'package:fleetmanager/models/enums/tipo_veicolo.dart';
import 'package:fleetmanager/models/prenotazione.dart';
import 'package:fleetmanager/models/restituzione.dart';
import 'package:fleetmanager/models/utente.dart';
import 'package:fleetmanager/models/veicolo.dart';
import 'package:fleetmanager/provider/fleet_provider.dart';
import 'package:fleetmanager/ui/screens/costi/dettaglio_costi_driver.dart';
import 'package:fleetmanager/ui/screens/costi/dettaglio_costi_veicolo.dart';
import 'package:fleetmanager/ui/screens/costi/grafici_costi_screen.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

enum _CostCategory { carburante, pedaggi }

enum _CostSort { totaleDesc, carburanteDesc, pedaggiDesc, nomeAsc }

enum _PeriodPreset { today, week, month, quarter, year, custom }

class AnalisiCostiScreen extends StatefulWidget {
  const AnalisiCostiScreen({super.key});

  @override
  State<AnalisiCostiScreen> createState() => _AnalisiCostiScreenState();
}

class _AnalisiCostiScreenState extends State<AnalisiCostiScreen> {
  final _money = NumberFormat.currency(locale: 'it_IT', symbol: '\u20AC');
  final _shortDate = DateFormat('dd/MM/yy');
  final _fullDate = DateFormat('dd/MM/yyyy');

  DateTimeRange _rangeSelezionato = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 30)),
    end: DateTime.now(),
  );

  final Set<_CostCategory> _categorie = {
    _CostCategory.carburante,
    _CostCategory.pedaggi,
  };

  _PeriodPreset _periodPreset = _PeriodPreset.month;
  Set<int>? _driverSelezionati = {};
  Set<String>? _targheSelezionate = {};
  TipoVeicolo? _tipoVeicoloSelezionato;
  _CostSort _ordinamento = _CostSort.totaleDesc;
  bool _filtriEspansi = true;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FleetProvider>();
    final records = _buildRecords(provider);
    final filteredRecords = _filterRecords(records);
    final summaries = _buildSummaries(filteredRecords);
    final vehicleSummaries = _buildVehicleSummaries(filteredRecords);
    final visibleDriverIds =
        summaries.map((summary) => summary.driverId).toSet();
    final displayedRecords = filteredRecords
        .where((record) =>
            visibleDriverIds.contains(record.prenotazione?.idUtente ?? -1))
        .toList();
    final totals = _CostTotals.fromSummaries(summaries);
    final average = summaries.isEmpty ? 0.0 : totals.totale / summaries.length;

    return Scaffold(
      backgroundColor: AppColors.grey100,
      appBar: AppBar(
        title: const Text('Analisi Costi'),
      ),
      body: RefreshIndicator(
        onRefresh: () => context.read<FleetProvider>().inizializzaDati(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(totals, displayedRecords.length, records.length),
              const SizedBox(height: AppSpacing.lg),
              _buildFilters(provider),
              const SizedBox(height: AppSpacing.lg),
              _buildKpiGrid(totals, average, summaries.length),
              const SizedBox(height: AppSpacing.lg),
              if (summaries.isEmpty)
                _buildEmptyState(records.isEmpty)
              else ...[
                _buildCharts(
                  summaries,
                  vehicleSummaries,
                  totals,
                  filteredRecords,
                ),
                const SizedBox(height: AppSpacing.lg),
                _buildDriverList(summaries),
                const SizedBox(height: AppSpacing.lg),
                _buildRecentMovements(displayedRecords),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(_CostTotals totals, int visibleCount, int totalCount) {
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
            'COSTI FLOTTA',
            style: AppTextStyles.overline.copyWith(
              color: AppColors.white.withValues(alpha: 0.72),
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
            '${_shortDate.format(_rangeSelezionato.start)} - ${_shortDate.format(_rangeSelezionato.end)} - $visibleCount movimenti filtrati su $totalCount',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.white.withValues(alpha: 0.82),
            ),
          ),
        ],
      ),
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

  Widget _buildKpiGrid(_CostTotals totals, double average, int driversCount) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 820 ? 4 : 2;
        final cards = [
          _kpiCard(
            'Carburante',
            _money.format(totals.carburante),
            Icons.local_gas_station,
            AppColors.secondary,
          ),
          _kpiCard(
            'Pedaggi',
            _money.format(totals.pedaggi),
            Icons.route_rounded,
            AppColors.primaryLight,
          ),
          _kpiCard(
            'Media driver',
            _money.format(average),
            Icons.speed_rounded,
            AppColors.success,
          ),
          _kpiCard(
            'Driver',
            driversCount.toString(),
            Icons.groups_2_outlined,
            AppColors.grey700,
          ),
        ];

        return _responsiveRows(children: cards, columns: columns);
      },
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

  Widget _buildCharts(
    List<_DriverCostSummary> summaries,
    List<_VehicleCostSummary> vehicleSummaries,
    _CostTotals totals,
    List<_CostRecord> records,
  ) {
    final chartData = summaries.take(10).toList();
    final vehicleChartData = vehicleSummaries.take(10).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 860;
        final barChart = _sectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Spesa per driver',
                  style: AppTextStyles.headlineSmall),
              const SizedBox(height: AppSpacing.lg),
              SizedBox(height: 310, child: _buildBarChart(chartData)),
            ],
          ),
        );
        final pieChart = _sectionCard(
          onTap: () => _openChartsDashboard(
            summaries: summaries,
            vehicleSummaries: vehicleSummaries,
            totals: totals,
            records: records,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Composizione',
                      style: AppTextStyles.headlineSmall,
                    ),
                  ),
                  Tooltip(
                    message: 'Apri dashboard grafici',
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight.withValues(alpha: 0.10),
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusMedium),
                      ),
                      child: const Icon(
                        Icons.insights_rounded,
                        color: AppColors.primaryDark,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
              if (wide)
                const Spacer()
              else
                const SizedBox(height: AppSpacing.lg),
              SizedBox(
                height: wide ? 260 : 220,
                child: _buildPieChart(totals),
              ),
              if (wide)
                const Spacer()
              else
                const SizedBox(height: AppSpacing.md),
              if (wide) const SizedBox(height: AppSpacing.md),
              _legendRow('Carburante', totals.carburante, AppColors.secondary),
              const SizedBox(height: AppSpacing.sm),
              _legendRow('Pedaggi', totals.pedaggi, AppColors.primaryLight),
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(
                    AppSpacing.radiusMedium,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.open_in_new_rounded,
                      color: AppColors.primaryDark,
                      size: 16,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'Apri dashboard grafici',
                        style: AppTextStyles.labelMedium.copyWith(
                          color: AppColors.primaryDark,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
        final vehicleChart = _sectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Spesa per veicolo',
                  style: AppTextStyles.headlineSmall),
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                height: 310,
                child: _buildVehicleBarChart(vehicleChartData),
              ),
            ],
          ),
        );

        if (!wide) {
          return Column(
            children: [
              barChart,
              const SizedBox(height: AppSpacing.md),
              pieChart,
              const SizedBox(height: AppSpacing.md),
              vehicleChart,
            ],
          );
        }

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 7,
                child: Column(
                  children: [
                    barChart,
                    const SizedBox(height: AppSpacing.md),
                    vehicleChart,
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                flex: 4,
                child: pieChart,
              ),
            ],
          ),
        );
      },
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

  Widget _buildBarChart(List<_DriverCostSummary> summaries) {
    if (summaries.isEmpty) {
      return const Center(
        child: Text('Nessun driver nel grafico',
            style: TextStyle(color: AppColors.grey500)),
      );
    }

    final maxY = summaries
        .map((summary) => summary.totaleVisibile)
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
          touchCallback: (event, response) {
            if (event is! FlTapUpEvent || response?.spot == null) return;
            final index = response!.spot!.touchedBarGroupIndex;
            if (index < 0 || index >= summaries.length) return;
            final summary = summaries[index];
            if (summary.driverId <= 0) return;

            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DettaglioCostiDriver(
                  idDriver: summary.driverId,
                  nomeDriver: summary.nomeDriver,
                  rangeIniziale: _rangeSelezionato,
                ),
              ),
            );
          },
          touchTooltipData: BarTouchTooltipData(
            tooltipBgColor: AppColors.grey800,
            tooltipRoundedRadius: AppSpacing.radiusMedium,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final summary = summaries[groupIndex];
              return BarTooltipItem(
                '${summary.nomeDriver}\n',
                const TextStyle(
                    color: AppColors.white, fontWeight: FontWeight.bold),
                children: [
                  TextSpan(
                    text: _money.format(summary.totaleVisibile),
                    style: const TextStyle(
                      color: AppColors.secondaryLight,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 52,
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
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= summaries.length) {
                  return const SizedBox.shrink();
                }
                return SideTitleWidget(
                  axisSide: meta.axisSide,
                  space: 10,
                  child: SizedBox(
                    width: 56,
                    child: Text(
                      summaries[index].nomeDriver.split(' ').first,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.captionSmall.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: List.generate(summaries.length, (index) {
          final summary = summaries[index];
          final fuelEnd = _categorie.contains(_CostCategory.carburante)
              ? summary.carburante
              : 0.0;
          final tollEnd = fuelEnd +
              (_categorie.contains(_CostCategory.pedaggi)
                  ? summary.pedaggi
                  : 0.0);

          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: summary.totaleVisibile,
                width: 24,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(6)),
                rodStackItems: [
                  if (_categorie.contains(_CostCategory.carburante))
                    BarChartRodStackItem(
                      0,
                      fuelEnd,
                      AppColors.secondary,
                    ),
                  if (_categorie.contains(_CostCategory.pedaggi))
                    BarChartRodStackItem(
                      fuelEnd,
                      tollEnd,
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

  Widget _buildVehicleBarChart(List<_VehicleCostSummary> summaries) {
    if (summaries.isEmpty) {
      return const Center(
        child: Text('Nessun veicolo nel grafico',
            style: TextStyle(color: AppColors.grey500)),
      );
    }

    final maxY = summaries
        .map((summary) => summary.totaleVisibile)
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
          touchCallback: (event, response) {
            if (event is! FlTapUpEvent || response?.spot == null) return;
            final index = response!.spot!.touchedBarGroupIndex;
            if (index < 0 || index >= summaries.length) return;
            final summary = summaries[index];

            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DettaglioCostiVeicolo(
                  targa: summary.targa,
                  nomeVeicolo: summary.vehicleLabel,
                  rangeIniziale: _rangeSelezionato,
                ),
              ),
            );
          },
          touchTooltipData: BarTouchTooltipData(
            tooltipBgColor: AppColors.grey800,
            tooltipRoundedRadius: AppSpacing.radiusMedium,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final summary = summaries[groupIndex];
              return BarTooltipItem(
                '${summary.vehicleLabel}\n',
                const TextStyle(
                    color: AppColors.white, fontWeight: FontWeight.bold),
                children: [
                  TextSpan(
                    text: _money.format(summary.totaleVisibile),
                    style: const TextStyle(
                      color: AppColors.secondaryLight,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 52,
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
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= summaries.length) {
                  return const SizedBox.shrink();
                }
                return SideTitleWidget(
                  axisSide: meta.axisSide,
                  space: 10,
                  child: SizedBox(
                    width: 68,
                    child: Text(
                      summaries[index].targa,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.captionSmall.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: List.generate(summaries.length, (index) {
          final summary = summaries[index];
          final fuelEnd = _categorie.contains(_CostCategory.carburante)
              ? summary.carburante
              : 0.0;
          final tollEnd = fuelEnd +
              (_categorie.contains(_CostCategory.pedaggi)
                  ? summary.pedaggi
                  : 0.0);

          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: summary.totaleVisibile,
                width: 24,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(6)),
                rodStackItems: [
                  if (_categorie.contains(_CostCategory.carburante))
                    BarChartRodStackItem(
                      0,
                      fuelEnd,
                      AppColors.secondary,
                    ),
                  if (_categorie.contains(_CostCategory.pedaggi))
                    BarChartRodStackItem(
                      fuelEnd,
                      tollEnd,
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

  Widget _buildPieChart(_CostTotals totals) {
    if (totals.totale <= 0) {
      return const Center(
        child: Text('Nessuna composizione disponibile',
            style: TextStyle(color: AppColors.grey500)),
      );
    }

    return PieChart(
      PieChartData(
        sectionsSpace: 3,
        centerSpaceRadius: 46,
        sections: [
          if (totals.carburante > 0)
            PieChartSectionData(
              value: totals.carburante,
              color: AppColors.secondary,
              title: '${(totals.carburante / totals.totale * 100).round()}%',
              radius: 58,
              titleStyle: const TextStyle(
                color: AppColors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          if (totals.pedaggi > 0)
            PieChartSectionData(
              value: totals.pedaggi,
              color: AppColors.primaryLight,
              title: '${(totals.pedaggi / totals.totale * 100).round()}%',
              radius: 58,
              titleStyle: const TextStyle(
                color: AppColors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
        ],
      ),
    );
  }

  void _openChartsDashboard({
    required List<_DriverCostSummary> summaries,
    required List<_VehicleCostSummary> vehicleSummaries,
    required _CostTotals totals,
    required List<_CostRecord> records,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GraficiCostiScreen(
          periodLabel:
              '${_fullDate.format(_rangeSelezionato.start)} - ${_fullDate.format(_rangeSelezionato.end)}',
          carburante: totals.carburante,
          pedaggi: totals.pedaggi,
          movimenti: records.length,
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
          dailyData: _buildDailyChartData(records),
          weekdayData: _buildWeekdayChartData(records),
          initialRange: _rangeSelezionato,
          initialDriverIds: {..._driverSelezionatiSicuri},
          initialVehiclePlates: {..._targheSelezionateSicure},
          initialVehicleType: _tipoVeicoloSelezionato,
          initialCategories:
              _categorie.map((category) => category.name).toSet(),
          initialSort: _ordinamento.name,
          initialPeriodPreset: _periodPreset.name,
        ),
      ),
    );
  }

  Widget _buildDriverList(List<_DriverCostSummary> summaries) {
    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Ranking driver', style: AppTextStyles.headlineSmall),
          const SizedBox(height: AppSpacing.md),
          ...summaries.map((summary) {
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Material(
                color: AppColors.grey50,
                borderRadius: BorderRadius.circular(AppSpacing.radiusDefault),
                child: ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radiusDefault),
                  ),
                  leading: CircleAvatar(
                    backgroundColor:
                        AppColors.primaryLight.withValues(alpha: 0.12),
                    child: const Icon(Icons.person_outline,
                        color: AppColors.primaryDark),
                  ),
                  title: Text(
                    summary.nomeDriver,
                    style: AppTextStyles.titleMedium,
                  ),
                  subtitle: Text(
                    'Carburante ${_money.format(summary.carburante)} - Pedaggi ${_money.format(summary.pedaggi)} - ${summary.movimenti} movimenti',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Text(
                    _money.format(summary.totaleVisibile),
                    style: AppTextStyles.titleMedium.copyWith(
                      color: AppColors.primaryDark,
                    ),
                  ),
                  onTap: summary.driverId <= 0
                      ? null
                      : () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DettaglioCostiDriver(
                                idDriver: summary.driverId,
                                nomeDriver: summary.nomeDriver,
                                rangeIniziale: _rangeSelezionato,
                              ),
                            ),
                          ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildRecentMovements(List<_CostRecord> records) {
    final recent = [...records]..sort((a, b) => b.restituzione.dataRestituzione
        .compareTo(a.restituzione.dataRestituzione));

    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Movimenti recenti', style: AppTextStyles.headlineSmall),
          const SizedBox(height: AppSpacing.md),
          ...recent.take(8).map((record) {
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                record.restituzione.isEmergenza
                    ? Icons.warning_amber_rounded
                    : Icons.receipt_long_outlined,
                color: record.restituzione.isEmergenza
                    ? AppColors.error
                    : AppColors.primaryDark,
              ),
              title: Text(
                '${record.driverName} - ${record.targa}',
                style: AppTextStyles.titleMedium,
              ),
              subtitle: Text(
                '${_fullDate.format(record.restituzione.dataRestituzione)} - ${record.vehicleLabel}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Text(
                _money.format(_visibleTotal(record)),
                style: AppTextStyles.titleMedium,
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool noSourceData) {
    return _sectionCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
        child: Center(
          child: Column(
            children: [
              Icon(
                noSourceData
                    ? Icons.receipt_long_outlined
                    : Icons.filter_alt_off_outlined,
                size: 42,
                color: AppColors.grey400,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                noSourceData
                    ? 'Nessun costo registrato'
                    : 'Nessun risultato con questi filtri',
                style: AppTextStyles.headlineSmall.copyWith(
                  color: AppColors.grey700,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                noSourceData
                    ? 'I dati compariranno dopo le restituzioni con carburante o pedaggi.'
                    : 'Allarga il periodo o rimuovi qualche filtro per confrontare la flotta.',
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

  Widget _sectionCard({required Widget child, VoidCallback? onTap}) {
    final borderRadius = BorderRadius.circular(AppSpacing.radiusLarge);

    return Material(
      color: AppColors.white,
      borderRadius: borderRadius,
      child: InkWell(
        onTap: onTap,
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
      ),
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

  Widget _periodChip(_PeriodPreset preset) {
    final selected = _periodPreset == preset;

    return ChoiceChip(
      label: Text(_periodPresetLabel(preset)),
      avatar: const Icon(
        Icons.calendar_today_outlined,
        size: 16,
        color: AppColors.primaryDark,
      ),
      selected: selected,
      selectedColor: AppColors.primaryLight.withValues(alpha: 0.08),
      backgroundColor: AppColors.white,
      labelStyle: AppTextStyles.labelMedium.copyWith(
        color: AppColors.primaryDark,
        fontWeight: FontWeight.w700,
      ),
      side: BorderSide(
        color: selected ? AppColors.primaryLight : AppColors.border,
        width: selected ? 1.5 : 1,
      ),
      onSelected: (_) => _setPreset(preset),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusDefault),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
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
        color: selected ? activeColor : AppColors.grey600,
      ),
      label: Text(label),
      selected: selected,
      selectedColor: activeColor.withValues(alpha: 0.18),
      checkmarkColor: activeColor,
      labelStyle: AppTextStyles.labelMedium.copyWith(
        color: selected ? AppColors.grey900 : AppColors.grey700,
        fontWeight: FontWeight.w700,
      ),
      side: BorderSide(
        color: selected ? activeColor : AppColors.border,
      ),
      onSelected: onSelected,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusDefault),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
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

  Widget _legendRow(String label, double value, Color color) {
    final total = _categorie.isEmpty ? 0.0 : value;

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
          _money.format(total),
          style: AppTextStyles.titleSmall,
        ),
      ],
    );
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
                IconButton(
                  tooltip: 'Annulla',
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(dialogContext),
                ),
                IconButton(
                  tooltip: 'Applica',
                  icon: const Icon(Icons.check_rounded),
                  onPressed: () => Navigator.pop(
                    dialogContext,
                    DateTimeRange(start: start, end: end),
                  ),
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
                  Text(title),
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
                IconButton(
                  tooltip: 'Annulla',
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(dialogContext),
                ),
                IconButton(
                  tooltip: 'Applica',
                  icon: const Icon(Icons.check_rounded),
                  onPressed: () {
                    onApply(selected);
                    Navigator.pop(dialogContext);
                  },
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
