import 'package:FleetManager/provider/fleet_provider.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart'; // Ti serve per formattare le date sotto il grafico
import 'package:FleetManager/core/theme/index.dart';

class DettaglioCostiDriver extends StatefulWidget {
  final int idDriver;
  final String nomeDriver;
  final DateTimeRange rangeIniziale;

  const DettaglioCostiDriver({
    super.key,
    required this.idDriver,
    required this.nomeDriver,
    required this.rangeIniziale,
  });

  @override
  State<DettaglioCostiDriver> createState() => _DettaglioCostiDriverState();
}

class _DettaglioCostiDriverState extends State<DettaglioCostiDriver> {
  late DateTimeRange _rangeSelezionato;
  bool _mostraCarburante = true;
  bool _mostraPedaggi = true;

  @override
  void initState() {
    super.initState();
    _rangeSelezionato = widget.rangeIniziale;
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FleetProvider>(context);

    // Recuperiamo i dati raggruppati per GIORNO per questo specifico driver
    final Map<DateTime, SpesaDriver> datiTemporali =
        provider.getSpesaTemporaleDriver(
      idDriver: widget.idDriver,
      inizio: _rangeSelezionato.start,
      fine: _rangeSelezionato.end,
    );

    double totale = datiTemporali.values.fold(0, (sum, item) {
      double parziale = 0;
      if (_mostraCarburante) parziale += item.carburante;
      if (_mostraPedaggi) parziale += item.pedaggi;
      return sum + parziale;
    });

    return Scaffold(
      appBar: AppBar(
        title: Text("Dettaglio: ${widget.nomeDriver}"),
        backgroundColor: AppColors.primaryDark,
        foregroundColor: AppColors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [_buildPickerPeriodo()],
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusLarge)),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    children: [
                      const SizedBox(height: 10),
                      Text(
                        "Totale Periodo: € ${totale.toStringAsFixed(2)}",
                        style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary),
                      ),
                      const SizedBox(height: 20),
                      _buildGraficoTemporale(datiTemporali),
                      const SizedBox(height: 20),
                      _buildFiltri(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGraficoTemporale(Map<DateTime, SpesaDriver> dati) {
    // 1. FILTRIAMO LA MAPPA: teniamo solo le date che hanno un importo > 0
    // in base ai toggle (Carburante/Pedaggi) attivi.
    final Map<DateTime, SpesaDriver> datiFiltrati = Map.fromEntries(
      dati.entries.where((entry) {
        double totale = 0;
        if (_mostraCarburante) totale += entry.value.carburante;
        if (_mostraPedaggi) totale += entry.value.pedaggi;
        return totale > 0; // Se è 0, la data viene ESCLUSA dal grafico
      }),
    );

    // 2. CREIAMO LA LISTA DELLE DATE ORDINATE (Solo quelle con dati!)
    final dateOrdinate = datiFiltrati.keys.toList()..sort();

    if (dateOrdinate.isEmpty) {
      return const SizedBox(
        height: 300,
        child: Center(
          child: Text("Nessun dato disponibile con i filtri selezionati",
              style: TextStyle(color: AppColors.grey500)),
        ),
      );
    }

    return SizedBox(
      height: 300,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,

          // --- TOOLTIP (Identico al primo grafico) ---
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              tooltipRoundedRadius: 8,
              tooltipBgColor: AppColors.grey800,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final data = dateOrdinate[groupIndex];
                final dataStr = DateFormat('dd/MM/yyyy').format(data);
                return BarTooltipItem(
                  '$dataStr\n€ ${rod.toY.toStringAsFixed(2)}',
                  const TextStyle(
                      color: AppColors.white, fontWeight: FontWeight.bold),
                );
              },
            ),
          ),

          // --- TITOLI DINAMICI (Uguale ai Driver) ---
          titlesData: FlTitlesData(
            show: true,
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (double value, TitleMeta meta) {
                  int index = value.toInt();
                  // Se l'indice non esiste nella nostra lista FILTRATA, non scriviamo nulla
                  if (index >= 0 && index < dateOrdinate.length) {
                    return SideTitleWidget(
                      axisSide: meta.axisSide,
                      space: 10,
                      child: Text(
                        DateFormat('dd/MM').format(dateOrdinate[index]),
                        style: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
                  // Scala identica al primo grafico
                  if (value % 1 == 0 && value > 0) {
                    return Text("€${value.toInt()}",
                        style:
                            const TextStyle(fontSize: 10, color: AppColors.grey500));
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),

          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),

          // --- GENERAZIONE BARRE (Usa solo date con dati) ---
          barGroups: List.generate(dateOrdinate.length, (index) {
            final data = dateOrdinate[index];
            final spesa = datiFiltrati[data]!;

            double altezza = 0;
            if (_mostraCarburante) altezza += spesa.carburante;
            if (_mostraPedaggi) altezza += spesa.pedaggi;

            return BarChartGroupData(
              x: index, // <--- SEQUENZIALE: 0, 1, 2... Niente buchi!
              barRods: [
                BarChartRodData(
                  toY: altezza,
                  width: 22,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(4)),
                  rodStackItems: [
                    if (_mostraCarburante)
                      BarChartRodStackItem(
                          0, spesa.carburante, AppColors.secondary),
                    if (_mostraPedaggi)
                      BarChartRodStackItem(
                        _mostraCarburante ? spesa.carburante : 0,
                        altezza,
                        AppColors.primaryDark,
                      ),
                  ],
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  void _impostaPeriodoPreset(String scelta) {
    DateTime fine = DateTime.now();
    DateTime inizio;

    switch (scelta) {
      case 'Oggi':
        inizio = DateTime(fine.year, fine.month, fine.day);
        break;
      case 'Ultima Settimana': // <--- AGGIUNTO
        inizio = fine.subtract(const Duration(days: 7));
        break;
      case 'Ultimo Mese':
        inizio = fine.subtract(const Duration(days: 30));
        break;
      case 'Ultimo Trimestre':
        inizio = fine.subtract(const Duration(days: 90));
        break;
      case 'Ultimo Anno':
        inizio = fine.subtract(const Duration(days: 365));
        break;
      default:
        return;
    }

    setState(() {
      _rangeSelezionato = DateTimeRange(start: inizio, end: fine);
    });
  }

  Widget _buildPickerPeriodo() {
    return PopupMenuButton<String>(
      onSelected: _impostaPeriodoPreset,
      offset: const Offset(0, 45), // Sposta la tendina leggermente in basso
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusLarge)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppSpacing.radiusRound),
          border: Border.all(color: AppColors.grey300),
          boxShadow: [
            BoxShadow(
              color: AppColors.grey900..withValues(alpha:0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.calendar_today_outlined,
                size: 16, color: AppColors.primary),
            const SizedBox(width: 10),
            Text(
              "${DateFormat('dd/MM/yy').format(_rangeSelezionato.start)} - ${DateFormat('dd/MM/yy').format(_rangeSelezionato.end)}",
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(width: 5),
            const Icon(Icons.keyboard_arrow_down, color: AppColors.grey500),
          ],
        ),
      ),
      itemBuilder: (context) => [
        const PopupMenuItem(value: 'Oggi', child: Text('Oggi')),
        const PopupMenuItem(
            value: 'Ultima Settimana', child: Text('Ultima Settimana')),
        const PopupMenuItem(value: 'Ultimo Mese', child: Text('Ultimo Mese')),
        const PopupMenuItem(
            value: 'Ultimo Trimestre', child: Text('Ultimo Trimestre')),
        const PopupMenuItem(value: 'Ultimo Anno', child: Text('Ultimo Anno')),
      ],
    );
  }

  Widget _buildFiltri() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        FilterChip(
          label: const Text("Carburante"),
          selected: _mostraCarburante,
          onSelected: (v) => setState(() => _mostraCarburante = v),
          selectedColor: AppColors.secondary..withValues(alpha:0.2),
          checkmarkColor: AppColors.secondary,
        ),
        const SizedBox(width: 10),
        FilterChip(
          label: const Text("Pedaggi"),
          selected: _mostraPedaggi,
          onSelected: (v) => setState(() => _mostraPedaggi = v),
          selectedColor: AppColors.primary..withValues(alpha:0.2),
          checkmarkColor: AppColors.primary,
        ),
      ],
    );
  }
}
