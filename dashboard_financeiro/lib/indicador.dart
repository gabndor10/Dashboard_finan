// Representa um único dado de série temporal (data e valor).

class DadoSGS {
  final String data;
  final String valor;

  DadoSGS({required this.data, required this.valor});

  // Factory constructor para criar uma instância de DadoSGS a partir de um JSON.
  factory DadoSGS.fromJson(Map<String, dynamic> json) {
    return DadoSGS(
      data: json['data'],
      valor: json['valor'],
    );
  }
}

// Representa o mapa completo de indicadores recebido do Go.
// A chave é o código da série (String) e o valor é uma lista de DadoSGS.
class IndicadoresFinanceiros {
  final Map<String, List<DadoSGS>> indicadores;

  IndicadoresFinanceiros({required this.indicadores});

  // Factory constructor para criar uma instância a partir do JSON da API Go.
  factory IndicadoresFinanceiros.fromJson(Map<String, dynamic> json) {
    Map<String, List<DadoSGS>> tempIndicadores = {};
    json.forEach((key, value) {
      if (value is List) {
        tempIndicadores[key] = value.map((item) => DadoSGS.fromJson(item as Map<String, dynamic>)).toList();
      }
    });
    return IndicadoresFinanceiros(indicadores: tempIndicadores);
  }
}