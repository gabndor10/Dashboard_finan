# Projeto Prático - Dashboard de Indicadores Financeiros Públicos

## Objetivo do Projeto
Este projeto tem como objetivo a criação de uma aplicação funcional multiplataforma (Web/Desktop/Mobile) que integra **Rust** (coleta de dados), **Go** (orquestração e API) e **Dart/Flutter** (interface gráfica), para resolver o problema real de monitorar e visualizar dados públicos de indicadores financeiros. A solução busca tornar indicadores como IPCA, SELIC e Dólar acessíveis, permitindo visualização em gráficos, tabelas e exportação, com capacidade de filtragem por período.

## Funcionalidades Implementadas

* **Coleta de Dados de Indicadores Financeiros**:
    * Coleta dados de IPCA (código 433), SELIC (código 1178) e Dólar Comercial (código 1) diretamente das APIs públicas do Banco Central do Brasil (SGS).
    * Configurado para coletar dados dos últimos 5 anos para cada indicador, garantindo um histórico robusto para análise.
    * Envio dos dados coletados para o módulo Go via requisições HTTP POST.
* **Orquestração e API Backend**:
    * Módulo Go que atua como um servidor HTTP, recebendo os dados do coletor Rust.
    * Armazenamento temporário dos dados em memória (in-memory store) para demonstração.
    * Exposição de uma API RESTful para o frontend Flutter, permitindo a consulta dos dados.
    * Suporte a filtros de data (`dataInicial`, `dataFinal`) na API GET para períodos específicos, otimizando a entrega de dados.
    * Configuração CORS (Cross-Origin Resource Sharing) para permitir acesso do aplicativo Flutter Web.
* **Interface Gráfica Multiplataforma (Flutter)**:
    * Desenvolvida em Dart com o framework Flutter, garantindo acesso por navegador (Web), desktop e dispositivos móveis.
    * **Tela Dashboard (Inicial)**: Exibe cards consolidados com os valores mais recentes dos indicadores IPCA, SELIC e Dólar, para uma visão "em tempo real" (último dado disponível da coleta diária).
    * **Página de Gráficos**:
        * Permite visualizar a evolução histórica de IPCA, SELIC e Dólar através de gráficos de linha interativos (via `fl_chart`).
        * Filtro de dados por intervalo de datas (seletores de data).
        * Filtros predefinidos de tempo ("1 dia", "Últimos 7 dias", "1 mês", "3 meses", "12 meses", "5 anos") para facilitar a análise.
    * **Página de Tabelas**:
        * Apresenta os dados financeiros em formato tabular, com datas nas linhas e indicadores nas colunas.
        * Filtro de dados por intervalo de datas e filtros predefinidos, similar aos gráficos.
        * Funcionalidade de **Exportar para CSV**, permitindo ao usuário baixar os dados filtrados em formato de planilha.
    * **Funcionalidade de Comparação de Datas** (Em Desenvolvimento / Esqueleto): Um esqueleto para a funcionalidade de comparar indicadores entre até 3 datas específicas.

## Estrutura do Projeto
├── coleta_rust/             # Módulo Rust para coleta de dados do BACEN
│   ├── src/                 # Código fonte Rust (main.rs)
│   └── Cargo.toml           # Configurações e dependências Rust
├── orquestracao_go/         # Módulo Go para orquestração e API
│   ├── main.go              # Código fonte Go
│   └── go.mod               # Módulos e dependências Go
└── interface_flutter/       # Aplicação Flutter para a interface gráfica
├── lib/                 # Código fonte Dart/Flutter
│   ├── main.dart        # Lógica principal e UI das abas
│   ├── indicador.dart   # Modelos de dados (DadoSGS, IndicadoresFinanceiros)
│   └── screens/         # Telas separadas (ex: comparison_screen.dart)
├── pubspec.yaml         # Configurações e dependências Flutter
└── pubspec.lock
## Como Executar o Projeto

Para que a aplicação funcione corretamente, você precisará executar os três módulos em ordem:

### 1. Configurar e Executar o Módulo Go (Backend API)

1.  **Instalação do Go SDK**: Se ainda não tiver, baixe e instale o Go SDK em [go.dev/dl](https://go.dev/dl/).
2.  **Navegue para o diretório Go**: `cd orquestracao_go/`
3.  **Execute o servidor Go**: `go run main.go`
    * Mantenha este terminal aberto. O servidor Go estará escutando na porta `8080`.

### 2. Configurar e Executar o Módulo Rust (Coletor de Dados)

1.  **Instalação do Rust**: Se ainda não tiver, instale o Rust via `rustup` em [rust-lang.org](https://www.rust-lang.org/). No Windows, certifique-se de ter as "Build Tools for Visual Studio".
2.  **Navegue para o diretório Rust**: `cd coleta_rust/`
3.  **Execute o coletor Rust**: `cargo run`
    * Este módulo coletará dados das APIs do BACEN e os enviará para o servidor Go. Observe os logs em ambos os terminais.
    * Recomenda-se executar o Rust pelo menos uma vez após cada reinício do servidor Go, pois o Go armazena dados em memória. Para atualizações diárias, este comando pode ser agendado via `cron` (Linux/macOS) ou Agendador de Tarefas (Windows).

### 3. Configurar e Executar a Aplicação Flutter (Frontend)

1.  **Instalação do Flutter SDK**: Se ainda não tiver, siga as instruções em [flutter.dev/docs/get-started/install](https://flutter.dev/docs/get-started/install). Configure seu ambiente de desenvolvimento (VS Code ou Android Studio).
2.  **Navegue para o diretório Flutter**: `cd interface_flutter/`
3.  **Instale as dependências Dart**: `flutter pub get`
    * Isso baixará as bibliotecas `http`, `fl_chart`, `intl`, `csv`, `file_saver`.
4.  **Execute o aplicativo Flutter**: `flutter run`
    * O aplicativo será iniciado no navegador Chrome por padrão. Se estiver usando um emulador Android, lembre-se de que a URL da API Go no Flutter (`lib/main.dart`) deve ser alterada de `http://localhost:8080` para `http://10.0.2.2:8080`. Se estiver em um dispositivo físico, use o IP real da sua máquina.

## Tecnologias Utilizadas
* **Backend & Coleta**:
    * **Rust**: Linguagem de programação (Coleta de dados).
    * **Go**: Linguagem de programação (Orquestração e API).
* **Frontend**:
    * **Dart**: Linguagem de programação.
    * **Flutter**: Framework UI multiplataforma.
* **APIs Externas**:
    * Banco Central do Brasil (SGS) - `api.bcb.gov.br`
* **Bibliotecas Chave**:
    * Rust: `reqwest`, `serde`, `chrono`, `tokio`.
    * Go: `net/http`, `encoding/json`, `sync`, `time`.
    * Flutter: `http`, `fl_chart`, `intl`, `csv`, `file_saver`.


## Licença
Este projeto é para fins acadêmicos e não possui fins lucrativos.