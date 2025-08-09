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

# --- Configurações do Projeto FastAPI ---
# A nova estrutura de arquivos está em /lambda_fastapi
# Arquivos da aplicação
APP_FILES=("app.py" "gerenciador_dns.py")
# Arquivo de dependências
REQUIREMENTS_FILE="requirements.txt"
# Nome do arquivo ZIP final
ZIP_FILE="fastapi_lambda_function.zip"

# Obter o diretório base do projeto
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LAMBDA_DIR="$BASE_DIR/lambda_fastapi" # Caminho atualizado
PACKAGE_DIR="$BASE_DIR/lambda_package"
ZIP_OUTPUT_PATH="$BASE_DIR/terraform/modules/lambda_api/$ZIP_FILE"

# --- Validações Iniciais ---
if [ ! -d "$LAMBDA_DIR" ]; then
    print_message "O diretório lambda não foi encontrado em $LAMBDA_DIR." "$RED"
    exit 1
fi

if [ ! -f "$LAMBDA_DIR/$REQUIREMENTS_FILE" ]; then
    print_message "O arquivo $REQUIREMENTS_FILE não foi encontrado em $LAMBDA_DIR." "$RED"
    exit 1
fi

for file in "${APP_FILES[@]}"; do
    if [ ! -f "$LAMBDA_DIR/$file" ]; then
        print_message "O arquivo de aplicação $file não foi encontrado em $LAMBDA_DIR." "$RED"
        exit 1
    fi
done

# --- Processo de Empacotamento ---
print_message "Iniciando o empacotamento do FastAPI para o Lambda..." "$YELLOW"

# Criar e limpar diretórios
print_message "Preparando diretórios..." "$YELLOW"
mkdir -p "$PACKAGE_DIR"
mkdir -p "$BASE_DIR/terraform/modules/lambda_api"

# Instalar dependências no diretório de empacotamento
print_message "Instalando dependências do Python..." "$YELLOW"
pip install -r "$LAMBDA_DIR/$REQUIREMENTS_FILE" --target "$PACKAGE_DIR"
check_status "Dependências instaladas com sucesso." "Erro ao instalar dependências. Verifique o arquivo $REQUIREMENTS_FILE"

# Copiar os arquivos da aplicação para o diretório de empacotamento
print_message "Copiando arquivos da aplicação para o pacote..." "$YELLOW"
cp "$LAMBDA_DIR/"* "$PACKAGE_DIR/"
check_status "Arquivos da aplicação copiados com sucesso." "Erro ao copiar arquivos da aplicação"

# Criar o arquivo ZIP final
print_message "Compactando o pacote do Lambda..." "$YELLOW"
cd "$PACKAGE_DIR"
zip -r "$ZIP_OUTPUT_PATH" .
check_status "Arquivo ZIP do Lambda criado com sucesso em $ZIP_OUTPUT_PATH" "Erro ao criar arquivo ZIP"

# Limpeza: Remover a pasta temporária de dependências
print_message "Removendo pasta temporária de dependências..." "$YELLOW"
rm -rf "$PACKAGE_DIR"
check_status "Limpeza concluída." "Erro na limpeza do diretório"

print_message "Backend FastAPI preparado com sucesso!" "$GREEN"