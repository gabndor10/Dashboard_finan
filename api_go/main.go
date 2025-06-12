// main.go
package main

import (
	"encoding/json" // Para codificar e decodificar JSON
	"fmt"           // Para formatação de strings (impressão)
	"log"           // Para logs de erro e informações
	"net/http"      // Para criar o servidor HTTP e manipular requisições
	"sync"          // Para garantir a segurança de acesso a dados compartilhados (mutex)
	//"time"          // Para lidar com tempo, útil para timestamps
)

// DadoSGS representa a estrutura de um dado de série temporal recebido do Rust.
// Os campos são tagsadas com `json:"..."` para mapear os nomes do JSON.
type DadoSGS struct {
	Data  string `json:"data"`  // Data do dado (ex: "01/01/2024")
	Valor string `json:"valor"` // Valor do indicador (ex: "5.25")
}

// GlobalDataStore simula um armazenamento em memória para os dados do SGS.
// Em um sistema real, isso seria um banco de dados (ex: PostgreSQL, SQLite).
// Um RWMutex é usado para controlar o acesso concorrente aos dados,
// permitindo múltiplos leitores ou um único escritor por vez.
type GlobalDataStore struct {
	mu    sync.RWMutex             // Mutex para proteção de acesso concorrente
	dados map[string][]DadoSGS // Mapa: chave (código série) -> lista de dados
	// Ex: {"433": [{Data: "...", Valor: "..."}, ...]}
}

// nossoDataStore é a instância global do armazenamento de dados.
var nossoDataStore = GlobalDataStore{
	dados: make(map[string][]DadoSGS),
}

// handleReceiveData recebe dados financeiros do módulo Rust via POST.
func handleReceiveData(w http.ResponseWriter, r *http.Request) {
	// Garante que a requisição é um POST.
	if r.Method != http.MethodPost {
		http.Error(w, "Método não permitido. Use POST.", http.StatusMethodNotAllowed)
		log.Printf("Erro: Tentativa de acesso com método não permitido: %s", r.Method)
		return
	}

	// Define uma variável para decodificar o JSON recebido.
	// O Rust enviará um mapa com códigos de série e suas respectivas listas de DadosSGS.
	var dadosRecebidos map[string][]DadoSGS
	err := json.NewDecoder(r.Body).Decode(&dadosRecebidos)
	if err != nil {
		http.Error(w, "Erro ao decodificar JSON: "+err.Error(), http.StatusBadRequest)
		log.Printf("Erro ao decodificar JSON da requisição: %v", err)
		return
	}

	// Protege o acesso ao armazenamento global com um Mutex para escrita.
	nossoDataStore.mu.Lock()
	defer nossoDataStore.mu.Unlock() // Garante que o mutex será liberado ao final da função.

	// Atualiza os dados no armazenamento. Para este exemplo, substituímos os dados existentes.
	// Em um cenário real, você poderia mergear, inserir no banco de dados, etc.
	for codigo, listaDados := range dadosRecebidos {
		nossoDataStore.dados[codigo] = listaDados
		log.Printf("Dados para série %s atualizados. Total de %d itens.", codigo, len(listaDados))
	}

	w.WriteHeader(http.StatusOK) // Retorna status 200 OK
	fmt.Fprintf(w, "Dados recebidos e processados com sucesso!")
	log.Println("Dados recebidos e processados com sucesso do Rust.")
}

// handleGetIndicators expõe os dados financeiros armazenados via GET para o módulo Dart.
func handleGetIndicators(w http.ResponseWriter, r *http.Request) {
	// Garante que a requisição é um GET.
	if r.Method != http.MethodGet {
		http.Error(w, "Método não permitido. Use GET.", http.StatusMethodNotAllowed)
		log.Printf("Erro: Tentativa de acesso com método não permitido: %s", r.Method)
		return
	}

	// Protege o acesso ao armazenamento global com um RLock (leitura).
	nossoDataStore.mu.RLock()
	defer nossoDataStore.mu.RUnlock() // Garante que o RWMutex será liberado.

	// Verifica se há dados disponíveis.
	if len(nossoDataStore.dados) == 0 {
		http.Error(w, "Nenhum dado financeiro disponível no momento.", http.StatusNotFound)
		log.Println("Erro: Nenhuns dados financeiros disponíveis para o Dart.")
		return
	}

	// Define o cabeçalho Content-Type para indicar que a resposta é JSON.
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK) // Retorna status 200 OK

	// Codifica os dados armazenados como JSON e os escreve na resposta HTTP.
	err := json.NewEncoder(w).Encode(nossoDataStore.dados)
	if err != nil {
		log.Printf("Erro ao codificar JSON para resposta: %v", err)
		// Já escrevemos o cabeçalho, então não podemos usar http.Error novamente,
		// apenas registrar o erro.
	}
	log.Println("Dados financeiros enviados para o Dart.")
}

func main() {
	// Configura as rotas do servidor HTTP.
	// "/dados/sgs" para receber dados do Rust.
	http.HandleFunc("/dados/sgs", handleReceiveData)
	// "/api/v1/indicadores" para expor dados ao Dart.
	http.HandleFunc("/api/v1/indicadores", handleGetIndicators)

	// Inicia o servidor HTTP na porta 8080.
	port := ":8080"
	log.Printf("Servidor Go iniciado na porta %s. Aguardando requisições...", port)
	// log.Fatal(http.ListenAndServe(port, nil)) inicia o servidor e bloqueia.
	// Se houver um erro ao iniciar o servidor, ele será logado e o programa encerrará.
	err := http.ListenAndServe(port, nil)
	if err != nil {
		log.Fatalf("Erro ao iniciar o servidor Go: %v", err)
	}
}