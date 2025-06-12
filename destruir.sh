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

# 1. Verificar se estamos no diretório correto
print_message "$YELLOW" "\n1. Verificando diretório..."

if [ ! -f "$BASE_DIR/terraform/main.tf" ]; then
    print_message "$RED" "❌ Arquivo terraform/main.tf não encontrado."
    print_message "$YELLOW" "Execute o script do diretório raiz do projeto."
    exit 1
fi

# 2. Limpar arquivos temporários
print_message "$YELLOW" "\n2. Limpando arquivos temporários..."

# Remover arquivo ZIP do Lambda
if [ -f "$BASE_DIR/terraform/modules/lambda_api/lambda_function.zip" ]; then
    rm "$BASE_DIR/terraform/modules/lambda_api/lambda_function.zip"
    check_status "Remoção do arquivo ZIP do Lambda"
fi

# 3. Executar terraform destroy
print_message "$YELLOW" "\n3. Executando terraform destroy..."

# Navegar para o diretório terraform
cd "$BASE_DIR/terraform"

# Executar terraform destroy
print_message "$YELLOW" "Executando terraform destroy..."
terraform destroy -auto-approve
check_status "Terraform destroy"

# 4. Limpar arquivos do Terraform
print_message "$YELLOW" "\n4. Limpando arquivos do Terraform..."

# Remover arquivos de estado e cache
rm -f .terraform.lock.hcl
rm -f terraform.tfstate
rm -f terraform.tfstate.backup
rm -rf .terraform
check_status "Limpeza dos arquivos do Terraform"

print_message "$GREEN" "\n✅ Processo de destruição concluído com sucesso!" 