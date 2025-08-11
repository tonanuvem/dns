#!/bin/bash

# Obter o diretório do script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# Mudar para o diretório do script
cd "$SCRIPT_DIR"

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

# Verificar se Python 3 está instalado
if ! command -v python3 &> /dev/null; then
    print_error "Python 3 não está instalado"
    exit 1
fi

# Verificar argumentos
if [ "$#" -ne 2 ]; then
    print_error "Uso: $0 <nome_aluno> <senha>"
    exit 1
fi

# Atribuir os parâmetros a variáveis
NOME_ALUNO=$1
SENHA_COMPARTILHADA=$2

# Verificar se o arquivo terraform.tfvars.example existe
if [ ! -f "terraform/terraform.tfvars.example" ]; then
    print_error "Arquivo terraform.tfvars.example não encontrado"
    exit 1
fi

# Obter o account_id da AWS
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null)
if [ -z "$ACCOUNT_ID" ]; then
    print_error "Não foi possível obter o account_id da AWS. Verifique suas credenciais."
    exit 1
fi

# Criar terraform.tfvars a partir do exemplo
print_message "Criando arquivo de configuração do Terraform..."
# Exportar variáveis de ambiente para substituição
export NOME_ALUNO="$NOME_ALUNO"
export SENHA_COMPARTILHADA="$SENHA_COMPARTILHADA"

# Criar terraform.tfvars a partir do exemplo, substituindo as variáveis de ambiente
envsubst < terraform/terraform.tfvars.example > terraform/terraform.tfvars

# Substituir manualmente as variáveis que não foram substituídas (caso envsubst não funcione para todas)
sed -i "s|\${NOME_ALUNO}|$NOME_ALUNO|g" terraform/terraform.tfvars
sed -i "s|\${SENHA_COMPARTILHADA}|$SENHA_COMPARTILHADA|g" terraform/terraform.tfvars

# Inserir ou atualizar o account_id no terraform.tfvars
if grep -q '^account_id' terraform/terraform.tfvars; then
    sed -i "s/^account_id.*/account_id = \"$ACCOUNT_ID\"/" terraform/terraform.tfvars
else
    echo "account_id = \"$ACCOUNT_ID\"" >> terraform/terraform.tfvars
fi
check_status "Arquivo terraform.tfvars criado com sucesso" "Falha ao criar terraform.tfvars"

# Verificar se o arquivo terraform.tfvars foi atualizado corretamente
print_message "Verificando atualizações no arquivo de configuração..."
# if grep -q "nome_aluno = \"$NOME_ALUNO\"" terraform/terraform.tfvars; then
#     print_message "✓ Nome do aluno atualizado com sucesso"
# else
#     print_error "Falha ao atualizar nome do aluno"
#     print_message "Conteúdo atual do arquivo terraform.tfvars:"
#     cat terraform/terraform.tfvars
# fi

# if grep -q "api_gateway_nome_aluno = \"$NOME_ALUNO\"" terraform/terraform.tfvars; then
#     print_message "✓ Nome do aluno no API Gateway atualizado com sucesso"
# else
#     print_error "Falha ao atualizar nome do aluno no API Gateway"
#     print_message "Conteúdo atual do arquivo terraform.tfvars:"
#     cat terraform/terraform.tfvars
# fi

# if grep -q "frontend_nome_aluno = \"$NOME_ALUNO\"" terraform/terraform.tfvars; then
#     print_message "✓ Nome do aluno no Frontend atualizado com sucesso"
# else
#     print_error "Falha ao atualizar nome do aluno no Frontend"
#     print_message "Conteúdo atual do arquivo terraform.tfvars:"
#     cat terraform/terraform.tfvars
# fi

# if grep -q "senha_compartilhada = \"$SENHA_COMPARTILHADA\"" terraform/terraform.tfvars; then
#     print_message "✓ Senha compartilhada atualizada com sucesso"
# else
#     print_error "Falha ao atualizar senha compartilhada"
#     print_message "Conteúdo atual do arquivo terraform.tfvars:"
#     cat terraform/terraform.tfvars
# fi

print_message "Configuração do arquivo terraform.tfvars concluída!"

# Criar ambiente virtual se não existir
if [ ! -d "venv" ]; then
    print_message "Criando ambiente virtual..."
    python3 -m venv venv
fi

# Ativar ambiente virtual
print_message "Ativando ambiente virtual..."
source venv/bin/activate

# Atualizar pip
print_message "Atualizando pip..."
pip install --upgrade pip

# Instalar dependências
print_message "Instalando dependências..."
if [ -f "requirements.txt" ]; then
    pip install -r requirements.txt
else
    print_error "Arquivo requirements.txt não encontrado"
    exit 1
fi

# Verificar LabRole
print_message "Verificando LabRole..."
./scripts/validar_LabRole.sh
check_status "LabRole validada com sucesso" "Falha na validação do LabRole"

# Tornar os scripts executáveis
print_message "Configurando permissões dos scripts..."
chmod +x scripts/validar_LabRole.sh
chmod +x scripts/create_backend.sh
chmod +x scripts/create_frontend.sh
chmod +x scripts/update_frontend.sh
chmod +x scripts/deploy.sh
check_status "Permissões configuradas com sucesso" "Falha ao configurar permissões"

# Listar zonas DNS disponíveis
print_message "Verificando zonas DNS disponíveis..."
echo "====================================="
python3 scripts/dns_list_zonas.py

# Verificar se a zona do aluno existe
print_message "Verificando zona DNS do aluno..."
echo "================================="
ZONE_ID=$(python3 scripts/dns_list_zonas.py "${1}.lab.tonanuvem.com")
if [ -z "$ZONE_ID" ]; then
    print_error "Zona DNS '${1}.lab.tonanuvem.com' não encontrada"
    exit 1
fi
print_message "✓ Zona DNS encontrada: $ZONE_ID"

# Substituir ou inserir o id_zona_hospedada no terraform.tfvars
if grep -q '^id_zona_hospedada' terraform/terraform.tfvars; then
    sed -i "s/^id_zona_hospedada.*/id_zona_hospedada = \"$ZONE_ID\"/" terraform/terraform.tfvars
else
    echo "id_zona_hospedada = \"$ZONE_ID\"" >> terraform/terraform.tfvars
fi
check_status "ID da zona hospedada atualizado com sucesso" "Falha ao atualizar ID da zona hospedada"

# Executar o script Python
#print_message "Executando configuração..."
#python3 scripts/configurar_aluno.py "$1" "$2"

# Desativar ambiente virtual
deactivate

echo -e "\nConfiguração concluída com sucesso!"
echo -e "\nPróximo passo:"
#echo "1. Execute ./criar.sh para criar o build do backend e frontend"
echo "- Execute ./scripts/deploy.sh para fazer o deploy da infraestrutura"
echo ""
echo "Após o deploy, você poderá acessar:"
echo "- Frontend: https://www.${1}.lab.tonanuvem.com"
echo "- API: https://api.${1}.lab.tonanuvem.com"