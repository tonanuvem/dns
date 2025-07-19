#!/bin/bash

# Cria o diretório ./files se não existir
mkdir -p ./files

echo "Cole suas credenciais da AWS e pressione ENTER após colar todas elas:"
read -r -d '' CRED

# Salva as credenciais completas no arquivo
echo "$CRED" > ./files/credentials

# Exporta apenas as variáveis (ignorando a linha [default] se existir)
echo "$CRED" | grep -v '^\[.*\]$' | while IFS='=' read -r chave valor; do
    chave=$(echo "$chave" | xargs)
    valor=$(echo "$valor" | xargs)
    if [[ -n "$chave" && -n "$valor" ]]; then
        export "$chave=$valor"
        echo "Exportado: $chave"
    fi
done

echo "Credenciais salvas em ./files/credentials"
