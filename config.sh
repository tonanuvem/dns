#!/bin/bash

# Obter o diretório do script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# Mudar para o diretório do script
cd "$SCRIPT_DIR"

# Verificar se Python 3 está instalado
if ! command -v python3 &> /dev/null; then
    echo "Erro: Python 3 não está instalado"
    exit 1
fi

# Verificar argumentos
if [ "$#" -ne 2 ]; then
    echo "Uso: $0 <nome_aluno> <senha>"
    exit 1
fi

# Criar ambiente virtual se não existir
if [ ! -d "venv" ]; then
    echo "Criando ambiente virtual..."
    python3 -m venv venv
fi

# Ativar ambiente virtual
echo "Ativando ambiente virtual..."
source venv/bin/activate

# Atualizar pip
echo "Atualizando pip..."
pip install --upgrade pip

# Instalar dependências
echo "Instalando dependências..."
if [ -f "requirements.txt" ]; then
    pip install -r requirements.txt
else
    echo "Erro: Arquivo requirements.txt não encontrado"
    exit 1
fi

# Tornar os scripts executáveis
echo "Configurando permissões dos scripts..."
chmod +x scripts/configurar_aluno.py
chmod +x scripts/dns_list_zonas.py

# Executar o script Python
echo "Executando configuração..."
python3 scripts/configurar_aluno.py "$1" "$2"

# Listar zonas DNS disponíveis
echo -e "\nZonas DNS disponíveis:"
echo "======================"
python3 scripts/dns_list_zonas.py

# Desativar ambiente virtual
deactivate