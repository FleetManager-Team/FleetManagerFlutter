import 'package:fleetmanager/provider/fleet_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

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
    final datiDriver = provider.getSpesaFiltrata(
      inizio: _rangeSelezionato.start,
      fine: _rangeSelezionato.end,
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
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: [Colors.blue.shade900, Colors.blue.shade700]),
        borderRadius: BorderRadius.circular(20),
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
    return SizedBox(
      height: 300,
      child: BarChart(
        BarChartData(
          barGroups: List.generate(dati.length, (index) {
            final spesa = dati.values.elementAt(index);
            // Calcoliamo l'altezza totale visibile in base ai filtri
            double altezzaVisibile = 0;
            if (_mostraCarburante) altezzaVisibile += spesa.carburante;
            if (_mostraPedaggi) altezzaVisibile += spesa.pedaggi;

            return BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: altezzaVisibile,
                  width: 25,
                  rodStackItems: [
                    if (_mostraCarburante)
                      BarChartRodStackItem(
                          0, spesa.carburante, Colors.orange.shade700),
                    if (_mostraPedaggi)
                      BarChartRodStackItem(
                          _mostraCarburante ? spesa.carburante : 0,
                          _mostraCarburante ? spesa.totale : spesa.pedaggi,
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.grey.shade300),
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
                size: 16, color: Colors.blue.shade900),
            const SizedBox(width: 10),
            Text(
              "${DateFormat('dd/MM/yy').format(_rangeSelezionato.start)} - ${DateFormat('dd/MM/yy').format(_rangeSelezionato.end)}",
              style: TextStyle(
                color: Colors.blue.shade900,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(width: 5),
            const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
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
