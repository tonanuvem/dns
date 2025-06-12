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

# Verifica se o venv existe, se não, cria
if [ ! -d "venv" ]; then
    echo "Criando ambiente virtual..."
    python3 -m venv venv
fi

# Ativa o venv
echo "Ativando ambiente virtual..."
source venv/bin/activate

# Instala/atualiza pip
python -m pip install --upgrade pip

# Verifica se requirements.txt existe
if [ -f "requirements.txt" ]; then
    echo "Instalando dependências..."
    pip install -r requirements.txt
else
    echo "Arquivo requirements.txt não encontrado"
    exit 1
fi


# Torna o script configurar.sh executável
chmod +x configurar.sh
chmod +x criar.sh
chmod +x dns_listar_zonas.sh

# Executa o script de configuração passando os argumentos
./configurar.sh "$NOME_ALUNO" "$SENHA"