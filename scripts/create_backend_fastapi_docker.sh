#!/bin/bash

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_message() {
    echo -e "${2}${1}${NC}"
}

check_status() {
    if [ $? -eq 0 ]; then
        print_message "✓ $1" "$GREEN"
    else
        print_message "✗ $2" "$RED"
        exit 1
    fi
}

# --- Configurações ---
# Diretório onde está o código da sua aplicação FastAPI (gerenciador_dns.py, app.py)
LAMBDA_APP_DIR="lambda_fastapi"
# Diretório temporário para a construção do pacote
BUILD_DIR="lambda_build"
# Nome do arquivo ZIP final
ZIP_FILE="fastapi_lambda_function.zip"
# Diretório de destino do ZIP
ZIP_OUTPUT_MODULE_DIR="terraform/modules/lambda_api"

# Obter o diretório base do projeto
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FULL_LAMBDA_APP_PATH="$BASE_DIR/$LAMBDA_APP_DIR"
FULL_BUILD_PATH="$BASE_DIR/$BUILD_DIR"
FULL_ZIP_OUTPUT_PATH="$BASE_DIR/$ZIP_OUTPUT_MODULE_DIR/$ZIP_FILE"

# --- Validações Iniciais ---
if [ ! -d "$FULL_LAMBDA_APP_PATH" ]; then
    print_message "O diretório da aplicação Lambda não foi encontrado em $FULL_LAMBDA_APP_PATH." "$RED"
    exit 1
fi
if [ ! -f "$FULL_LAMBDA_APP_PATH/requirements.txt" ]; then
    print_message "O arquivo requirements.txt não foi encontrado em $FULL_LAMBDA_APP_PATH." "$RED"
    exit 1
fi
if [ ! -f "$FULL_LAMBDA_APP_PATH/gerenciador_dns.py" ]; then
    print_message "O arquivo gerenciador_dns.py não foi encontrado em $FULL_LAMBDA_APP_PATH." "$RED"
    exit 1
fi
if [ ! -f "$FULL_LAMBDA_APP_PATH/app.py" ]; then
    print_message "O arquivo app.py não foi encontrado em $FULL_LAMBDA_APP_PATH." "$RED"
    exit 1
fi

print_message "Iniciando o empacotamento do FastAPI para o Lambda usando Docker..." "$YELLOW"

# Limpar e criar diretório de build
print_message "Preparando diretórios de build..." "$YELLOW"
rm -rf "$FULL_BUILD_PATH"
mkdir -p "$FULL_BUILD_PATH"
mkdir -p "$BASE_DIR/$ZIP_OUTPUT_MODULE_DIR"

# Copiar o código da aplicação para o diretório de build
print_message "Copiando o código da aplicação para o diretório de build..." "$YELLOW"
cp "$FULL_LAMBDA_APP_PATH/gerenciador_dns.py" "$FULL_BUILD_PATH/"
cp "$FULL_LAMBDA_APP_PATH/app.py" "$FULL_BUILD_PATH/"
cp "$FULL_LAMBDA_APP_PATH/requirements.txt" "$FULL_BUILD_PATH/"
check_status "Código da aplicação copiado." "Erro ao copiar código da aplicação."

# Instalar dependências usando Docker
print_message "Instalando dependências Python em ambiente Docker compatível com Lambda..." "$YELLOW"
docker run --rm \
    -v "$FULL_BUILD_PATH":/var/task \
    public.ecr.aws/lambda/python:3.9 \
    /bin/bash -c "pip install -r /var/task/requirements.txt -t /var/task/python && rm -rf /var/task/requirements.txt"
check_status "Dependências instaladas via Docker." "Erro ao instalar dependências via Docker."

# Mover as dependências para a raiz do pacote (se pip instalou em /python)
# O comando pip install -t /var/task/python já coloca as libs em /var/task/python
# e o zip abaixo irá incluir essa pasta python no raiz do zip.
# Se você quiser que as libs estejam na raiz do zip, você precisaria mover o conteúdo de /var/task/python para /var/task
# Ex: mv /var/task/python/* /var/task/ && rm -rf /var/task/python

# Criar o arquivo ZIP final
print_message "Compactando o pacote do Lambda..." "$YELLOW"
cd "$FULL_BUILD_PATH"
zip -r "$FULL_ZIP_OUTPUT_PATH" .
check_status "Arquivo ZIP do Lambda criado com sucesso em $FULL_ZIP_OUTPUT_PATH" "Erro ao criar arquivo ZIP."

# Limpeza
print_message "Removendo diretório de build temporário..." "$YELLOW"
rm -rf "$FULL_BUILD_PATH"
check_status "Limpeza concluída." "Erro na limpeza."

print_message "Backend FastAPI preparado com sucesso!" "$GREEN"