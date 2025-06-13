#!/bin/bash

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Função para imprimir mensagens
print_message() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

# Função para imprimir erros
print_error() {
    echo -e "${RED}[ERRO]${NC} $1"
}

# Função para verificar se um comando foi bem sucedido
check_status() {
    if [ $? -eq 0 ]; then
        print_message "$1"
    else
        print_error "$2"
        exit 1
    fi
}

# Verificar se o AWS CLI está instalado
if ! command -v aws &> /dev/null; then
    print_error "AWS CLI não está instalado"
    exit 1
fi

# Verificar se as credenciais AWS estão configuradas
if ! aws sts get-caller-identity &> /dev/null; then
    print_error "Credenciais AWS não configuradas"
    exit 1
fi

# Verificar se a LabRole existe
print_message "Verificando existência da LabRole..."
if ! aws iam get-role --role-name LabRole &> /dev/null; then
    print_error "LabRole não encontrada"
    exit 1
fi

# Verificar políticas gerenciadas
print_message "Verificando políticas gerenciadas..."
aws iam list-attached-role-policies --role-name LabRole --query 'AttachedPolicies[*].PolicyName' --output text
check_status "Políticas gerenciadas verificadas" "Erro ao verificar políticas gerenciadas"

# Verificar políticas inline
print_message "Verificando políticas inline..."
aws iam list-role-policies --role-name LabRole --query 'PolicyNames' --output text
check_status "Políticas inline verificadas" "Erro ao verificar políticas inline"

print_message "LabRole encontrada e verificada com sucesso!"
print_message "Próximos passos:"
print_message "1. Verifique se as políticas anexadas têm as permissões necessárias para:"
print_message "   - Lambda (criar e gerenciar funções)"
print_message "   - API Gateway (criar e gerenciar APIs)"
print_message "   - DynamoDB (criar e gerenciar tabelas)"
print_message "   - Route 53 (criar e gerenciar registros DNS)"
print_message "   - S3 (criar e gerenciar buckets)"
print_message "   - CloudFront (criar e gerenciar distribuições)"
print_message "2. Se alguma permissão estiver faltando, solicite ao administrador para adicionar as políticas necessárias"