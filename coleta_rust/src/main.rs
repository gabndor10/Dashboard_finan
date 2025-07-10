// src/main.rs

use reqwest;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::error::Error;
use chrono::{NaiveDate, Utc, Duration}; // Importe os tipos necessários de chrono

// Estrutura que mapeia a resposta JSON da API do SGS para um dado.
#[derive(Debug, Deserialize, Serialize)]
struct DadoSGS {
    #[serde(rename = "data")]
    data: String,
    #[serde(rename = "valor")]
    valor: String,
}

/// Função assíncrona para coletar dados de uma série específica do SGS.
async fn coletar_dados_sgs(
    codigo_serie: &str,
    data_inicial: &str, // Este parâmetro será "DD/MM/AAAA"
    data_final: &str,   // Este parâmetro será "DD/MM/AAAA"
) -> Result<Vec<DadoSGS>, Box<dyn Error>> {
    let url = format!(
        "https://api.bcb.gov.br/dados/serie/bcdata.sgs.{}/dados?formato=json&dataInicial={}&dataFinal={}",
        codigo_serie, data_inicial, data_final
    );

    println!("Fazendo requisição para: {}", url);

    let response = reqwest::get(&url).await?.error_for_status()?;

    let body = response.text().await?; // Pega o corpo da resposta como texto
    println!("Corpo da resposta para {}: {}", codigo_serie, body); // Imprime o corpo

    let dados: Vec<DadoSGS> = serde_json::from_str(&body)?; // Tenta desserializar a string diretamente.

    Ok(dados)
}

/// Função assíncrona para enviar dados coletados para o servidor Go.
async fn enviar_dados_para_go(
    url_go_api: &str,
    dados: HashMap<String, Vec<DadoSGS>>,
) -> Result<(), Box<dyn Error>> {
    println!("Enviando dados para o servidor Go em: {}", url_go_api);

    let client = reqwest::Client::new();

    let response = client.post(url_go_api)
        .json(&dados)
        .send()
        .await?
        .error_for_status()?;

    let status = response.status();
    let corpo_resposta = response.text().await?;

    println!("Resposta do servidor Go - Status: {}", status);
    println!("Resposta do servidor Go - Corpo: {}", corpo_resposta);

    if status.is_success() {
        Ok(())
    } else {
        Err(format!("Erro ao enviar dados para Go. Status: {}, Corpo: {}", status, corpo_resposta).into())
    }
}

