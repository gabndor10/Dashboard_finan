// lib/screens/comparison_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:dashboard_financeiro/indicador.dart';
import 'package:dashboard_financeiro/main.dart'; // Importa fetchIndicadores e outras utilidades

class ComparisonScreen extends StatefulWidget {
  const ComparisonScreen({super.key});

  @override
  State<ComparisonScreen> createState() => _ComparisonScreenState();
}

class _ComparisonScreenState extends State<ComparisonScreen> {
  // Lista para armazenar as datas selecionadas para comparação
  List<DateTime> _selectedComparisonDates = [];
  // Mapa para armazenar os dados carregados para cada data
  Map<String, Future<IndicadoresFinanceiros>> _comparisonDataFutures = {};

  // Função para adicionar uma nova data de comparação
  Future<void> _addComparisonDate(BuildContext context) async {
    if (_selectedComparisonDates.length >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Máximo de 3 datas para comparação.')),
      );
      return;
    }

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );

    if (picked != null && !_selectedComparisonDates.contains(picked)) {
      setState(() {
        _selectedComparisonDates.add(picked);
        // Inicia a busca pelos dados para a nova data
        String dateStr = DateFormat('dd/MM/yyyy').format(picked);
        _comparisonDataFutures[dateStr] = fetchIndicadores(dataInicial: dateStr, dataFinal: dateStr);
      });
    }
  }

  // Função para remover uma data de comparação
  void _removeComparisonDate(DateTime dateToRemove) {
    setState(() {
      _selectedComparisonDates.remove(dateToRemove);
      _comparisonDataFutures.remove(DateFormat('dd/MM/yyyy').format(dateToRemove));
    });
  }

  // Função para calcular o IPCA acumulado dos últimos 12 meses
  // Recebe todos os dados coletados de IPCA para um período (ex: 5 anos)
  // e a data de referência para a qual se quer o acumulado de 12 meses.
  double _calculateIpcaAccumulated12Months(List<DadoSGS>? ipcaData, DateTime referenceDate) {
    if (ipcaData == null || ipcaData.isEmpty) return 0.0;

    // Filtra e parseia os dados para o cálculo
    List<Map<String, dynamic>> parsedIpca = [];
    for (var dado in ipcaData) {
      try {
        parsedIpca.add({
          'date': DateFormat('dd/MM/yyyy').parse(dado.data),
          'value': double.parse(dado.valor.replaceAll(',', '.')),
        });
      } catch (e) {
        print('Erro ao parsear IPCA para cálculo: $e');
      }
    }

    // Ordena os dados por data
    parsedIpca.sort((a, b) => a['date'].compareTo(b['date']));

    // Encontra os 12 meses anteriores à data de referência
    DateTime twelveMonthsAgo = DateTime(referenceDate.year - 1, referenceDate.month, referenceDate.day);
    if (referenceDate.day == 1) { // Se for o primeiro dia do mês, o acumulado é do mês anterior
      twelveMonthsAgo = DateTime(referenceDate.year, referenceDate.month - 12, 1);
    }

    List<double> relevantIpcas = [];
    for (var dataPoint in parsedIpca) {
      if (dataPoint['date'].isAfter(twelveMonthsAgo) && (dataPoint['date'].isBefore(referenceDate) || dataPoint['date'].isAtSameMomentAs(referenceDate))) {
        relevantIpcas.add(dataPoint['value']);
      }
    }
    
    // Cálculo do acumulado
    double accumulated = 1.0;
    for (var ipcaValue in relevantIpcas) {
      accumulated *= (1 + (ipcaValue / 100));
    }
    return (accumulated - 1) * 100;
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Comparar Indicadores'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton(
              onPressed: () => _addComparisonDate(context),
              child: const Text('Adicionar Data para Comparação'),
            ),
          ),
          if (_selectedComparisonDates.isNotEmpty)
            Container(
              height: 50, // Altura fixa para os chips de data
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _selectedComparisonDates.length,
                itemBuilder: (context, index) {
                  final date = _selectedComparisonDates[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: Chip(
                      label: Text(DateFormat('dd/MM/yyyy').format(date)),
                      onDeleted: () => _removeComparisonDate(date),
                    ),
                  );
                },
              ),
            ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: _selectedComparisonDates.map((date) {
                  String dateStr = DateFormat('dd/MM/yyyy').format(date);
                  return FutureBuilder<IndicadoresFinanceiros>(
                    future: _comparisonDataFutures[dateStr],
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Card(
                          elevation: 2,
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              children: [
                                Text('Dados para $dateStr', style: const TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                const CircularProgressIndicator(),
                              ],
                            ),
                          ),
                        );
                      } else if (snapshot.hasError) {
                        return Card(
                          elevation: 2,
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          color: Colors.red.shade50,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              children: [
                                Text('Erro ao carregar dados para $dateStr: ${snapshot.error}', style: const TextStyle(color: Colors.red)),
                              ],
                            ),
                          ),
                        );
                      } else if (snapshot.hasData) {
                        final indicadores = snapshot.data!.indicadores;
                        final ipcaData = indicadores['433']?.firstOption(); // Pega o primeiro dado do dia
                        final selicData = indicadores['1178']?.firstOption();
                        final dolarData = indicadores['1']?.firstOption();

                        // Calcula IPCA acumulado nos últimos 12 meses para esta data
                        final ipcaAccumulated = _calculateIpcaAccumulated12Months(indicadores['433'], date);


                        return Card(
                          elevation: 4,
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Dados para ${DateFormat('dd/MM/yyyy').format(date)}',
                                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 16),
                                _buildComparisonIndicatorRow('IPCA', ipcaData?.valor ?? 'N/A'),
                                _buildComparisonIndicatorRow('IPCA (Acum. 12m)', '${ipcaAccumulated.toStringAsFixed(2)}%'),
                                _buildComparisonIndicatorRow('SELIC', selicData?.valor ?? 'N/A'),
                                _buildComparisonIndicatorRow('Dólar', dolarData?.valor ?? 'N/A'),
                              ],
                            ),
                          ),
                        );
                      }
                      return const SizedBox(); // Caso não haja dados
                    },
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonIndicatorRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 16)),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}