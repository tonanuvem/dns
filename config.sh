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

# Verificar se o script está sendo executado no diretório correto
if [ ! -f "terraform/main.tf" ]; then
    print_message "Erro: Execute este script a partir do diretório raiz do projeto" "$RED"
    exit 1
fi

# Verificar se o AWS CLI está instalado
if ! command -v aws &> /dev/null; then
    print_message "Erro: AWS CLI não está instalado" "$RED"
    exit 1
fi

# Verificar se as credenciais AWS estão configuradas
if ! aws sts get-caller-identity &> /dev/null; then
    print_message "Erro: Credenciais AWS não configuradas" "$RED"
    exit 1
fi

# Verificar se o LabRole existe
print_message "Verificando LabRole..." "$YELLOW"
./scripts/validar_LabRole.sh
check_status "LabRole validada com sucesso" "Falha ao validar LabRole"

# Verificar se o Node.js está instalado
if ! command -v node &> /dev/null; then
    print_message "Erro: Node.js não está instalado" "$RED"
    exit 1
fi

# Verificar se o npm está instalado
if ! command -v npm &> /dev/null; then
    print_message "Erro: npm não está instalado" "$RED"
    exit 1
fi

# Verificar se o Python está instalado
if ! command -v python3 &> /dev/null; then
    print_message "Erro: Python 3 não está instalado" "$RED"
    exit 1
fi

# Verificar se o pip está instalado
if ! command -v pip3 &> /dev/null; then
    print_message "Erro: pip3 não está instalado" "$RED"
    exit 1
fi

# Verificar se o Terraform está instalado
if ! command -v terraform &> /dev/null; then
    print_message "Erro: Terraform não está instalado" "$RED"
    exit 1
fi

# Verificar se o arquivo de variáveis existe
if [ ! -f "terraform/terraform.tfvars" ]; then
    print_message "Criando arquivo de variáveis..." "$YELLOW"
    cp terraform/terraform.tfvars.example terraform/terraform.tfvars
    check_status "Arquivo de variáveis criado" "Falha ao criar arquivo de variáveis"
fi

# Atualizar variáveis nos módulos
print_message "Atualizando variáveis nos módulos..." "$YELLOW"

# Função para atualizar variáveis em um módulo
update_module_variables() {
    local module=$1
    local prefix=$2
    local file="terraform/modules/${module}/variables.tf"
    
    # Atualizar nome_aluno
    sed -i '' "s/variable \"${prefix}_nome_aluno\"/variable \"${prefix}_nome_aluno\" {/g" "$file"
    sed -i '' "/variable \"${prefix}_nome_aluno\"/,/}/c\\
variable \"${prefix}_nome_aluno\" {\\
  description = \"Nome do aluno para prefixo dos recursos\"\\
  type        = string\\
}" "$file"
    
    # Atualizar nome_dominio
    sed -i '' "s/variable \"${prefix}_nome_dominio\"/variable \"${prefix}_nome_dominio\" {/g" "$file"
    sed -i '' "/variable \"${prefix}_nome_dominio\"/,/}/c\\
variable \"${prefix}_nome_dominio\" {\\
  description = \"Nome do domínio base para os recursos\"\\
  type        = string\\
  default     = \"dns.lab\"\\
}" "$file"
    
    # Atualizar tags
    sed -i '' "s/variable \"${prefix}_tags\"/variable \"${prefix}_tags\" {/g" "$file"
    sed -i '' "/variable \"${prefix}_tags\"/,/}/c\\
variable \"${prefix}_tags\" {\\
  description = \"Tags padrão para todos os recursos\"\\
  type        = map(string)\\
  default     = {}\\
}" "$file"
}

# Atualizar variáveis em cada módulo
update_module_variables "api_gateway" "api_gateway"
update_module_variables "frontend" "frontend"
update_module_variables "lambda_api" "lambda_api"

check_status "Variáveis atualizadas com sucesso" "Falha ao atualizar variáveis"

# Atualizar arquivo terraform.tfvars
print_message "Atualizando arquivo terraform.tfvars..." "$YELLOW"

# Função para atualizar variáveis no arquivo principal
update_main_variables() {
    local file="terraform/terraform.tfvars"
    
    # Atualizar variáveis globais
    sed -i '' "s/nome_aluno = .*/nome_aluno = \"$1\"/" "$file"
    sed -i '' "s/nome_dominio = .*/nome_dominio = \"$2\"/" "$file"
    
    # Atualizar variáveis dos módulos
    sed -i '' "s/api_gateway_nome_aluno = .*/api_gateway_nome_aluno = \"$1\"/" "$file"
    sed -i '' "s/api_gateway_nome_dominio = .*/api_gateway_nome_dominio = \"$2\"/" "$file"
    sed -i '' "s/frontend_nome_aluno = .*/frontend_nome_aluno = \"$1\"/" "$file"
    sed -i '' "s/frontend_nome_dominio = .*/frontend_nome_dominio = \"$2\"/" "$file"
}

# Atualizar variáveis com os valores fornecidos
update_main_variables "$1" "$2"

check_status "Arquivo terraform.tfvars atualizado" "Falha ao atualizar arquivo terraform.tfvars"

print_message "Configuração concluída com sucesso!" "$GREEN"