#!/bin/bash

# Verifica se os dois argumentos foram passados
if [ $# -ne 2 ]; then
  echo "Uso: $0 <nome_aluno> <senha>"
  exit 1
fi

NOME_ALUNO="$1"
SENHA="$2"

# Navega até a pasta scripts
cd scripts || { echo "Erro: pasta 'scripts' não encontrada"; exit 1; }

# Torna o script configurar.sh executável
chmod +x configurar.sh

# Executa o script de configuração passando os argumentos
./configurar.sh "$NOME_ALUNO" "$SENHA"