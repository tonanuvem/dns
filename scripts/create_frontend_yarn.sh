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

# --- Configurações do Frontend ---
FRONTEND_DIR="dns_admin" # Diretório do seu projeto frontend
BUILD_OUTPUT_DIR="dist"  # Geralmente 'dist' para projetos Vite/Yarn, ou 'build' se configurado
TERRAFORM_DEST_DIR="$BASE_DIR/terraform/frontend_build"

# --- Validações Iniciais ---
# Verificar se o Node.js está instalado
if ! command -v node &> /dev/null; then
    print_message "Node.js não está instalado. Por favor, instale o Node.js primeiro." "$RED"
    exit 1
fi

# Verificar se o Yarn está instalado
if ! command -v yarn &> /dev/null; then
    print_message "Yarn não está instalado. Por favor, instale o Yarn primeiro." "$RED"
    exit 1
fi

# Verificar se o diretório do frontend existe
if [ ! -d "$BASE_DIR/$FRONTEND_DIR" ]; then
    print_message "O diretório do frontend não foi encontrado em $BASE_DIR/$FRONTEND_DIR." "$RED"
    exit 1
fi

# Navegar para o diretório do frontend
print_message "Navegando para o diretório do frontend: $FRONTEND_DIR" "$YELLOW"
cd "$BASE_DIR/$FRONTEND_DIR"
check_status "Diretório do frontend acessado com sucesso." "Erro ao acessar o diretório do frontend."

# --- Processo de Build do Frontend ---

# Instalar dependências com Yarn
print_message "Instalando dependências do frontend com Yarn..." "$YELLOW"
yarn install
check_status "Dependências instaladas com sucesso." "Erro ao instalar dependências com Yarn."

# Criar build do frontend com Yarn
print_message "Criando build de produção do frontend com Yarn..." "$YELLOW"
yarn build
check_status "Build do frontend criado com sucesso." "Erro ao criar build do frontend com Yarn."

# --- Copiar Arquivos para o Terraform ---

# Limpar diretório de destino do Terraform antes de copiar
print_message "Limpando diretório de destino do Terraform: $TERRAFORM_DEST_DIR" "$YELLOW"
rm -rf "$TERRAFORM_DEST_DIR"
check_status "Diretório de destino limpo." "Erro ao limpar diretório de destino."

# Copiar os arquivos do build para o diretório do Terraform
print_message "Copiando arquivos do build para o diretório do Terraform..." "$YELLOW"
cp -r "$BASE_DIR/$FRONTEND_DIR/$BUILD_OUTPUT_DIR" "$TERRAFORM_DEST_DIR"
check_status "Arquivos do build copiados com sucesso." "Erro ao copiar arquivos do build."

print_message "Frontend preparado com sucesso para o Terraform!" "$GREEN"