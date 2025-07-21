#!/bin/bash

# Cria diretório ./files se não existir
mkdir -p ./files

echo "Cole suas credenciais da AWS e pressione ENTER (duas vezes):"

# Lê entrada até a primeira linha em branco
CRED=$(sed '/^$/q')

# Define o arquivo onde as credenciais serão salvas
CREDENTIALS_FILE="./files/credentials"
# Salva todas as credenciais em um arquivo
echo "$CRED" > "$CREDENTIALS_FILE"

# Define o arquivo de perfil (ajuste para zsh, se necessário)
SHELL_PROFILE="$HOME/.bashrc"  # ou ~/.bash_profile, dependendo da distro

# Remove blocos anteriores adicionados pelo script (caso o usuário execute mais de uma vez)
sed -i '/# AWS Academy START/,/# AWS Academy END/d' "$SHELL_PROFILE"

# Adiciona novo bloco de exportações
{
    echo ""
    echo "# AWS Academy START"
    echo "# Essas variáveis foram adicionadas por config_credenciais.sh em $(date)"
    echo "$CRED" | grep -v '^\[.*\]$' | while IFS='=' read -r chave valor; do
        chave=$(echo "$chave" | xargs)
        valor=$(echo "$valor" | xargs)

        if [[ -n "$chave" && -n "$valor" ]]; then
            echo "export $chave=\"$valor\""
            upper_key=$(echo "$chave" | tr '[:lower:]' '[:upper:]')
            echo "export $upper_key=\"$valor\""
        fi
    done
    echo "# AWS Academy END"
} >> "$SHELL_PROFILE"

echo ""
echo "Credenciais exportadas e salvas em:"
echo " - Arquivo temporário: $CREDENTIALS_FILE"
echo " - Shell profile: $SHELL_PROFILE"

echo ""
echo "⚠️  Abra um novo terminal ou execute:"
echo "   source $SHELL_PROFILE"
echo "para ativar as credenciais neste ambiente."
