#!/bin/bash

# Cria diretório ./files se não existir
mkdir -p ./files

echo "Cole suas credenciais da AWS e pressione ENTER (duas vezes):"

# Lê entrada até a primeira linha em branco
CRED=$(sed '/^$/q')

# Salva as credenciais completas no arquivo
echo "$CRED" > ./files/credentials

# Lê linha por linha diretamente da string, sem usar pipe (evita subshell)
while IFS='=' read -r chave valor; do
    # Ignora linha [default] ou vazia
    [[ "$chave" =~ ^\[.*\]$ || -z "$chave" ]] && continue

    chave=$(echo "$chave" | xargs)
    valor=$(echo "$valor" | xargs)

    if [[ -n "$chave" && -n "$valor" ]]; then
        export "$chave=$valor"
        echo "Exportado: $chave"

        upper_key=$(echo "$chave" | tr '[:lower:]' '[:upper:]')
        export "$upper_key=$valor"
        echo "Exportado (uppercase): $upper_key"
    fi
done <<< "$CRED"

aws sts get-caller-identity

echo "Credenciais salvas em ./files/credentials"
