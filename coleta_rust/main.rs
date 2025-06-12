// src/main.rs

use reqwest; // Para fazer requisições HTTP
use serde::{Deserialize, Serialize}; // Para desserializar E serializar JSON (adicionado Serialize)
use std::collections::HashMap; // Para criar um mapa de códigos de série para lista de dados
use std::error::Error; // Para tratamento de erros

// Estrutura que mapeia a resposta JSON da API do SGS para um dado.
// 'Deserialize' e 'Serialize' são derivados para permitir a conversão de/para JSON.
#[derive(Debug, Deserialize, Serialize)] // Adicionado Serialize aqui
struct DadoSGS {
    #[serde(rename = "data")]
    data: String,
    #[serde(rename = "valor")]
    valor: String,
}

/// Função assíncrona para coletar dados de uma série específica do SGS.
async fn coletar_dados_sgs(
    codigo_serie: &str,
    data_inicial: &str,
    data_final: &str,
) -> Result<Vec<DadoSGS>, Box<dyn Error>> {
    let url = format!(
        "https://api.bcb.gov.br/dados/olinda/sgs/series/{}/dados?formato=json&dataInicial={}&dataFinal={}",
        codigo_serie, data_inicial, data_final
    );

    println!("Fazendo requisição para: {}", url);

    let response = reqwest::get(&url).await?.error_for_status()?;

    let dados: Vec<DadoSGS> = response.json().await?;

    Ok(dados)
}

/// Função assíncrona para enviar dados coletados para o servidor Go.
async fn enviar_dados_para_go(
    url_go_api: &str,
    dados: HashMap<String, Vec<DadoSGS>>,
) -> Result<(), Box<dyn Error>> {
    println!("Enviando dados para o servidor Go em: {}", url_go_api);

    // Cria um cliente HTTP para enviar a requisição.
    let client = reqwest::Client::new();

    // Envia a requisição POST com os dados JSON no corpo.
    let response = client.post(url_go_api)
        .json(&dados) // Serializa o HashMap para JSON e o define como corpo da requisição.
        .send()
        .await?
        .error_for_status()?; // Verifica se a resposta do Go é de sucesso (2xx).

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
    // Definindo as datas para a consulta.
    let data_inicio = "01-01-2024";
    let data_fim = "31-05-2025"; // Data atualizada para o contexto de Junho de 2025

    // URL do endpoint Go para receber os dados.
    let go_api_url = "http://localhost:8080/dados/sgs"; // Onde o servidor Go estará escutando.

    // --- Coleta de dados do IPCA (Inflação) ---
    let codigo_ipca = "433";
    let mut todos_dados_coletados: HashMap<String, Vec<DadoSGS>> = HashMap::new();

    println!("\n--- Coletando dados do IPCA (Código: {}) ---", codigo_ipca);
    match coletar_dados_sgs(codigo_ipca, data_inicio, data_fim).await {
        Ok(dados) => {
            if dados.is_empty() {
                println!("Nenhum dado encontrado para IPCA no período.");
            } else {
                println!("IPCA - Dados coletados: {} itens.", dados.len());
                // Armazena os dados coletados no HashMap.
                todos_dados_coletados.insert(codigo_ipca.to_string(), dados);
            }
        }
        Err(e) => eprintln!("Erro ao coletar IPCA: {}", e),
    }

    // --- Coleta de dados da SELIC ---
    let codigo_selic = "439";
    println!("\n--- Coletando dados da SELIC (Código: {}) ---", codigo_selic);
    match coletar_dados_sgs(codigo_selic, data_inicio, data_fim).await {
        Ok(dados) => {
            if dados.is_empty() {
                println!("Nenhum dado encontrado para SELIC no período.");
            } else {
                println!("SELIC - Dados coletados: {} itens.", dados.len());
                todos_dados_coletados.insert(codigo_selic.to_string(), dados);
            }
        }
        Err(e) => eprintln!("Erro ao coletar SELIC: {}", e),
    }

    // --- Coleta de dados do Câmbio (Dólar) ---
    let codigo_dolar = "1";
    println!("\n--- Coletando dados do Dólar (Código: {}) ---", codigo_dolar);
    match coletar_dados_sgs(codigo_dolar, data_inicio, data_fim).await {
        Ok(dados) => {
            if dados.is_empty() {
                println!("Nenhum dado encontrado para Dólar no período.");
            } else {
                println!("Dólar - Dados coletados: {} itens.", dados.len());
                todos_dados_coletados.insert(codigo_dolar.to_string(), dados);
            }
        }
        Err(e) => eprintln!("Erro ao coletar Dólar: {}", e),
    }

    // --- Envio de todos os dados coletados para o Go ---
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