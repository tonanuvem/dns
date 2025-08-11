#!/bin/bash

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

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
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Verificar se o diretório lambda existe
if [ ! -d "$BASE_DIR/lambda" ]; then
    print_message "Erro: Diretório lambda não encontrado" "$RED"
    exit 1
fi

# Verificar se o arquivo gerenciador_dns.py existe
if [ ! -f "$BASE_DIR/lambda/gerenciador_dns.py" ]; then
    print_message "Erro: Arquivo gerenciador_dns.py não encontrado" "$RED"
    exit 1
fi

# Criar diretório lambda_zip se não existir
if [ ! -d "$BASE_DIR/lambda_zip" ]; then
    print_message "Criando diretório lambda_zip..." "$YELLOW"
    mkdir -p "$BASE_DIR/lambda_zip"
    check_status "Diretório lambda_zip criado com sucesso" "Erro ao criar diretório lambda_zip"
fi

# Criar arquivo ZIP da função Lambda
print_message "Criando arquivo ZIP da função Lambda..." "$YELLOW"
cd "$BASE_DIR/lambda"
zip -r "$BASE_DIR/lambda_zip/gerenciador_dns.zip" .
check_status "Arquivo ZIP criado com sucesso" "Erro ao criar arquivo ZIP"

# Verificar se o arquivo ZIP foi criado
if [ ! -f "$BASE_DIR/lambda_zip/gerenciador_dns.zip" ]; then
    print_message "Erro: Arquivo ZIP não foi criado" "$RED"
    exit 1
fi

# Verificar conteúdo do arquivo ZIP
print_message "Verificando conteúdo do arquivo ZIP..." "$YELLOW"
unzip -l "$BASE_DIR/lambda_zip/gerenciador_dns.zip" | grep "gerenciador_dns.py" > /dev/null
check_status "Arquivo gerenciador_dns.py encontrado no ZIP" "Arquivo gerenciador_dns.py não encontrado no ZIP"

# Criar build do frontend
print_message "Criando build do frontend..." "$YELLOW"
"$BASE_DIR/scripts/create_frontend_yarn.sh"
check_status "Build do frontend criado com sucesso" "Erro ao criar build do frontend"

print_message "Build do backend e frontend concluído com sucesso!" "$GREEN"
print_message "\nPróximo passo:" "$YELLOW"
print_message "Execute ./scripts/deploy.sh para fazer o deploy da infraestrutura" "$YELLOW" 