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

# 1. Verificar se o config.sh foi executado
print_message "$YELLOW" "\n1. Verificando configuração inicial..."

# Verificar se as variáveis de ambiente necessárias estão definidas
if [ -z "$AWS_ACCESS_KEY_ID" ] || [ -z "$AWS_SECRET_ACCESS_KEY" ]; then
    print_message "$RED" "❌ Variáveis de ambiente AWS não configuradas."
    print_message "$YELLOW" "Execute o script config.sh primeiro:"
    print_message "$YELLOW" "./config.sh"
    exit 1
fi

# Verificar se o arquivo terraform.tfvars existe
if [ ! -f "terraform/terraform.tfvars" ]; then
    print_message "$RED" "❌ Arquivo terraform.tfvars não encontrado."
    print_message "$YELLOW" "Execute o script config.sh primeiro:"
    print_message "$YELLOW" "./config.sh"
    exit 1
fi

# 2. Verificar e criar o arquivo ZIP do Lambda
print_message "$YELLOW" "\n2. Verificando arquivo ZIP do Lambda..."

# Verificar se o diretório lambda existe
if [ ! -d "lambda" ]; then
    print_message "$RED" "❌ Diretório lambda não encontrado."
    exit 1
fi

# Verificar se o arquivo gerenciador_dns.py existe
if [ ! -f "lambda/gerenciador_dns.py" ]; then
    print_message "$RED" "❌ Arquivo lambda/gerenciador_dns.py não encontrado."
    exit 1
fi

# Criar diretório lambda_zip se não existir
mkdir -p lambda_zip

# Criar arquivo ZIP do Lambda
print_message "$YELLOW" "Criando arquivo ZIP do Lambda..."
cd lambda
zip -r ../lambda_zip/gerenciador_dns.zip .
cd ..
check_status "Criação do arquivo ZIP do Lambda"

# 3. Executar deploy
print_message "$YELLOW" "\n3. Executando deploy..."

# Verificar se o script deploy.sh existe
if [ ! -f "scripts/deploy.sh" ]; then
    print_message "$RED" "❌ Script scripts/deploy.sh não encontrado."
    exit 1
fi

# Tornar o script deploy.sh executável
chmod +x scripts/deploy.sh

# Executar o deploy
./scripts/deploy.sh
check_status "Terraform deploy"

print_message "$GREEN" "\n✅ Processo concluído com sucesso!" 