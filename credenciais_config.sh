#!/bin/bash

# Verifica se o script foi executado com "source" ou "."
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "⚠️  Este script deve ser executado com 'source' para manter as variáveis na sessão atual do shell."
  echo "   Use: source $0"
  exit 1
fi

# Cria diretório ./files se não existir
mkdir -p ./files

echo "Cole suas credenciais da AWS e pressione ENTER (duas vezes):"

# Lê entrada até a primeira linha em branco
CRED=$(sed '/^$/q')

# Define o arquivo onde as credenciais serão salvas
CREDENTIALS_FILE="./files/credentials"
echo "$CRED" > "$CREDENTIALS_FILE"

# Exporta variáveis de ambiente para a sessão atual
echo ""
echo "# Exportando variáveis de ambiente para esta sessão..."

echo "$CRED" | grep -v '^\[.*\]$' | while IFS='=' read -r chave valor; do
    chave=$(echo "$chave" | xargs)
    valor=$(echo "$valor" | xargs)

    if [[ -n "$chave" && -n "$valor" ]]; then
        export "$chave"="$valor"
        upper_key=$(echo "$chave" | tr '[:lower:]' '[:upper:]')
        export "$upper_key"="$valor"
        echo "Exportado: $chave=\"$valor\""
    fi
done

echo ""
echo "✅ Credenciais exportadas para esta sessão atual do shell."
echo "📝 Arquivo temporário salvo em: $CREDENTIALS_FILE"
