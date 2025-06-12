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

# Verifica se o AWS CLI está instalado
if ! command -v aws &> /dev/null; then
    echo "AWS CLI não encontrado. Por favor, instale-o primeiro."
    exit 1
fi

# Verifica se o Terraform está instalado
if ! command -v terraform &> /dev/null; then
    echo "Terraform não encontrado. Por favor, instale-o primeiro."
    exit 1
fi

# Obtém o diretório base do projeto
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# 1. Verificar se estamos no diretório correto
print_message "$YELLOW" "\n1. Verificando diretório..."

if [ ! -f "$BASE_DIR/terraform/main.tf" ]; then
    print_message "$RED" "❌ Arquivo terraform/main.tf não encontrado."
    print_message "$YELLOW" "Execute o script do diretório raiz do projeto."
    exit 1
fi

# 2. Verificar arquivos necessários
print_message "$YELLOW" "\n2. Verificando arquivos necessários..."

# Verificar arquivo ZIP do Lambda
if [ ! -f "$BASE_DIR/terraform/modules/lambda_api/lambda_function.zip" ]; then
    print_message "$RED" "❌ Arquivo ZIP do Lambda não encontrado."
    print_message "$YELLOW" "Execute o script criar.sh primeiro."
    exit 1
fi

# Verificar build do frontend
if [ ! -d "$BASE_DIR/terraform/frontend_build" ]; then
    print_message "$RED" "❌ Diretório frontend_build não encontrado."
    print_message "$YELLOW" "Execute o script create_frontend.sh primeiro."
    exit 1
fi

# 3. Executar terraform
print_message "$YELLOW" "\n3. Executando Terraform..."

# Navegar para o diretório terraform
cd "$BASE_DIR/terraform"

# Inicializar o Terraform
print_message "$YELLOW" "Inicializando o Terraform..."
terraform init
check_status "Inicialização do Terraform"

# Criar plano de execução
print_message "$YELLOW" "Criando plano de execução..."
terraform plan -out=tfplan
check_status "Criação do plano"

# Aplicar as mudanças
print_message "$YELLOW" "Aplicando mudanças..."
terraform apply tfplan
check_status "Aplicação das mudanças"

print_message "$GREEN" "\n✅ Deploy concluído com sucesso!" 