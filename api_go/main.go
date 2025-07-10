// main.go
package main

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"sync"
	"time" // Re-importado para manipulação de datas
)

// DadoSGS representa a estrutura de um dado de série temporal.
type DadoSGS struct {
	Data  string `json:"data"`
	Valor string `json:"valor"`
}

// GlobalDataStore simula um armazenamento em memória.
type GlobalDataStore struct {
	mu    sync.RWMutex
	dados map[string][]DadoSGS
}

var nossoDataStore = GlobalDataStore{
	dados: make(map[string][]DadoSGS),
}

// handleReceiveData permanece o mesmo
func handleReceiveData(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Método não permitido. Use POST.", http.StatusMethodNotAllowed)
		log.Printf("Erro: Tentativa de acesso com método não permitido: %s", r.Method)
		return
	}

	var dadosRecebidos map[string][]DadoSGS
	err := json.NewDecoder(r.Body).Decode(&dadosRecebidos)
	if err != nil {
		http.Error(w, "Erro ao decodificar JSON: "+err.Error(), http.StatusBadRequest)
		log.Printf("Erro ao decodificar JSON da requisição: %v", err)
		return
	}

	nossoDataStore.mu.Lock()
	defer nossoDataStore.mu.Unlock()

	for codigo, listaDados := range dadosRecebidos {
		// Para simplificar, estamos substituindo a lista inteira.
		// Em um cenário real, você faria um merge ou inseriria no DB, tratando duplicatas.
		nossoDataStore.dados[codigo] = listaDados
		log.Printf("Dados para série %s atualizados. Total de %d itens.", codigo, len(listaDados))
	}

	w.WriteHeader(http.StatusOK)
	fmt.Fprintf(w, "Dados recebidos e processados com sucesso!")
	log.Println("Dados recebidos e processados com sucesso do Rust.")
}

// handleGetIndicators agora aceita e filtra por data.
func handleGetIndicators(w http.ResponseWriter, r *http.Request) {
	// --- ADICIONE ESTES CABEÇALHOS CORS NO INÍCIO DO HANDLER ---
	// Permite requisições de qualquer origem. Em produção, você restringiria isso a origens específicas.
	w.Header().Set("Access-Control-Allow-Origin", "*")
	// Permite os métodos HTTP que seu cliente Flutter usará (GET, POST, etc.)
	w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
	// Permite cabeçalhos específicos
	w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Access-Control-Allow-Headers, Authorization, X-Requested-With")

	// Lida com requisições OPTIONS (pré-voo CORS)
	if r.Method == http.MethodOptions {
		w.WriteHeader(http.StatusOK)
		return
	}
	// -------------------------------------------------------------

	if r.Method != http.MethodGet {
		http.Error(w, "Método não permitido. Use GET.", http.StatusMethodNotAllowed)
		log.Printf("Erro: Tentativa de acesso com método não permitido: %s", r.Method)
		return
	}

	query := r.URL.Query()
	dataInicialStr := query.Get("dataInicial")
	dataFinalStr := query.Get("dataFinal")

	var dataInicial time.Time
	var dataFinal time.Time
	var err error

	const dateFormat = "02/01/2006"

	if dataInicialStr != "" {
		dataInicial, err = time.Parse(dateFormat, dataInicialStr)
		if err != nil {
			http.Error(w, "Formato de dataInicial inválido. Use DD/MM/AAAA.", http.StatusBadRequest)
			log.Printf("Erro ao parsear dataInicial '%s': %v", dataInicialStr, err)
			return
		}
	} else {
		dataInicial = time.Time{}
	}

	if dataFinalStr != "" {
		dataFinal, err = time.Parse(dateFormat, dataFinalStr)
		if err != nil {
			http.Error(w, "Formato de dataFinal inválido. Use DD/MM/AAAA.", http.StatusBadRequest)
			log.Printf("Erro ao parsear dataFinal '%s': %v", dataFinalStr, err)
			return
		}
		dataFinal = dataFinal.Add(23*time.Hour + 59*time.Minute + 59*time.Second)
	} else {
		dataFinal = time.Now().Add(365 * 24 * time.Hour)
	}

	nossoDataStore.mu.RLock()
	defer nossoDataStore.mu.RUnlock()

	if len(nossoDataStore.dados) == 0 {
		http.Error(w, "Nenhum dado financeiro disponível no momento.", http.StatusNotFound)
		log.Println("Erro: Nenhuns dados financeiros disponíveis para o Dart.")
		return
	}

	filteredData := make(map[string][]DadoSGS)

	for codigo, dados := range nossoDataStore.dados {
		var serieFiltrada []DadoSGS
		for _, dado := range dados {
			dadoTime, err := time.Parse(dateFormat, dado.Data)
			if err != nil {
				log.Printf("Aviso: Falha ao parsear data do dado '%s' para série %s: %v. Dado ignorado.", dado.Data, codigo, err)
				continue
			}

			if (dadoTime.Equal(dataInicial) || dadoTime.After(dataInicial)) &&
				(dadoTime.Equal(dataFinal) || dadoTime.Before(dataFinal)) {
				serieFiltrada = append(serieFiltrada, dado)
			}
		}
		if len(serieFiltrada) > 0 {
			filteredData[codigo] = serieFiltrada
		}
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)

	err = json.NewEncoder(w).Encode(filteredData)
	if err != nil {
		log.Printf("Erro ao codificar JSON para resposta: %v", err)
	}
	log.Println("Dados financeiros filtrados e enviados para o Dart.")
}

func main() {
	http.HandleFunc("/dados/sgs", handleReceiveData)
	http.HandleFunc("/api/v1/indicadores", handleGetIndicators)

	port := ":8080"
	log.Printf("Servidor Go iniciado na porta %s. Aguardando requisições...", port)
	err := http.ListenAndServe(port, nil)
	if err != nil {
		log.Fatalf("Erro ao iniciar o servidor Go: %v", err)
	}
}
