#!/bin/bash

# Verificar se o Python 3 está instalado
if ! command -v python3 &> /dev/null; then
    echo "Erro: Python 3 não está instalado"
    exit 1
fi

# Verificar se os argumentos foram fornecidos
if [ $# -ne 2 ]; then
    echo "Uso: ./configurar.sh <nome_aluno> <senha>"
    exit 1
fi

# Tornar o script Python executável
chmod +x configurar_aluno.py

# Executar o script Python
python3 configurar_aluno.py "$1" "$2" 