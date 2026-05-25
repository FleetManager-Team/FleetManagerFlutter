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
  String? _targaSelezionata;
  TipoVeicolo? _tipoVeicoloSelezionato;
  _CostSort _ordinamento = _CostSort.totaleDesc;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FleetProvider>();
    final records = _buildRecords(provider);
    final filteredRecords = _filterRecords(records);
    final summaries = _buildSummaries(filteredRecords);
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
        actions: [
          IconButton(
            tooltip: 'Reimposta filtri',
            icon: const Icon(Icons.restart_alt_rounded),
            onPressed: _resetFilters,
          ),
        ],
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
                _buildCharts(summaries, totals),
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
              const Text('Filtri analisi', style: AppTextStyles.headlineSmall),
              const Spacer(),
              IconButton(
                tooltip: 'Pulisci filtri',
                onPressed: _resetFilters,
                icon: const Icon(Icons.filter_alt_off_rounded),
              ),
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
                label: 'Targa',
                icon: Icons.directions_car_outlined,
                value: _selectedVehicleLabel(veicoli),
                onTap: () => _showSingleSelectMenu<String>(
                  includeAll: true,
                  currentValue: _targaSelezionata,
                  entries: veicoli
                      .map((veicolo) =>
                          _SelectOption(veicolo.targa, _vehicleLabel(veicolo)))
                      .toList(),
                  onSelected: (value) =>
                      setState(() => _targaSelezionata = value),
                ),
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
                      .map((tipo) => _SelectOption(tipo, _enumLabel(tipo.name)))
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

  Widget _buildCharts(List<_DriverCostSummary> summaries, _CostTotals totals) {
    final chartData = summaries.take(10).toList();

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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Composizione', style: AppTextStyles.headlineSmall),
              const SizedBox(height: AppSpacing.lg),
              SizedBox(height: 220, child: _buildPieChart(totals)),
              const SizedBox(height: AppSpacing.md),
              _legendRow('Carburante', totals.carburante, AppColors.secondary),
              const SizedBox(height: AppSpacing.sm),
              _legendRow('Pedaggi', totals.pedaggi, AppColors.primaryLight),
            ],
          ),
        );

        if (!wide) {
          return Column(
            children: [
              barChart,
              const SizedBox(height: AppSpacing.md),
              pieChart,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 7,
              child: barChart,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              flex: 4,
              child: pieChart,
            ),
          ],
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

  Widget _periodChip(_PeriodPreset preset) {
    final selected = _periodPreset == preset;

    return ChoiceChip(
      label: Text(_periodPresetLabel(preset)),
      avatar: Icon(
        Icons.calendar_today_outlined,
        size: 16,
        color: selected ? AppColors.white : AppColors.primaryDark,
      ),
      selected: selected,
      selectedColor: AppColors.primaryDark,
      backgroundColor: AppColors.white,
      labelStyle: AppTextStyles.labelMedium.copyWith(
        color: selected ? AppColors.white : AppColors.primaryDark,
        fontWeight: FontWeight.w700,
      ),
      side: BorderSide(
        color: selected ? AppColors.primaryDark : AppColors.border,
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

  String _vehicleLabel(Veicolo veicolo) {
    return '${veicolo.targa} - ${veicolo.marca} ${veicolo.modello}';
  }

  String _selectedVehicleLabel(List<Veicolo> veicoli) {
    if (_targaSelezionata == null) return 'Tutti';

    try {
      return _vehicleLabel(
        veicoli.firstWhere((veicolo) => veicolo.targa == _targaSelezionata),
      );
    } catch (_) {
      return _targaSelezionata!;
    }
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
      if (_targaSelezionata != null && record.targa != _targaSelezionata) {
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

  Future<void> _showDriverPicker(List<Utente> drivers) async {
    final selected = {..._driverSelezionatiSicuri};

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Seleziona driver'),
              content: SizedBox(
                width: 420,
                height: math.min(
                  MediaQuery.of(context).size.height * 0.72,
                  520.0,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CheckboxListTile(
                        value: selected.isEmpty,
                        title: const Text('Tutti i driver'),
                        controlAffinity: ListTileControlAffinity.leading,
                        onChanged: (_) {
                          setDialogState(() => selected.clear());
                        },
                      ),
                      const Divider(height: AppSpacing.lg),
                      ...drivers.map((driver) {
                        final isSelected = selected.contains(driver.idUtente);

                        return CheckboxListTile(
                          value: isSelected,
                          title: Text(_driverName(driver)),
                          subtitle: driver.email.isEmpty
                              ? null
                              : Text(
                                  driver.email,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                          controlAffinity: ListTileControlAffinity.leading,
                          onChanged: (value) {
                            setDialogState(() {
                              if (value == true) {
                                selected.add(driver.idUtente);
                              } else {
                                selected.remove(driver.idUtente);
                              }
                            });
                          },
                        );
                      }),
                    ],
                  ),
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
                    setState(() {
                      _driverSelezionatiSicuri
                        ..clear()
                        ..addAll(selected);
                    });
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
      _targaSelezionata = null;
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
