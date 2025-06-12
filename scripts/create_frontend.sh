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

# Verificar se o Node.js está instalado
if ! command -v node &> /dev/null; then
    print_message "Node.js não está instalado. Por favor, instale o Node.js primeiro." "$RED"
    exit 1
fi

# Verificar se o npm está instalado
if ! command -v npm &> /dev/null; then
    print_message "npm não está instalado. Por favor, instale o npm primeiro." "$RED"
    exit 1
fi

# Navegar para o diretório do frontend
cd "$BASE_DIR/frontend" || exit 1

# Instalar dependências
print_message "Instalando dependências..." "$YELLOW"
npm install
check_status "Dependências instaladas com sucesso" "Erro ao instalar dependências"

# Criar build do frontend
print_message "Criando build do frontend..." "$YELLOW"
npm run build
check_status "Build do frontend criado com sucesso" "Erro ao criar build do frontend"

# Copiar arquivos para o diretório do Terraform
print_message "Copiando arquivos para o diretório do Terraform..." "$YELLOW"
rm -rf "$BASE_DIR/terraform/frontend_build"
cp -r "$BASE_DIR/frontend/build" "$BASE_DIR/terraform/frontend_build"
check_status "Arquivos copiados com sucesso" "Erro ao copiar arquivos"

print_message "Frontend criado com sucesso!" "$GREEN" 