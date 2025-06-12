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

# Criar e ativar ambiente virtual
echo "Ativando ambiente virtual..."
python3 -m venv venv
source venv/bin/activate

# Atualizar pip
pip install --upgrade pip

# Instalar dependências
if [ -f "requirements.txt" ]; then
    pip install -r requirements.txt
else
    echo "Arquivo requirements.txt não encontrado"
    exit 1
fi

# Tornar os scripts executáveis
chmod +x scripts/configurar_aluno.py
chmod +x scripts/dns_list_zonas.py

# Executar o script Python
python3 scripts/configurar_aluno.py "$1" "$2"