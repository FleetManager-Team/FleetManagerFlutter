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

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FleetProvider>();
    final datiDriver = provider.getSpesaCarburanteFiltrata(_rangeSelezionato.start, _rangeSelezionato.end);
    double totalePeriodo = datiDriver.values.fold(0.0, (a, b) => a + b);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Analisi Costi"),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: () async {
              final picked = await showDateRangePicker(
                context: context,
                initialDateRange: _rangeSelezionato,
                firstDate: DateTime(2023),
                lastDate: DateTime.now().add(const Duration(days: 1)),
              );
              if (picked != null) setState(() => _rangeSelezionato = picked);
            },
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              "Periodo: ${DateFormat('dd/MM/yy').format(_rangeSelezionato.start)} - ${DateFormat('dd/MM/yy').format(_rangeSelezionato.end)}",
              style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            _buildCardTotale(totalePeriodo),
            const SizedBox(height: 30),
            if (datiDriver.isEmpty)
              const Center(child: Padding(padding: EdgeInsets.all(50), child: Text("Nessun dato per questo periodo")))
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
        gradient: LinearGradient(colors: [Colors.blue.shade900, Colors.blue.shade700]),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const Text("SPESA CARBURANTE NEL PERIODO", style: TextStyle(color: Colors.white70, fontSize: 12)),
          Text("€ ${totale.toStringAsFixed(2)}", style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildGrafico(Map<String, double> dati) {
    return SizedBox(
      height: 250,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: (dati.values.reduce((a, b) => a > b ? a : b)) * 1.2,
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  if (value.toInt() >= dati.length) return const SizedBox();
                  return Text(dati.keys.elementAt(value.toInt()).split(' ').first, style: const TextStyle(fontSize: 10));
                },
              ),
            ),
          ),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          barGroups: List.generate(dati.length, (index) => BarChartGroupData(
            x: index,
            barRods: [BarChartRodData(toY: dati.values.elementAt(index), color: Colors.blueAccent, width: 18, borderRadius: BorderRadius.circular(4))],
          )),
        ),
      ),
    );
  }

  Widget _buildLista(Map<String, double> dati) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: dati.length,
      itemBuilder: (context, index) {
        return Card(
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.local_gas_station)),
            title: Text(dati.keys.elementAt(index)),
            trailing: Text("€ ${dati.values.elementAt(index).toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        );
      },
    );
  }
}