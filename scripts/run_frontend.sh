#!/bin/bash

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Função para imprimir mensagens
print_message() {
    echo -e "${2}${1}${NC}"
}

# Função para verificar status do comando
check_status() {
    if [ $? -eq 0 ]; then
        print_message "✓ $1" "$GREEN"
    else
        print_message "✗ $2" "$RED"
        exit 1
    fi
}

# Obter o diretório base do projeto
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# --- Configurações do Frontend ---
FRONTEND_DIR="dns_admin" # Diretório do seu projeto frontend
DEFAULT_PORT="3000"      # Porta padrão, caso não seja encontrada no vite.config.js

# --- Validações Iniciais ---
# Verificar se o Node.js está instalado
if ! command -v node &> /dev/null; then
    print_message "Node.js não está instalado. Por favor, instale o Node.js primeiro." "$RED"
    exit 1
fi

# Verificar se o Yarn está instalado
if ! command -v yarn &> /dev/null; then
    print_message "Yarn não está instalado. Por favor, instale o Yarn primeiro." "$RED"
    exit 1
fi

# Verificar se o diretório do frontend existe
if [ ! -d "$BASE_DIR/$FRONTEND_DIR" ]; then
    print_message "O diretório do frontend não foi encontrado em $BASE_DIR/$FRONTEND_DIR." "$RED"
    exit 1
fi

# Navegar para o diretório do frontend
print_message "Navegando para o diretório do frontend: $FRONTEND_DIR" "$YELLOW"
cd "$BASE_DIR/$FRONTEND_DIR"
check_status "Diretório do frontend acessado com sucesso." "Erro ao acessar o diretório do frontend."

# --- Execução do Frontend ---

# Obter a porta do vite.config.js, ou usar a porta padrão
PORTA=$(grep -oP '(?<=port: )\d+' vite.config.js 2>/dev/null | head -n 1)
if [ -z "$PORTA" ]; then
    PORTA="$DEFAULT_PORT"
    print_message "Porta não encontrada em vite.config.js. Usando porta padrão: $DEFAULT_PORT" "$YELLOW"
fi

# Obter o IP de rede para acesso externo
# Usa checkip.amazonaws.com para obter o IP público
IP=$(curl -s checkip.amazonaws.com 2>/dev/null)
if [ -z "$IP" ]; then
    IP="localhost" # Fallback para localhost se o IP externo não puder ser obtido
    print_message "Não foi possível obter o IP de rede. Acesse via localhost." "$YELLOW"
fi

# Iniciar o servidor de desenvolvimento com Yarn
print_message "Iniciando o servidor de desenvolvimento do frontend com Yarn..." "$YELLOW"
yarn dev --host --port "$PORTA"
check_status "Servidor de desenvolvimento do frontend iniciado. Acesse em http://localhost:$PORTA ou http://$IP:$PORTA" "Erro ao iniciar o servidor de desenvolvimento do frontend."

print_message "Frontend em execução!" "$GREEN"
