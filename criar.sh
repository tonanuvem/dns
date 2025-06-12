#!/bin/bash

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Função para imprimir mensagens coloridas
print_message() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Função para verificar se um comando foi executado com sucesso
check_status() {
    if [ $? -eq 0 ]; then
        print_message "$GREEN" "✓ $1"
        return 0
    else
        print_message "$RED" "✗ $1"
        return 1
    fi
}

# Função para esperar a propagação DNS
wait_for_dns() {
    local domain=$1
    local max_attempts=30
    local attempt=1
    
    print_message "$YELLOW" "Aguardando propagação DNS para $domain..."
    
    while [ $attempt -le $max_attempts ]; do
        if dig +short $domain > /dev/null; then
            print_message "$GREEN" "✓ DNS propagado para $domain"
            return 0
        fi
        
        print_message "$YELLOW" "Tentativa $attempt de $max_attempts..."
        sleep 10
        attempt=$((attempt + 1))
    done
    
    print_message "$RED" "✗ Timeout aguardando propagação DNS para $domain"
    return 1
}

# Carregar variáveis de ambiente
if [ -f .env ]; then
    source .env
else
    print_message "$RED" "Erro: Arquivo .env não encontrado"
    exit 1
fi

# Verificar se as variáveis necessárias estão definidas
if [ -z "$NOME_ALUNO" ] || [ -z "$SENHA_API" ]; then
    print_message "$RED" "Erro: Variáveis NOME_ALUNO ou SENHA_API não definidas no arquivo .env"
    exit 1
fi

print_message "$YELLOW" "Iniciando deploy do ambiente para o aluno: $NOME_ALUNO"
echo "=================================================="

# 1. Inicializar Terraform
print_message "$YELLOW" "\n1. Inicializando Terraform..."
cd terraform
terraform init
check_status "Terraform init"

# 2. Verificar plano de execução
print_message "$YELLOW" "\n2. Verificando plano de execução..."
terraform plan
check_status "Terraform plan"

# 3. Executar deploy
print_message "$YELLOW" "\n3. Executando deploy..."
./scripts/deploy.sh
check_status "Terraform deploy"

# 4. Obter outputs do Terraform
print_message "$YELLOW" "\n4. Obtendo informações do ambiente..."
API_ENDPOINT=$(terraform output -raw api_endpoint)
ZONE_ID=$(terraform output -raw zona_id)
NAMESERVERS=$(terraform output -raw nameservers)

# 5. Validar recursos AWS
print_message "$YELLOW" "\n5. Validando recursos AWS..."

# Lambda
print_message "$YELLOW" "Verificando função Lambda..."
aws lambda get-function --function-name "gerenciador-dns-$NOME_ALUNO" > /dev/null
check_status "Função Lambda"

# DynamoDB
print_message "$YELLOW" "Verificando tabela DynamoDB..."
aws dynamodb describe-table --table-name "registros-dns-$NOME_ALUNO" > /dev/null
check_status "Tabela DynamoDB"

# API Gateway
print_message "$YELLOW" "Verificando API Gateway..."
aws apigatewayv2 get-apis --query "Items[?Name=='api-dns-$NOME_ALUNO']" --output text > /dev/null
check_status "API Gateway"

# 6. Validar DNS
print_message "$YELLOW" "\n6. Validando configuração DNS..."

# Verificar zona hospedada
print_message "$YELLOW" "Verificando zona hospedada..."
aws route53 get-hosted-zone --id "$ZONE_ID" > /dev/null
check_status "Zona hospedada"

# Aguardar propagação DNS
wait_for_dns "$NOME_ALUNO.lab.tonanuvem.com"

# 7. Testar API
print_message "$YELLOW" "\n7. Testando API..."

# Criar registro de teste
print_message "$YELLOW" "Criando registro de teste..."
curl -s -X POST "$API_ENDPOINT" \
    -H "Content-Type: application/json" \
    -H "X-API-Key: $SENHA_API" \
    -d '{
        "subdominio": "teste",
        "endereco_ip": "1.1.1.1"
    }' > /dev/null
check_status "Criação de registro"

# Aguardar propagação do registro de teste
wait_for_dns "teste.$NOME_ALUNO.lab.tonanuvem.com"

# 8. Resumo final
print_message "$GREEN" "\n=================================================="
print_message "$GREEN" "Deploy concluído com sucesso!"
print_message "$GREEN" "=================================================="
print_message "$GREEN" "\nInformações do ambiente:"
echo "Nome do aluno: $NOME_ALUNO"
echo "API Endpoint: $API_ENDPOINT"
echo "ID da Zona: $ZONE_ID"
echo "Nameservers:"
echo "$NAMESERVERS" | tr ',' '\n'
echo ""
print_message "$GREEN" "URLs de acesso:"
echo "Frontend: https://$NOME_ALUNO.lab.tonanuvem.com"
echo "API: https://api.$NOME_ALUNO.lab.tonanuvem.com"
echo ""
print_message "$YELLOW" "Próximos passos:"
echo "1. Configure os nameservers no seu registrador de domínio"
echo "2. Aguarde a propagação completa do DNS (pode levar até 48 horas)"
echo "3. Acesse o frontend e teste a criação de registros"
echo ""
print_message "$YELLOW" "Para limpar o ambiente:"
echo "cd terraform && terraform destroy" 