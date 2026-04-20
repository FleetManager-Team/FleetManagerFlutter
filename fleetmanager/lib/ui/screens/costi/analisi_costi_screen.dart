import 'package:fleetmanager/provider/fleet_provider.dart';
import 'package:fleetmanager/ui/screens/costi/dettaglio_costi_driver.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:fleetmanager/core/theme/index.dart';

class AnalisiCostiScreen extends StatefulWidget {
  const AnalisiCostiScreen({super.key});

  @override
  State<AnalisiCostiScreen> createState() => _AnalisiCostiScreenState();
}

class _AnalisiCostiScreenState extends State<AnalisiCostiScreen> {
  DateTimeRange _rangeSelezionato = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 30)),
    end: DateTime.now(),
  );

  bool _mostraCarburante = true;
  bool _mostraPedaggi = true;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FleetProvider>();

    // Prendiamo i dati completi
    // 1. Prendi tutti i dati dal provider
    final Map<String, SpesaDriver> tuttiIDati = provider.getSpesaFiltrata(
      inizio: _rangeSelezionato.start,
      fine: _rangeSelezionato.end,
    );

    // 2. CREA UNA MAPPA FILTRATA: tieni solo chi ha spesa > 0 basandoti sui filtri UI
    final Map<String, SpesaDriver> datiDriver = Map.fromEntries(
      tuttiIDati.entries.where((entry) {
        double totaleVisibile = 0;
        if (_mostraCarburante) totaleVisibile += entry.value.carburante;
        if (_mostraPedaggi) totaleVisibile += entry.value.pedaggi;
        return totaleVisibile > 0; // Fondamentale: se è 0, sparisce dal grafico
      }),
    );

    // Calcoliamo il totale pesando i filtri della UI
    double totalePeriodo = 0;
    datiDriver.forEach((key, spesa) {
      if (_mostraCarburante) totalePeriodo += spesa.carburante;
      if (_mostraPedaggi) totalePeriodo += spesa.pedaggi;
    });

    return Scaffold(
      appBar: AppBar(title: const Text("Analisi Costi")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [_buildPickerPeriodo(), _buildFiltriTipologia()],
            ),
            const SizedBox(height: 20),
            _buildCardTotale(totalePeriodo),
            const SizedBox(height: 30),
            if (datiDriver.isEmpty)
              const Center(child: Text("Nessun dato"))
            else ...[
              _buildGrafico(datiDriver),
              const SizedBox(height: 30),
              _buildLista(datiDriver),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildCardTotale(double totale) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: [AppColors.primaryDark, AppColors.primaryDark]),
        borderRadius: BorderRadius.circular(AppSpacing.radiusXLarge),
      ),
      child: Column(
        children: [
          const Text("SPESA CARBURANTE NEL PERIODO",
              style: TextStyle(color: Colors.white70, fontSize: 12)),
          Text("€ ${totale.toStringAsFixed(2)}",
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildGrafico(Map<String, SpesaDriver> dati) {
    // 1. SE LA MAPPA È VUOTA, NON DISEGNARE NULLA (evita nomi senza barre)
    if (dati.isEmpty) {
      return const SizedBox(
        height: 300,
        child: Center(
          child: Text(
            "Nessun dato disponibile per questo periodo",
            style: TextStyle(color: AppColors.grey500),
          ),
        ),
      );
    }

    return SizedBox(
      height: 300,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,

          // --- TOOLTIP DINAMICO ---
          barTouchData: BarTouchData(
            touchCallback: (FlTouchEvent event, barResponse) {
              if (!event.isInterestedForInteractions ||
                  barResponse == null ||
                  barResponse.spot == null) {
                return;
              }

              if (event is FlTapUpEvent) {
                final int index = barResponse.spot!.touchedBarGroupIndex;

                final int idDelDriver = dati.values.elementAt(index).idUtente;
                final String nomeDelDriver = dati.keys.elementAt(index);

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DettaglioCostiDriver(
                      idDriver: idDelDriver,
                      nomeDriver: nomeDelDriver,
                      rangeIniziale: _rangeSelezionato,
                    ),
                  ),
                );
              }
            },
            touchTooltipData: BarTouchTooltipData(
              tooltipRoundedRadius: 8,
              // Se tooltipBgColor dà errore, cancellalo o usa tooltipColor
              tooltipBgColor: AppColors.grey800,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final nome = dati.keys.elementAt(groupIndex);
                final spesa = dati.values.elementAt(groupIndex);

                Color coloreTesto;
                if (_mostraCarburante && !_mostraPedaggi) {
                  coloreTesto = AppColors.secondaryLight;
                } else if (!_mostraCarburante && _mostraPedaggi) {
                  coloreTesto = AppColors.primaryLight;
                } else {
                  coloreTesto = spesa.carburante >= spesa.pedaggi
                      ? AppColors.secondaryLight
                      : AppColors.primaryLight;
                }

                return BarTooltipItem(
                  '$nome\n',
                  const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                  children: [
                    TextSpan(
                      text: '€ ${rod.toY.toStringAsFixed(2)}',
                      style: TextStyle(
                          color: coloreTesto, fontWeight: FontWeight.w500),
                    ),
                  ],
                );
              },
            ),
          ),

          // --- TITOLI (NOMI DRIVER DINAMICI) ---
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
                  // Verifichiamo SEMPRE che l'indice esista nella mappa attuale
                  if (index >= 0 && index < dati.length) {
                    String nome = dati.keys.elementAt(index);
                    return SideTitleWidget(
                      axisSide: meta.axisSide,
                      space: 10,
                      child: Text(
                        nome.split(' ')[0], // Prende solo il primo nome
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
                  // MODIFICA QUI: Mostra il titolo solo se è un numero intero
                  // Se vuoi toglierli del tutto, imposta showTitles: false sopra
                  if (value % 1 == 0 && value > 0) {
                    return Text("€${value.toInt()}",
                        style:
                            const TextStyle(fontSize: 10, color: Colors.grey));
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),

          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),

          // --- GENERAZIONE DELLE BARRE (SOLO QUELLE CHE ESISTONO) ---
          barGroups: List.generate(dati.length, (index) {
            final spesa = dati.values.elementAt(index);

            double altezzaVisibile = 0;
            if (_mostraCarburante) altezzaVisibile += spesa.carburante;
            if (_mostraPedaggi) altezzaVisibile += spesa.pedaggi;

            return BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: altezzaVisibile,
                  width: 22,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(4)),
                  rodStackItems: [
                    if (_mostraCarburante)
                      BarChartRodStackItem(
                          0, spesa.carburante, Colors.orange.shade700),
                    if (_mostraPedaggi)
                      BarChartRodStackItem(
                          _mostraCarburante ? spesa.carburante : 0,
                          altezzaVisibile,
                          Colors.blue.shade700),
                  ],
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget _buildPickerPeriodo() {
    return PopupMenuButton<String>(
      onSelected: _impostaPeriodoPreset,
      offset: const Offset(0, 45), // Sposta la tendina leggermente in basso
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusLarge)),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppSpacing.radiusRound),
          border: Border.all(color: AppColors.grey300),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_today_outlined,
                size: 16, color: AppColors.primaryDark),
            const SizedBox(width: 10),
            Text(
              "${DateFormat('dd/MM/yy').format(_rangeSelezionato.start)} - ${DateFormat('dd/MM/yy').format(_rangeSelezionato.end)}",
              style: TextStyle(
                color: AppColors.primaryDark,
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

  Widget _buildFiltriTipologia() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        FilterChip(
          label: const Text("Carburante"),
          selected: _mostraCarburante,
          selectedColor: Colors.orange.shade200,
          checkmarkColor: Colors.orange.shade900,
          onSelected: (bool value) {
            setState(() => _mostraCarburante = value);
          },
        ),
        const SizedBox(width: 10),
        FilterChip(
          label: const Text("Pedaggi"),
          selected: _mostraPedaggi,
          selectedColor: Colors.lightBlue.shade200,
          checkmarkColor: Colors.blue.shade900,
          onSelected: (bool value) {
            setState(() => _mostraPedaggi = value);
          },
        ),
      ],
    );
  }

  Widget _buildLista(Map<String, SpesaDriver> dati) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: dati.length,
      itemBuilder: (context, index) {
        final nome = dati.keys.elementAt(index);
        final spesa = dati.values.elementAt(index);
        double totaleMostrato = 0;
        if (_mostraCarburante) totaleMostrato += spesa.carburante;
        if (_mostraPedaggi) totaleMostrato += spesa.pedaggi;

        if (totaleMostrato == 0) return const SizedBox.shrink();

        return Card(
          child: ListTile(
            title: Text(nome),
            subtitle: Text(
                "Benzina: €${spesa.carburante.toStringAsFixed(2)} | Pedaggi: €${spesa.pedaggi.toStringAsFixed(2)}"),
            trailing: Text("€ ${totaleMostrato.toStringAsFixed(2)}",
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        );
      },
    );
  }
}
