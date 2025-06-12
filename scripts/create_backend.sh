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

# Verificar se o diretório lambda existe
if [ ! -d "$BASE_DIR/lambda" ]; then
    print_message "O diretório lambda não foi encontrado." "$RED"
    exit 1
fi

# Verificar se o arquivo gerenciador_dns.py existe
if [ ! -f "$BASE_DIR/lambda/gerenciador_dns.py" ]; then
    print_message "O arquivo lambda/gerenciador_dns.py não foi encontrado." "$RED"
    exit 1
fi

# Criar diretório do módulo lambda se não existir
mkdir -p "$BASE_DIR/terraform/modules/lambda_api"

# Criar diretório lambda_zip se não existir
mkdir -p "$BASE_DIR/lambda_zip"

# Criar arquivo ZIP do Lambda
print_message "Criando arquivo ZIP do Lambda..." "$YELLOW"
cd "$BASE_DIR/lambda"
zip -r "$BASE_DIR/lambda_zip/gerenciador_dns.zip" .
cd "$BASE_DIR"
check_status "Arquivo ZIP do Lambda criado com sucesso" "Erro ao criar arquivo ZIP do Lambda"

# Verificar se o arquivo ZIP foi criado corretamente
if [ ! -f "$BASE_DIR/lambda_zip/gerenciador_dns.zip" ]; then
    print_message "O arquivo ZIP não foi criado corretamente." "$RED"
    exit 1
fi

# Verificar se o arquivo ZIP tem conteúdo
if [ ! -s "$BASE_DIR/lambda_zip/gerenciador_dns.zip" ]; then
    print_message "O arquivo ZIP está vazio." "$RED"
    exit 1
fi

# Copiar o arquivo ZIP para o diretório do módulo lambda
print_message "Copiando arquivo ZIP para o módulo lambda..." "$YELLOW"
cp "$BASE_DIR/lambda_zip/gerenciador_dns.zip" "$BASE_DIR/terraform/modules/lambda_api/lambda_function.zip"
check_status "Arquivo ZIP copiado com sucesso" "Erro ao copiar arquivo ZIP"

print_message "Backend criado com sucesso!" "$GREEN" 