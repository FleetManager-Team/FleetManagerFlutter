import 'dart:math' as math;

import 'package:fleetmanager/core/theme/index.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class GraficiCostiScreen extends StatelessWidget {
  final String periodLabel;
  final double carburante;
  final double pedaggi;
  final int movimenti;
  final List<CostChartAmount> driverData;
  final List<CostChartAmount> vehicleData;
  final List<CostChartDay> dailyData;
  final List<CostChartAmount> weekdayData;

  GraficiCostiScreen({
    super.key,
    required this.periodLabel,
    required this.carburante,
    required this.pedaggi,
    required this.movimenti,
    required this.driverData,
    required this.vehicleData,
    required this.dailyData,
    required this.weekdayData,
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
    return Scaffold(
      backgroundColor: AppColors.grey100,
      appBar: AppBar(
        title: const Text('Grafici costi'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(),
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
                  accent: AppColors.primaryLight,
                  child: _dailyTrendChart(),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            _responsiveGrid(
              minHeight: 390,
              children: [
                _chartCard(
                  title: 'Top driver',
                  subtitle: 'Driver con maggiore incidenza sui costi',
                  icon: Icons.person_outline,
                  accent: AppColors.primaryLight,
                  child: _stackedBarChart(driverData.take(10).toList()),
                ),
                _chartCard(
                  title: 'Top veicoli',
                  subtitle: 'Veicoli con maggiore spesa nel periodo',
                  icon: Icons.directions_car_outlined,
                  accent: AppColors.success,
                  child: _stackedBarChart(vehicleData.take(10).toList()),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            _responsiveGrid(
              minHeight: 340,
              children: [
                _chartCard(
                  title: 'Distribuzione settimanale',
                  subtitle: 'Concentrazione dei costi per giorno',
                  icon: Icons.calendar_view_week_outlined,
                  accent: AppColors.primaryDark,
                  child: _stackedBarChart(weekdayData),
                ),
                _chartCard(
                  title: 'Confronto categorie',
                  subtitle: 'Lettura diretta tra carburante e pedaggi',
                  icon: Icons.compare_arrows_rounded,
                  accent: AppColors.secondary,
                  child: _categoryComparisonChart(),
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

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 760;

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
                  borderRadius: BorderRadius.circular(AppSpacing.radiusRound),
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
                style:
                    AppTextStyles.displaySmall.copyWith(color: AppColors.white),
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
                  style: AppTextStyles.displayMedium.copyWith(
                    color: AppColors.white,
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
          children: items
              .map((item) => SizedBox(width: width, child: item))
              .toList(),
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
        final columns = constraints.maxWidth >= 900 ? 4 : 2;
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
                  width: (constraints.maxWidth -
                          AppSpacing.md * (columns - 1)) /
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
        if (constraints.maxWidth < 980) {
          return Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                SizedBox(height: minHeight, child: children[i]),
                if (i != children.length - 1)
                  const SizedBox(height: AppSpacing.lg),
              ],
            ],
          );
        }

        return SizedBox(
          height: minHeight,
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
  }) {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 4,
            width: 48,
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
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.11),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                ),
                child: Icon(icon, color: accent, size: 20),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTextStyles.headlineSmall),
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
          const SizedBox(height: AppSpacing.lg),
          Expanded(child: child),
        ],
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
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  sectionsSpace: 4,
                  centerSpaceRadius: 62,
                  sections: [
                    if (carburante > 0)
                      PieChartSectionData(
                        value: carburante,
                        color: AppColors.secondary,
                        radius: 72,
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
                        radius: 72,
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
                            color: AppColors.primaryLight,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        TextSpan(
                          text:
                              'Carburante ${_money.format(day.carburante)}\n',
                          style: const TextStyle(
                            color: AppColors.secondaryLight,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        TextSpan(
                          text: 'Pedaggi ${_money.format(day.pedaggi)}',
                          style: const TextStyle(
                            color: AppColors.white,
                            fontWeight: FontWeight.w600,
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
                  color: AppColors.primaryDark,
                  barWidth: 3,
                  dotData: FlDotData(
                    show: dailyData.length <= 12,
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    color: AppColors.primaryLight.withValues(alpha: 0.10),
                  ),
                ),
                LineChartBarData(
                  spots: List.generate(
                    dailyData.length,
                    (index) => FlSpot(
                        index.toDouble(), dailyData[index].carburante),
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
        Row(
          children: [
            _compactLegend('Totale', AppColors.primaryDark),
            const SizedBox(width: AppSpacing.md),
            _compactLegend('Carburante', AppColors.secondary),
            const SizedBox(width: AppSpacing.md),
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

  Widget _stackedBarChart(List<CostChartAmount> entries) {
    final visibleEntries = entries.where((entry) => entry.totale > 0).toList();
    if (visibleEntries.isEmpty) return _emptyChart('Nessun dato disponibile');

    final maxY =
        visibleEntries.map((entry) => entry.totale).fold<double>(0, math.max);
    final interval = _chartInterval(maxY);

    return BarChart(
      BarChartData(
        maxY: maxY <= 0 ? 10 : maxY * 1.18,
        alignment: BarChartAlignment.spaceAround,
        gridData: FlGridData(
          drawVerticalLine: false,
          horizontalInterval: interval,
          getDrawingHorizontalLine: (_) => const FlLine(
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
              final entry = visibleEntries[groupIndex];
              return BarTooltipItem(
                '${entry.label}\n',
                const TextStyle(
                    color: AppColors.white, fontWeight: FontWeight.bold),
                children: [
                  if (entry.subtitle != null)
                    TextSpan(
                      text: '${entry.subtitle}\n',
                      style: const TextStyle(
                        color: AppColors.grey200,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  TextSpan(
                    text: _money.format(entry.totale),
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
              reservedSize: 44,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= visibleEntries.length) {
                  return const SizedBox.shrink();
                }
                return SideTitleWidget(
                  axisSide: meta.axisSide,
                  space: 10,
                  child: SizedBox(
                    width: 70,
                    child: Text(
                      visibleEntries[index].label,
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
        barGroups: List.generate(visibleEntries.length, (index) {
          final entry = visibleEntries[index];
          final fuelEnd = entry.carburante;
          final tollEnd = entry.totale;

          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: entry.totale,
                width: 24,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(6)),
                rodStackItems: [
                  if (entry.carburante > 0)
                    BarChartRodStackItem(
                      0,
                      fuelEnd,
                      AppColors.secondary,
                    ),
                  if (entry.pedaggi > 0)
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

  Widget _categoryComparisonChart() {
    if (totale <= 0) return _emptyChart('Nessun dato disponibile');
    final maxY = math.max(carburante, pedaggi);
    final interval = _chartInterval(maxY);
    final entries = [
      CostChartAmount(label: 'Carburante', carburante: carburante),
      CostChartAmount(label: 'Pedaggi', pedaggi: pedaggi),
    ];

    return BarChart(
      BarChartData(
        maxY: maxY <= 0 ? 10 : maxY * 1.18,
        alignment: BarChartAlignment.spaceAround,
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
              reservedSize: 38,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= entries.length) {
                  return const SizedBox.shrink();
                }
                return SideTitleWidget(
                  axisSide: meta.axisSide,
                  space: 10,
                  child: Text(
                    entries[index].label,
                    style: AppTextStyles.captionSmall.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: List.generate(entries.length, (index) {
          final entry = entries[index];
          final color =
              entry.carburante > 0 ? AppColors.secondary : AppColors.primaryLight;

          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: entry.totale,
                width: 44,
                color: color,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(8)),
              ),
            ],
          );
        }),
      ),
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
