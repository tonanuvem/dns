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
    echo "✅ Apenas uma zona encontrada: $ZONA_ID"
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
fi

# Atualizar o arquivo terraform.tfvars com o ID da zona
TF_VARS_FILE="terraform/terraform.tfvars"

# Verificar se o arquivo existe
if [ ! -f "$TF_VARS_FILE" ]; then
    echo "❌ Arquivo $TF_VARS_FILE não encontrado"
    exit 1
fi

# Atualizar o ID da zona no arquivo
sed -i "s/zone_id = \".*\"/zone_id = \"$ZONA_ID\"/" "$TF_VARS_FILE"
echo "✅ ID da zona atualizado no arquivo $TF_VARS_FILE"

echo ""
echo "📄 Detalhes da zona $ZONA_ID:"
aws route53 get-hosted-zone --id "$ZONA_ID"
