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

# Verificar se o script config.sh foi executado
if [ ! -f "$BASE_DIR/config.sh" ]; then
    print_message "O arquivo config.sh não foi encontrado. Execute-o primeiro." "$RED"
    exit 1
fi

# Verificar se o diretório frontend_build existe
if [ ! -d "$BASE_DIR/terraform/frontend_build" ]; then
    print_message "O diretório frontend_build não foi encontrado. Execute o create_frontend.sh primeiro." "$RED"
    exit 1
fi

# Verificar se o bucket S3 existe
BUCKET_NAME=$(grep -A 1 "bucket" "$BASE_DIR/terraform/terraform.tfvars" | grep -v "bucket" | tr -d ' "')
if [ -z "$BUCKET_NAME" ]; then
    print_message "Não foi possível encontrar o nome do bucket S3 no arquivo terraform.tfvars." "$RED"
    exit 1
fi

# Verificar se o bucket existe
if ! aws s3 ls "s3://$BUCKET_NAME" &> /dev/null; then
    print_message "O bucket S3 $BUCKET_NAME não existe." "$RED"
    exit 1
fi

# Atualizar os arquivos no S3
print_message "Atualizando arquivos no S3..." "$YELLOW"
aws s3 sync "$BASE_DIR/terraform/frontend_build" "s3://$BUCKET_NAME" --delete
check_status "Arquivos atualizados com sucesso no S3" "Erro ao atualizar arquivos no S3"

# Invalidar o cache do CloudFront
print_message "Invalidando cache do CloudFront..." "$YELLOW"
DISTRIBUTION_ID=$(grep -A 1 "distribution_id" "$BASE_DIR/terraform/terraform.tfvars" | grep -v "distribution_id" | tr -d ' "')
if [ -n "$DISTRIBUTION_ID" ]; then
    aws cloudfront create-invalidation --distribution-id "$DISTRIBUTION_ID" --paths "/*"
    check_status "Cache do CloudFront invalidado com sucesso" "Erro ao invalidar cache do CloudFront"
else
    print_message "Não foi possível encontrar o ID da distribuição CloudFront no arquivo terraform.tfvars." "$YELLOW"
fi

print_message "Frontend atualizado com sucesso!" "$GREEN" 