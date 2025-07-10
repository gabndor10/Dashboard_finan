// lib/main.dart

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:dashboard_financeiro/indicador.dart'; // Seu modelo de dados (verifique o caminho real do seu projeto)
import 'package:fl_chart/fl_chart.dart'; // Importe fl_chart
import 'package:intl/intl.dart'; // Importe intl para formatação de datas
import 'package:csv/csv.dart'; // Importe a biblioteca CSV
import 'package:file_saver/file_saver.dart'; // Importe a biblioteca FileSaver
import 'dart:typed_data'; // Necessário para FileSaver em algumas plataformas
import 'package:dashboard_financeiro/screens/comparison_screen.dart'; // NOVO: Importa a tela de comparação

// Função para buscar os dados da API Go
Future<IndicadoresFinanceiros> fetchIndicadores({
  String? dataInicial,
  String? dataFinal,
}) async {
  String url = 'http://localhost:8080/api/v1/indicadores';
  if (dataInicial != null && dataFinal != null) {
    url += '?dataInicial=$dataInicial&dataFinal=$dataFinal'; // Adiciona os parâmetros de data
  }

  final response = await http.get(Uri.parse(url));

  if (response.statusCode == 200) {
    final Map<String, dynamic> jsonResponse = jsonDecode(response.body);
    return IndicadoresFinanceiros.fromJson(jsonResponse);
  } else {
    throw Exception('Falha ao carregar indicadores: ${response.statusCode}. Corpo: ${response.body}');
  }
}

// Classe principal do seu aplicativo Flutter
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dashboard Financeiro',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const MainDashboardScreen(), // Nova tela principal com navegação por abas
    );
  }
}

// Tela principal com navegação por abas
class MainDashboardScreen extends StatefulWidget {
  const MainDashboardScreen({super.key});

  @override
  State<MainDashboardScreen> createState() => _MainDashboardScreenState();
}

class _MainDashboardScreenState extends State<MainDashboardScreen> {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3, // Número de abas: Dashboard, Gráficos, Tabelas
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Dashboard Financeiro'),
          centerTitle: true,
          bottom: const TabBar( // Abas na parte inferior do AppBar
            tabs: [
              Tab(icon: Icon(Icons.dashboard), text: 'Dashboard'),
              Tab(icon: Icon(Icons.bar_chart), text: 'Gráficos'),
              Tab(icon: Icon(Icons.table_chart), text: 'Tabelas'),
            ],
          ),
        ),
        body: const TabBarView( // Conteúdo de cada aba
          children: [
            DashboardTabContent(), // Tela inicial com cards de "tempo real" e comparar
            ChartsTabContent(),    // Tela para gráficos
            TablesTabContent(),    // Tela para tabelas
          ],
        ),
      ),
    );
  }
}

// Esqueleto para a Tab de Dashboard (Tela Inicial)
class DashboardTabContent extends StatefulWidget {
  const DashboardTabContent({super.key});

  @override
  State<DashboardTabContent> createState() => _DashboardTabContentState();
}

class _DashboardTabContentState extends State<DashboardTabContent> {
  late Future<IndicadoresFinanceiros> futureIndicadores;

  @override
  void initState() {
    super.initState();
    // Busca os dados mais recentes para a tela inicial (sem filtro de data para pegar o último)
    futureIndicadores = fetchIndicadores();
  }