/// Função principal do programa.
#[tokio::main]
async fn main() -> Result<(), Box<dyn Error>> {
    // Calcular a data atual e as datas de início dinamicamente
    let today = Utc::now().date_naive(); // Obtém a data atual (sem fuso horário)
    let yesterday = today - Duration::days(1); // Ontem
    let thirty_days_ago = today - Duration::days(30); // 30 dias atrás
    let ninety_days_ago = today - Duration::days(90); // 90 dias atrás
    let one_year_ago = today - Duration::days(365); // 1 ano atrás
    let five_years_ago = today - Duration::days(365 * 5); // 5 anos atrás


    // Formato de data para a API do BACEN "DD/MM/AAAA"
    const DATE_FORMAT_BCB: &str = "%d/%m/%Y";

    // URL do endpoint Go para receber os dados.
    let go_api_url = "http://localhost:8080/dados/sgs";

    let mut todos_dados_coletados: HashMap<String, Vec<DadoSGS>> = HashMap::new();

    // --- Coleta de dados do IPCA (Código: 433) ---
    // IPCA é mensal. Coletar dos últimos 5 anos.
    let data_inicio_ipca = five_years_ago.format(DATE_FORMAT_BCB).to_string(); // ALTERADO AQUI
    let data_fim_ipca = today.format(DATE_FORMAT_BCB).to_string(); // Data atual
    let codigo_ipca = "433";
    println!("\n--- Coletando dados do IPCA (Código: {}) ---", codigo_ipca);
    match coletar_dados_sgs(codigo_ipca, &data_inicio_ipca, &data_fim_ipca).await {
        Ok(dados) => {
            if dados.is_empty() {
                println!("Nenhum dado encontrado para IPCA no período {} - {}.", data_inicio_ipca, data_fim_ipca);
            } else {
                println!("IPCA - Dados coletados: {} itens.", dados.len());
                if let Some(primeiro) = dados.first() {
                    println!("  Primeiro dado: Data: {}, Valor: {}", primeiro.data, primeiro.valor);
                }
                if let Some(ultimo) = dados.last() {
                    println!("  Último dado: Data: {}, Valor: {}", ultimo.data, ultimo.valor);
                }
                todos_dados_coletados.insert(codigo_ipca.to_string(), dados);
            }
        }
        Err(e) => eprintln!("Erro ao coletar IPCA: {}", e),
    }

    // --- Coleta de dados da SELIC (Código: 1178) ---
    // SELIC é diária. Coletar dos últimos 5 anos.
    let data_inicio_selic = five_years_ago.format(DATE_FORMAT_BCB).to_string(); // ALTERADO AQUI
    let data_fim_selic = today.format(DATE_FORMAT_BCB).to_string(); // Data atual
    let codigo_selic = "1178";
    println!("\n--- Coletando dados da SELIC (Código: {}) ---", codigo_selic);
    match coletar_dados_sgs(codigo_selic, &data_inicio_selic, &data_fim_selic).await {
        Ok(dados) => {
            if dados.is_empty() {
                println!("Nenhum dado encontrado para SELIC no período {} - {}.", data_inicio_selic, data_fim_selic);
            } else {
                println!("SELIC - Dados coletados: {} itens.", dados.len());
                if let Some(primeiro) = dados.first() {
                    println!("  Primeiro dado: Data: {}, Valor: {}", primeiro.data, primeiro.valor);
                }
                if let Some(ultimo) = dados.last() {
                    println!("  Último dado: Data: {}, Valor: {}", ultimo.data, ultimo.valor);
                }
                todos_dados_coletados.insert(codigo_selic.to_string(), dados);
            }
        }
        Err(e) => eprintln!("Erro ao coletar SELIC: {}", e),
    }

    // --- Coleta de dados do Dólar (Código: 1) ---
    // Dólar é diário. Coletar dos últimos 5 anos.
    let data_inicio_dolar = five_years_ago.format(DATE_FORMAT_BCB).to_string(); // ALTERADO AQUI
    let data_fim_dolar = today.format(DATE_FORMAT_BCB).to_string(); // Data atual
    let codigo_dolar = "1";
    println!("\n--- Coletando dados do Dólar (Código: {}) ---", codigo_dolar);
    match coletar_dados_sgs(codigo_dolar, &data_inicio_dolar, &data_fim_dolar).await {
        Ok(dados) => {
            if dados.is_empty() {
                println!("Nenhum dado encontrado para Dólar no período {} - {}.", data_inicio_dolar, data_fim_dolar);
            } else {
                println!("Dólar - Dados coletados: {} itens.", dados.len());
                if let Some(primeiro) = dados.first() {
                    println!("  Primeiro dado: Data: {}, Valor: {}", primeiro.data, primeiro.valor);
                }
                if let Some(ultimo) = dados.last() {
                    println!("  Último dado: Data: {}, Valor: {}", ultimo.data, ultimo.valor);
                }
                todos_dados_coletados.insert(codigo_dolar.to_string(), dados);
            }
        }
        Err(e) => eprintln!("Erro ao coletar Dólar: {}", e),
    }

    // --- Envio de todos os dados coletados para o servidor Go ---
    if !todos_dados_coletados.is_empty() {
        println!("\n--- Enviando todos os dados coletados para o servidor Go ---");
        match enviar_dados_para_go(go_api_url, todos_dados_coletados).await {
            Ok(_) => println!("Dados enviados com sucesso para o Go!"),
            Err(e) => eprintln!("Falha ao enviar dados para o Go: {}", e),
        }
    } else {
        println!("\nNenhum dado para enviar para o Go.");
    }

    Ok(())
}