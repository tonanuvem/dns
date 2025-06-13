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
        return 1
    fi
}

# Verificar se o AWS CLI está instalado
if ! command -v aws &> /dev/null; then
    print_message "AWS CLI não está instalado. Por favor, instale-o primeiro." "$RED"
    exit 1
fi

# Verificar se as credenciais AWS estão configuradas
print_message "Verificando credenciais AWS..." "$YELLOW"
if ! aws sts get-caller-identity &> /dev/null; then
    print_message "Credenciais AWS não configuradas ou inválidas." "$RED"
    print_message "Por favor, configure suas credenciais AWS:" "$YELLOW"
    aws configure
    check_status "Credenciais AWS configuradas com sucesso" "Erro ao configurar credenciais AWS"
fi

# Verificar se a LabRole existe
print_message "Verificando se a LabRole existe..." "$YELLOW"
if ! aws iam get-role --role-name LabRole &> /dev/null; then
    print_message "Aviso: LabRole não encontrada" "$RED"
    print_message "O deploy pode falhar se a LabRole não existir" "$YELLOW"
else
    print_message "LabRole encontrada" "$GREEN"
fi

# Listar políticas gerenciadas
print_message "\nPolíticas gerenciadas:" "$YELLOW"
aws iam list-attached-role-policies --role-name LabRole --query 'AttachedPolicies[*].PolicyName' --output text
check_status "Políticas gerenciadas listadas" "Falha ao listar políticas gerenciadas"

# Listar políticas inline
print_message "\nPolíticas inline:" "$YELLOW"
aws iam list-role-policies --role-name LabRole --query 'PolicyNames' --output text
check_status "Políticas inline listadas" "Falha ao listar políticas inline"

# Verificar permissões necessárias
print_message "\nVerificando permissões necessárias..." "$YELLOW"

# Lista de permissões necessárias
PERMISSIONS=(
    "dynamodb:GetItem"
    "dynamodb:PutItem"
    "dynamodb:UpdateItem"
    "dynamodb:DeleteItem"
    "dynamodb:Scan"
    "dynamodb:Query"
    "lambda:InvokeFunction"
    "apigateway:*"
    "route53:*"
    "s3:*"
    "cloudfront:*"
    "acm:*"
    "logs:*"
)

# Verificar cada permissão
has_errors=false
for permission in "${PERMISSIONS[@]}"; do
    if ! aws iam simulate-principal-policy --policy-source-arn "arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/LabRole" --action-names "$permission" --query 'EvaluationResults[0].EvalDecision' --output text | grep -q "allowed"; then
        print_message "Aviso: Permissão $permission não encontrada" "$RED"
        has_errors=true
    else
        print_message "✓ Permissão $permission encontrada" "$GREEN"
    fi
done

# Informar sobre permissões faltantes
if [ "$has_errors" = true ]; then
    print_message "\nAviso: Algumas permissões necessárias não foram encontradas na LabRole" "$RED"
    print_message "O deploy pode falhar se as permissões necessárias não estiverem configuradas" "$YELLOW"
else
    print_message "\nTodas as permissões necessárias foram encontradas!" "$GREEN"
fi

print_message "\nValidação concluída!" "$GREEN" 