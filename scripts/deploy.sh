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

# Verificar se o AWS CLI está instalado
if ! command -v aws &> /dev/null; then
    print_message "AWS CLI não está instalado. Por favor, instale-o primeiro." "$RED"
    exit 1
fi

# Verificar se as credenciais AWS estão configuradas
#print_message "Verificando credenciais AWS..." "$YELLOW"
#if ! aws sts get-caller-identity &> /dev/null; then
#    print_message "Credenciais AWS não configuradas ou inválidas." "$RED"
#    print_message "Por favor, configure suas credenciais AWS:" "$YELLOW"
#    aws configure
#    check_status "Credenciais AWS configuradas com sucesso" "Erro ao configurar credenciais AWS"
#fi

# Verificar se as variáveis de ambiente AWS estão configuradas
#if [ -z "$AWS_ACCESS_KEY_ID" ] || [ -z "$AWS_SECRET_ACCESS_KEY" ] || [ -z "$AWS_DEFAULT_REGION" ]; then
#    print_message "Configurando variáveis de ambiente AWS..." "$YELLOW"
#    export AWS_ACCESS_KEY_ID=$(aws configure get aws_access_key_id)
#    export AWS_SECRET_ACCESS_KEY=$(aws configure get aws_secret_access_key)
#    export AWS_DEFAULT_REGION=$(aws configure get region)
#    check_status "Variáveis de ambiente AWS configuradas com sucesso" "Erro ao configurar variáveis de ambiente AWS"
#fi

# Verificar se estamos no diretório correto
if [ ! -f "$BASE_DIR/terraform/main.tf" ]; then
    print_message "Erro: Arquivo main.tf não encontrado. Execute este script do diretório raiz do projeto." "$RED"
    exit 1
fi

# Verificar se o arquivo ZIP da função Lambda existe
if [ ! -f "$BASE_DIR/lambda_zip/gerenciador_dns.zip" ]; then
    print_message "Erro: Arquivo ZIP da função Lambda não encontrado. Execute ./scripts/create_backend.sh primeiro." "$RED"
    exit 1
fi

# Verificar se o build do frontend existe
if [ ! -d "$BASE_DIR/frontend/build" ]; then
    print_message "Erro: Build do frontend não encontrado. Execute ./scripts/create_frontend.sh primeiro." "$RED"
    exit 1
fi

# Navegar para o diretório terraform
cd "$BASE_DIR/terraform"

# Inicializar o Terraform
print_message "Inicializando Terraform..." "$YELLOW"
terraform init
check_status "Terraform inicializado com sucesso" "Erro ao inicializar Terraform"

# Criar arquivo de plano
print_message "Criando plano de execução..." "$YELLOW"
terraform plan -out=tfplan
check_status "Plano criado com sucesso" "Erro ao criar plano"

# Aplicar as mudanças
print_message "Aplicando mudanças..." "$YELLOW"
terraform apply tfplan
check_status "Mudanças aplicadas com sucesso" "Erro ao aplicar mudanças"

print_message "Deploy concluído com sucesso!" "$GREEN"