  // NOVO: Função auxiliar para cada linha de indicador dentro do único card
  Widget _buildIndicatorRow(String title, String value, String date) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Text(
                'Data: $date',
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
          ),
          Text(
            'Valor: $value',
            style: const TextStyle(fontSize: 18, color: Colors.blue, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<IndicadoresFinanceiros>(
      future: futureIndicadores,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(
            child: Text(
              'Erro ao carregar dados: ${snapshot.error}',
              style: const TextStyle(color: Colors.red, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          );
        } else if (snapshot.hasData) {
          final indicadores = snapshot.data!.indicadores;

          // Extrai o último dado para IPCA, SELIC e Dólar, se existirem
          final ipcaData = indicadores['433']?.lastOption();
          final selicData = indicadores['1178']?.lastOption();
          final dolarData = indicadores['1']?.lastOption();

          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              // Card de Indicadores Financeiros em Tempo Real
              const Text(
                'Indicadores Atuais',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              // NOVO: Um único Card para todos os indicadores atuais
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // IPCA
                      _buildIndicatorRow(
                        'IPCA (Inflação)',
                        ipcaData != null ? ipcaData.valor : 'N/A',
                        ipcaData != null ? ipcaData.data : 'N/A',
                      ),
                      const Divider(), // Linha divisória
                      // SELIC
                      _buildIndicatorRow(
                        'SELIC (Taxa Básica de Juros)',
                        selicData != null ? selicData.valor : 'N/A',
                        selicData != null ? selicData.data : 'N/A',
                      ),
                      const Divider(),
                      // Dólar
                      _buildIndicatorRow(
                        'Dólar Comercial',
                        dolarData != null ? dolarData.valor : 'N/A',
                        dolarData != null ? dolarData.data : 'N/A',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Botão "Comparar"
              ElevatedButton(
                onPressed: () {
                  Navigator.push( // Navega para a tela de comparação
                    context,
                    MaterialPageRoute(builder: (context) => const ComparisonScreen()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  textStyle: const TextStyle(fontSize: 18),
                ),
                child: const Text('Comparar com Datas Específicas'),
              ),
            ],
          );
        }
        return const Center(child: Text('Nenhum dado disponível.'));
      },
    );
  }
}

// Classe para a Tab de Gráficos
class ChartsTabContent extends StatefulWidget {
  const ChartsTabContent({super.key});

  @override
  State<ChartsTabContent> createState() => _ChartsTabContentState();
}

class _ChartsTabContentState extends State<ChartsTabContent> {
  // Variáveis de estado para as datas selecionadas
  DateTime _selectedStartDate = DateTime.now().subtract(const Duration(days: 30)); // Padrão: 30 dias atrás
  DateTime _selectedEndDate = DateTime.now(); // Padrão: Hoje

  // Future para armazenar os dados dos gráficos
  late Future<IndicadoresFinanceiros> _futureFilteredIndicators;

  @override
  void initState() {
    super.initState();
    // Formata as datas iniciais para a API Go no formato "DD/MM/AAAA"
    _futureFilteredIndicators = _fetchDataWithDateFilter(
      DateFormat('dd/MM/yyyy').format(_selectedStartDate),
      DateFormat('dd/MM/yyyy').format(_selectedEndDate),
    );
  }

  // Função auxiliar para buscar dados com base nas datas selecionadas
  Future<IndicadoresFinanceiros> _fetchDataWithDateFilter(
      String startDate, String endDate) async {
    return await fetchIndicadores(dataInicial: startDate, dataFinal: endDate);
  }

  // Função para abrir o seletor de data
  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate ? _selectedStartDate : _selectedEndDate,
      firstDate: DateTime(2000), // Data mínima
      lastDate: DateTime.now(), // Data máxima
    );
    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _selectedStartDate = picked;
        } else {
          _selectedEndDate = picked;
        }
        // Após selecionar a data, refaça a busca dos dados
        _futureFilteredIndicators = _fetchDataWithDateFilter(
          DateFormat('dd/MM/yyyy').format(_selectedStartDate),
          DateFormat('dd/MM/yyyy').format(_selectedEndDate),
        );
      });
    }
  }

  // Função para aplicar filtros predefinidos
  void _applyPresetFilter(String filter) {
    setState(() {
      _selectedEndDate = DateTime.now(); // Data final sempre "hoje"
      switch (filter) {
        case '1 dia':
          _selectedStartDate = _selectedEndDate.subtract(const Duration(days: 1));
          break;
        case 'Últimos 7 dias':
          _selectedStartDate = _selectedEndDate.subtract(const Duration(days: 7));
          break;
        case '1 mês':
          _selectedStartDate = _selectedEndDate.subtract(const Duration(days: 30)); // Aproximado
          break;
        case '3 meses':
          _selectedStartDate = _selectedEndDate.subtract(const Duration(days: 90)); // Aproximado
          break;
        case '12 meses':
          _selectedStartDate = _selectedEndDate.subtract(const Duration(days: 365)); // Aproximado
          break;
        case '5 anos':
          _selectedStartDate = _selectedEndDate.subtract(const Duration(days: 365 * 5)); // Aproximado
          break;
        default: // Padrão 30 dias se algo der errado
          _selectedStartDate = _selectedEndDate.subtract(const Duration(days: 30));
          break;
      }
      _futureFilteredIndicators = _fetchDataWithDateFilter(
        DateFormat('dd/MM/yyyy').format(_selectedStartDate),
        DateFormat('dd/MM/yyyy').format(_selectedEndDate),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Seletores de Data
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _selectDate(context, true),
                      child: Text('Data Inicial: ${DateFormat('dd/MM/yyyy').format(_selectedStartDate)}'),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _selectDate(context, false),
                      child: Text('Data Final: ${DateFormat('dd/MM/yyyy').format(_selectedEndDate)}'),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10),
              // Filtros Predefinidos
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildPresetButton('1 dia'),
                    _buildPresetButton('Últimos 7 dias'),
                    _buildPresetButton('1 mês'),
                    _buildPresetButton('3 meses'),
                    _buildPresetButton('12 meses'),
                    _buildPresetButton('5 anos'),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<IndicadoresFinanceiros>(
            future: _futureFilteredIndicators,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              } else if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Erro ao carregar dados: ${snapshot.error}',
                    style: const TextStyle(color: Colors.red, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                );
              } else if (snapshot.hasData && snapshot.data!.indicadores.isNotEmpty) {
                final indicadoresData = snapshot.data!.indicadores;

                return SingleChildScrollView(
                  child: Column(
                    children: [
                      // Espaço para o Gráfico do IPCA
                      _buildChartCard(
                        title: 'Gráfico IPCA',
                        indicatorCode: '433',
                        data: indicadoresData['433'],
                      ),
                      SizedBox(height: 16),
                      // Espaço para o Gráfico da SELIC
                      _buildChartCard(
                        title: 'Gráfico SELIC',
                        indicatorCode: '1178',
                        data: indicadoresData['1178'],
                      ),
                      SizedBox(height: 16),
                      // Espaço para o Gráfico do Dólar
                      _buildChartCard(
                        title: 'Gráfico Dólar',
                        indicatorCode: '1',
                        data: indicadoresData['1'],
                      ),
                    ],
                  ),
                );
              }
              return const Center(child: Text('Nenhum dado disponível para este período.'));
            },
          ),
        ),
      ],
    );
  }

  // Widget auxiliar para construir os botões de filtro predefinidos
  Widget _buildPresetButton(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: ElevatedButton(
        onPressed: () => _applyPresetFilter(text),
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(0, 36),
          padding: const EdgeInsets.symmetric(horizontal: 10),
        ),
        child: Text(text),
      ),
    );
  }

  // _buildChartCard COMPLETO E CORRIGIDO
  Widget _buildChartCard({
    required String title,
    required String indicatorCode,
    List<DadoSGS>? data,
  }) {
    if (data == null || data.isEmpty) {
      return Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              const Text('Nenhum dado para exibir neste período.'),
            ],
          ),
        ),
      );
    }

    // Preparação dos dados para o fl_chart
    List<FlSpot> spots = [];
    for (int i = 0; i < data.length; i++) {
      final dado = data[i];
      double value = double.tryParse(dado.valor.replaceAll(',', '.')) ?? 0.0;
      spots.add(FlSpot(i.toDouble(), value));
    }

    double minYValue = spots.map((e) => e.y).reduce((a, b) => a < b ? a : b);
    double maxYValue = spots.map((e) => e.y).reduce((a, b) => a > b ? a : b);

    if (spots.length > 1) {
      minYValue = minYValue * 0.9;
      maxYValue = maxYValue * 1.1;
    } else {
      minYValue = (minYValue - 1.0).clamp(0.0, double.infinity);
      maxYValue = maxYValue + 1.0;
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            SizedBox(
              height: 200, // Altura do gráfico
              child: LineChart(
                LineChartData(
                  minX: 0,
                  maxX: (data.length - 1).toDouble(),
                  minY: minYValue,
                  maxY: maxYValue,
                  titlesData: FlTitlesData(
                    show: true,
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) => SideTitleWidget(
                          axisSide: meta.axisSide,
                          child: Text(value.toStringAsFixed(2)),
                        ),
                        reservedSize: 40,
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          // Se o número de pontos for pequeno (até 12, por exemplo, para meses),
                          // ou se for o primeiro/último ponto, ou a cada N pontos.
                          bool showEveryPoint = data.length <= 12;
                          int interval = (data.length ~/ 5).clamp(1, data.length);

                          if (showEveryPoint ||
                              value.toInt() == 0 ||
                              value.toInt() == data.length - 1 ||
                              (value.toInt() % interval == 0 && data.length > 12)) {
                            if (value.toInt() >= 0 && value.toInt() < data.length) {
                              return SideTitleWidget(
                                axisSide: meta.axisSide,
                                child: Text(data[value.toInt()].data), // Exibindo a data completa com ano
                              );
                            }
                          }
                          return const SizedBox();
                        },
                        reservedSize: 30,
                      ),
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawHorizontalLine: true,
                    drawVerticalLine: true,
                    getDrawingHorizontalLine: (value) => const FlLine(color: Colors.grey, strokeWidth: 0.5),
                    getDrawingVerticalLine: (value) => const FlLine(color: Colors.grey, strokeWidth: 0.5),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border.all(color: const Color(0xff37434d), width: 1),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: Colors.blueAccent,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(show: false),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Os dados são do período: ${data.first.data} até ${data.last.data}',
              style: const TextStyle(fontSize: 14, color: Colors.black87),
            ),
          ],
        ),
      ),
    );
  }
}

