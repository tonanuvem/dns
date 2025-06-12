#!/bin/bash

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

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
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Verificar se o script config.sh foi executado
if [ ! -f "$BASE_DIR/config.sh" ]; then
    print_message "O arquivo config.sh não foi encontrado. Execute-o primeiro." "$RED"
    exit 1
fi

# Verificar se as variáveis de ambiente estão configuradas
if [ -z "$AWS_ACCESS_KEY_ID" ] || [ -z "$AWS_SECRET_ACCESS_KEY" ] || [ -z "$AWS_DEFAULT_REGION" ]; then
    print_message "As variáveis de ambiente AWS não estão configuradas. Execute o config.sh primeiro." "$RED"
    exit 1
fi

# Verificar se o arquivo ZIP da função Lambda existe
if [ ! -f "$BASE_DIR/lambda_zip/gerenciador_dns.zip" ]; then
    print_message "O arquivo ZIP da função Lambda não foi encontrado. Execute o config.sh primeiro." "$RED"
    exit 1
fi

# Criar build do frontend
print_message "Criando build do frontend..." "$YELLOW"
"$BASE_DIR/scripts/create_frontend.sh"
check_status "Build do frontend criado com sucesso" "Erro ao criar build do frontend"

# Executar o script de deploy
print_message "Executando deploy..." "$YELLOW"
"$BASE_DIR/scripts/deploy.sh"
check_status "Deploy concluído com sucesso" "Erro ao executar deploy"

print_message "Processo concluído com sucesso!" "$GREEN" 