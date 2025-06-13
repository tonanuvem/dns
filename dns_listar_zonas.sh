#!/bin/bash

echo "🔍 Buscando zonas hospedadas no Route 53..."

# Lista todas as zonas e armazena em um array de nomes e IDs
ZONAS_JSON=$(aws route53 list-hosted-zones --output json)

# Conta quantas zonas existem
QTD_ZONAS=$(echo "$ZONAS_JSON" | jq '.HostedZones | length')

# Se não tiver nenhuma zona
if [ "$QTD_ZONAS" -eq 0 ]; then
    echo "❌ Nenhuma zona encontrada no Route 53."
    exit 1
fi

# Se tiver só uma zona
if [ "$QTD_ZONAS" -eq 1 ]; then
    ZONA_ID=$(echo "$ZONAS_JSON" | jq -r '.HostedZones[0].Id' | sed 's|/hostedzone/||')
    NOME_DOMINIO=$(echo "$ZONAS_JSON" | jq -r '.HostedZones[0].Name' | sed 's/\.$//')
    echo "✅ Apenas uma zona encontrada: $ZONA_ID ($NOME_DOMINIO)"
else
    echo "📋 Zonas encontradas:"
    for i in $(seq 0 $((QTD_ZONAS - 1))); do
        NOME=$(echo "$ZONAS_JSON" | jq -r ".HostedZones[$i].Name")
        ID=$(echo "$ZONAS_JSON" | jq -r ".HostedZones[$i].Id" | sed 's|/hostedzone/||')
        echo "[$i] $NOME ($ID)"
    done

    # Pede ao usuário para escolher uma
    echo ""
    read -p "👉 Digite o número da zona desejada: " ESCOLHA

    # Verifica se é número válido
    if ! [[ "$ESCOLHA" =~ ^[0-9]+$ ]] || [ "$ESCOLHA" -ge "$QTD_ZONAS" ]; then
        echo "❌ Opção inválida."
        exit 1
    fi

    ZONA_ID=$(echo "$ZONAS_JSON" | jq -r ".HostedZones[$ESCOLHA].Id" | sed 's|/hostedzone/||')
    NOME_DOMINIO=$(echo "$ZONAS_JSON" | jq -r ".HostedZones[$ESCOLHA].Name" | sed 's/\.$//')
fi

# Testes temporários
export NOME_ALUNO=$1
export SENHA_COMPARTILHADA=$2
envsubst < terraform/terraform.tfvars.example > terraform/terraform.tfvars

# Atualizar o arquivo terraform.tfvars com o ID da zona e nome do domínio
TF_VARS_FILE="terraform/terraform.tfvars"

# Verificar se o arquivo existe
if [ ! -f "$TF_VARS_FILE" ]; then
    echo "❌ Arquivo $TF_VARS_FILE não encontrado"
    exit 1
fi

# Atualizar o ID da zona e nome do domínio no arquivo
sed -i "s/id_zona_hospedada = \".*\"/id_zona_hospedada = \"$ZONA_ID\"/" "$TF_VARS_FILE"
sed -i "s/nome_dominio = \".*\"/nome_dominio = \"$NOME_DOMINIO\"/" "$TF_VARS_FILE"

echo "✅ ID da zona e nome do domínio atualizados no arquivo $TF_VARS_FILE"

echo ""
echo "📄 Detalhes da zona $ZONA_ID:"
aws route53 get-hosted-zone --id "$ZONA_ID"
