#!/bin/bash

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Função para imprimir mensagens
print_message() {
    echo -e "${1}${2}${NC}"
}

# Função para verificar status
check_status() {
    if [ $? -eq 0 ]; then
        print_message "$GREEN" "✅ $1 concluído com sucesso!"
    else
        print_message "$RED" "❌ Erro ao $1"
        exit 1
    fi
}

# Obtém o diretório base do projeto
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 1. Verificar se o config.sh foi executado
print_message "$YELLOW" "\n1. Verificando configuração inicial..."

# Verificar se o arquivo terraform.tfvars existe
if [ ! -f "$BASE_DIR/terraform/terraform.tfvars" ]; then
    print_message "$RED" "❌ Arquivo terraform.tfvars não encontrado."
    print_message "$YELLOW" "Execute o script config.sh primeiro:"
    print_message "$YELLOW" "./config.sh"
    exit 1
fi

# 2. Verificar e criar o arquivo ZIP do Lambda
print_message "$YELLOW" "\n2. Verificando arquivo ZIP do Lambda..."

# Verificar se o diretório lambda existe
if [ ! -d "$BASE_DIR/lambda" ]; then
    print_message "$RED" "❌ Diretório lambda não encontrado."
    exit 1
fi

# Verificar se o arquivo gerenciador_dns.py existe
if [ ! -f "$BASE_DIR/lambda/gerenciador_dns.py" ]; then
    print_message "$RED" "❌ Arquivo lambda/gerenciador_dns.py não encontrado."
    exit 1
fi

# Criar diretório lambda_zip se não existir
mkdir -p "$BASE_DIR/lambda_zip"

# Criar arquivo ZIP do Lambda
print_message "$YELLOW" "Criando arquivo ZIP do Lambda..."
cd "$BASE_DIR/lambda"
zip -r "$BASE_DIR/lambda_zip/gerenciador_dns.zip" .
cd "$BASE_DIR"
check_status "Criação do arquivo ZIP do Lambda"

# Copiar o arquivo ZIP para o diretório do módulo lambda
print_message "$YELLOW" "Copiando arquivo ZIP para o módulo lambda..."
cp "$BASE_DIR/lambda_zip/gerenciador_dns.zip" "$BASE_DIR/terraform/modules/lambda_api/lambda_function.zip"
check_status "Cópia do arquivo ZIP"

# 3. Executar deploy
print_message "$YELLOW" "\n3. Executando deploy..."

# Verificar se o script deploy.sh existe
if [ ! -f "$BASE_DIR/scripts/deploy.sh" ]; then
    print_message "$RED" "❌ Script scripts/deploy.sh não encontrado."
    exit 1
fi

# Tornar o script deploy.sh executável
chmod +x "$BASE_DIR/scripts/deploy.sh"

# Executar o deploy
"$BASE_DIR/scripts/deploy.sh"
check_status "Terraform deploy"

print_message "$GREEN" "\n✅ Processo concluído com sucesso!" 