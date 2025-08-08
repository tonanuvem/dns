#!/bin/bash

# =======================================================
# Script para testar os endpoints da API
#
# - Este script executa testes automatizados para os verbos GET, POST e DELETE.
# - Ele cria um subdomínio único a cada execução para evitar conflitos.
# - O JSON de teste é embutido no próprio script para maior praticidade.
# =======================================================

# --- Variáveis de Configuração ---
# Substitua 'aluno' pela sua chave de API, se for diferente.
API_KEY="aluno"
# URL base da sua API Gateway.
API_URL="https://tsll3rchh7.execute-api.us-east-1.amazonaws.com/prod"
# URLs completas para os endpoints.
REGISTROS_URL="$API_URL/registros"
INFO_URL="$API_URL/info"
# Cria um subdomínio único usando a data e hora atuais.
# Isso evita que o teste falhe se você rodar o script várias vezes.
SUBDOMINIO="teste-api-$(date +%s)"

# --- JSON para o teste de POST ---
# O 'heredoc' (<<EOF) permite definir um bloco de texto JSON no próprio script.
# A variável "$SUBDOMINIO" é expandida para o valor único que criamos acima.
read -r -d '' JSON_DATA <<EOF
{
  "subdominio": "$SUBDOMINIO",
  "endereco_ip": "192.0.2.1"
}
EOF

echo "========================================"
echo "Iniciando testes da API..."
echo "Subdomínio de teste: $SUBDOMINIO"
echo "========================================"
echo ""

# --- Teste GET /info ---
# Comando curl:
# -s: Modo silencioso, suprime a barra de progresso.
# -i: Inclui os headers da resposta na saída.
# -H: Adiciona o header 'X-API-Key' para autenticação.
echo "=> Testando GET /info..."
curl -s -i -H "X-API-Key: $API_KEY" "$INFO_URL"

echo ""
echo "----------------------------------------"
echo ""

# --- Teste GET /registros ---
echo "=> Testando GET /registros..."
curl -s -i -H "X-API-Key: $API_KEY" "$REGISTROS_URL"

echo ""
echo "----------------------------------------"
echo ""

# --- Teste POST /registros ---
# Comando curl:
# -X POST: Define o método HTTP como POST.
# -H "Content-Type: application/json": Informa que o corpo da requisição é JSON.
# -d "$JSON_DATA": Envia o conteúdo da nossa variável 'JSON_DATA' no corpo da requisição.
echo "=> Testando POST /registros..."
echo "JSON a ser enviado: "
echo "$JSON_DATA"
curl -s -i -X POST -H "Content-Type: application/json" -H "X-API-Key: $API_KEY" -d "$JSON_DATA" "$REGISTROS_URL"

echo ""
echo "----------------------------------------"
echo ""

# --- Teste DELETE /registros/{subdominio} ---
# Comando curl:
# -X DELETE: Define o método HTTP como DELETE.
# A URL utiliza a variável 'SUBDOMINIO' para deletar o registro que acabamos de criar.
echo "=> Testando DELETE /registros/$SUBDOMINIO..."
curl -s -i -X DELETE -H "X-API-Key: $API_KEY" "$REGISTROS_URL/$SUBDOMINIO"

echo ""
echo "========================================"
echo "Testes concluídos!"
echo "========================================"