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

# Tornar o script Python executável
chmod +x configurar_aluno.py

# Executar o script Python
python3 configurar_aluno.py "$1" "$2" 