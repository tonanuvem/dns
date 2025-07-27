#!/bin/bash

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "⚠️  Este script deve ser executado com 'source' para manter as variáveis na sessão atual do shell."
  echo "   Use: source $0"
  exit 1
fi

mkdir -p ./files

echo "Cole suas credenciais da AWS e pressione ENTER (duas vezes):"
CRED=$(sed '/^$/q')

CREDENTIALS_FILE="./files/credentials"
echo "$CRED" > "$CREDENTIALS_FILE"

echo ""
echo "# Exportando variáveis de ambiente para esta sessão..."

# Usar loop while sem pipe (sem subshell)
while IFS='=' read -r chave valor; do
  # Ignora linhas de seção, como [default]
  [[ "$chave" =~ ^\[.*\]$ ]] && continue

  chave=$(echo "$chave" | xargs)
  valor=$(echo "$valor" | xargs)

  if [[ -n "$chave" && -n "$valor" ]]; then
    export "$chave"="$valor"
    upper_key=$(echo "$chave" | tr '[:lower:]' '[:upper:]')
    export "$upper_key"="$valor"
    echo "Exportado: $chave=\"$valor\""
  fi
done <<< "$CRED"

echo ""
echo "✅ Credenciais exportadas para esta sessão atual do shell."
echo "📝 Arquivo temporário salvo em: $CREDENTIALS_FILE"