// Classe para a Tab de Tabelas
class TablesTabContent extends StatefulWidget {
  const TablesTabContent({super.key});

  @override
  State<TablesTabContent> createState() => _TablesTabContentState();
}

class _TablesTabContentState extends State<TablesTabContent> {
  DateTime _selectedStartDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _selectedEndDate = DateTime.now();

  late Future<IndicadoresFinanceiros> _futureFilteredIndicators;

  @override
  void initState() {
    super.initState();
    _futureFilteredIndicators = _fetchDataWithDateFilter(
      DateFormat('dd/MM/yyyy').format(_selectedStartDate),
      DateFormat('dd/MM/yyyy').format(_selectedEndDate),
    );
  }

  Future<IndicadoresFinanceiros> _fetchDataWithDateFilter(
      String startDate, String endDate) async {
    return await fetchIndicadores(dataInicial: startDate, dataFinal: endDate);
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate ? _selectedStartDate : _selectedEndDate,
      firstDate: DateTime(2000), // Data mínima
      lastDate: DateTime.now(), // Data máxima
    );
    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _selectedStartDate = picked;
        } else {
          _selectedEndDate = picked;
        }
        _futureFilteredIndicators = _fetchDataWithDateFilter(
          DateFormat('dd/MM/yyyy').format(_selectedStartDate),
          DateFormat('dd/MM/yyyy').format(_selectedEndDate),
        );
      });
    }
  }

  void _applyPresetFilter(String filter) {
    setState(() {
      _selectedEndDate = DateTime.now();
      switch (filter) {
        case '1 dia':
          _selectedStartDate = _selectedEndDate.subtract(const Duration(days: 1));
          break;
        case 'Últimos 7 dias':
          _selectedStartDate = _selectedEndDate.subtract(const Duration(days: 7));
          break;
        case '1 mês':
          _selectedStartDate = _selectedEndDate.subtract(const Duration(days: 30));
          break;
        case '3 meses':
          _selectedStartDate = _selectedEndDate.subtract(const Duration(days: 90));
          break;
        case '12 meses':
          _selectedStartDate = _selectedEndDate.subtract(const Duration(days: 365));
          break;
        case '5 anos':
          _selectedStartDate = _selectedEndDate.subtract(const Duration(days: 365 * 5));
          break;
        default:
          _selectedStartDate = _selectedEndDate.subtract(const Duration(days: 30));
          break;
      }
      _futureFilteredIndicators = _fetchDataWithDateFilter(
        DateFormat('dd/MM/yyyy').format(_selectedStartDate),
        DateFormat('dd/MM/yyyy').format(_selectedEndDate),
      );
    });
  }

  Widget _buildPresetButton(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: ElevatedButton(
        onPressed: () => _applyPresetFilter(text),
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(0, 36),
          padding: const EdgeInsets.symmetric(horizontal: 10),
        ),
        child: Text(text),
      ),
    );
  }

  List<Map<String, String>> _transformDataForTable(IndicadoresFinanceiros indicadores) {
    Set<String> uniqueDates = {};
    indicadores.indicadores.forEach((code, dataList) {
      for (var dado in dataList) {
        uniqueDates.add(dado.data);
      }
    });

    List<DateTime> sortedDates = uniqueDates.map((dateStr) => DateFormat('dd/MM/yyyy').parse(dateStr)).toList();
    sortedDates.sort();

    List<Map<String, String>> tableRows = [];

    Map<String, Map<String, String>> dataByDateAndCode = {};
    indicadores.indicadores.forEach((code, dataList) {
      for (var dado in dataList) {
        if (!dataByDateAndCode.containsKey(dado.data)) {
          dataByDateAndCode[dado.data] = {};
        }
        dataByDateAndCode[dado.data]![code] = dado.valor;
      }
    });

    for (var date in sortedDates) {
      String dateStr = DateFormat('dd/MM/yyyy').format(date);
      Map<String, String> row = {'Data': dateStr};

      row['IPCA'] = dataByDateAndCode[dateStr]?['433'] ?? 'N/A';
      row['SELIC'] = dataByDateAndCode[dateStr]?['1178'] ?? 'N/A';
      row['Dólar'] = dataByDateAndCode[dateStr]?['1'] ?? 'N/A';
      tableRows.add(row);
    }

    return tableRows;
  }

  // IMPLEMENTAÇÃO REAL DA EXPORTAÇÃO PARA CSV
  void _exportToCsv(List<Map<String, String>> data) async {
    if (data.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nenhum dado para exportar para CSV!')),
      );
      return;
    }

    // 1. Definir os cabeçalhos da tabela
    List<String> headers = ['Data', 'IPCA', 'SELIC', 'Dólar'];

    // 2. Preparar os dados no formato List<List<dynamic>> para a biblioteca CSV
    List<List<dynamic>> csvData = [];
    csvData.add(headers);

    for (var rowMap in data) {
      List<dynamic> row = [];
      for (var header in headers) {
        row.add(rowMap[header] ?? '');
      }
      csvData.add(row);
    }

    // 3. Converter a lista de listas para uma string CSV
    String csvString = const ListToCsvConverter().convert(csvData);

    // 4. Salvar o arquivo usando file_saver
    try {
      final String fileName = 'indicadores_financeiros_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv';
      final Uint8List bytes = Uint8List.fromList(utf8.encode(csvString));

      await FileSaver.instance.saveFile(
        name: fileName,
        bytes: bytes,
        ext: 'csv',
        mimeType: MimeType.csv,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Arquivo "$fileName" exportado com sucesso!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao exportar CSV: $e')),
      );
      print('Erro ao exportar CSV: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Seletores de Data e Filtros Predefinidos (igual ao ChartsTabContent)
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _selectDate(context, true),
                      child: Text('Data Inicial: ${DateFormat('dd/MM/yyyy').format(_selectedStartDate)}'),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _selectDate(context, false),
                      child: Text('Data Final: ${DateFormat('dd/MM/yyyy').format(_selectedEndDate)}'),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildPresetButton('1 dia'),
                    _buildPresetButton('Últimos 7 dias'),
                    _buildPresetButton('1 mês'),
                    _buildPresetButton('3 meses'),
                    _buildPresetButton('12 meses'),
                    _buildPresetButton('5 anos'),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Botão para Exportar CSV
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          child: ElevatedButton(
            onPressed: () async {
              final snapshot = await _futureFilteredIndicators;
              if (snapshot.indicadores.isNotEmpty) {
                final tableData = _transformDataForTable(snapshot);
                _exportToCsv(tableData);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Nenhum dado para exportar!')),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(40),
              textStyle: const TextStyle(fontSize: 16),
            ),
            child: const Text('Exportar para CSV'),
          ),
        ),
        // Exibição da Tabela
        Expanded(
          child: FutureBuilder<IndicadoresFinanceiros>(
            future: _futureFilteredIndicators,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              } else if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Erro ao carregar dados: ${snapshot.error}',
                    style: const TextStyle(color: Colors.red, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                );
              } else if (snapshot.hasData && snapshot.data!.indicadores.isNotEmpty) {
                final indicadoresData = snapshot.data!;
                final tableRows = _transformDataForTable(indicadoresData);

                if (tableRows.isEmpty) {
                    return const Center(child: Text('Nenhum dado disponível para este período.'));
                }

                return SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Data', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('IPCA', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('SELIC', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Dólar', style: TextStyle(fontWeight: FontWeight.bold))),
                      ],
                      rows: tableRows.map((row) {
                        return DataRow(cells: [
                          DataCell(Text(row['Data'] ?? 'N/A')),
                          DataCell(Text(row['IPCA'] ?? 'N/A')),
                          DataCell(Text(row['SELIC'] ?? 'N/A')),
                          DataCell(Text(row['Dólar'] ?? 'N/A')),
                        ]);
                      }).toList(),
                    ),
                  ),
                );
              }
              return const Center(child: Text('Nenhum dado disponível para este período.'));
            },
          ),
        ),
      ],
    );
  }
}

// Extensão para obter o último e o primeiro elemento de forma segura
extension ListExtension<T> on List<T> {
  T? lastOption() {
    if (isEmpty) {
      return null;
    }
    return last;
  }

  // Adicionado para a funcionalidade de comparação
  T? firstOption() {
    if (isEmpty) {
      return null;
    }
    return first;
  }
}

// Ponto de entrada do aplicativo
void main() {
  runApp(const MyApp());
}