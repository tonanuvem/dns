#!/bin/bash

# ============================================================
# DELEGACAO DA ZONA DA TURMA
#
# A zona pai (ex.: lab.tonanuvem.com) vive numa conta permanente; a
# zona da turma e criada na conta do AWS Academy, que e recriada a cada
# reset -- e com ela vem um conjunto NOVO de nameservers. Enquanto a
# delegacao na zona pai apontar para os NS antigos, nada resolve, e o
# sintoma (site e API inacessiveis, certificado ACM parado em pending)
# nao diz que o problema e a delegacao.
#
# Este script imprime os NS atuais prontos para colar no registro NS da
# zona pai.
#
# Uso:
#   ./scripts/mostrar_delegacao.sh                 # le a zona do tfvars
#   ./scripts/mostrar_delegacao.sh aluno.lab.tonanuvem.com
# ============================================================

set -u

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

ZONA="${1:-}"

# Sem argumento, reaproveita o que o config.sh ja gravou.
if [ -z "$ZONA" ]; then
    TFVARS="$BASE_DIR/terraform/terraform.tfvars"

    if [ ! -f "$TFVARS" ]; then
        echo "❌ Informe a zona ou rode o config.sh antes."
        echo "   Uso: $0 <zona>"
        exit 1
    fi

    NOME_ALUNO=$(sed -n 's/^nome_aluno[[:space:]]*=[[:space:]]*"\(.*\)"/\1/p' "$TFVARS" | tail -1)
    NOME_DOMINIO=$(sed -n 's/^nome_dominio[[:space:]]*=[[:space:]]*"\(.*\)"/\1/p' "$TFVARS" | tail -1)

    if [ -z "$NOME_ALUNO" ] || [ -z "$NOME_DOMINIO" ]; then
        echo "❌ Não foi possível ler a zona do terraform.tfvars."
        echo "   Uso: $0 <zona>"
        exit 1
    fi

    ZONA="${NOME_ALUNO}.${NOME_DOMINIO}"
fi

# O Route 53 guarda o nome com ponto final.
ZONA_COM_PONTO="${ZONA%.}."

ZONE_ID=$(aws route53 list-hosted-zones \
    --query "HostedZones[?Name=='${ZONA_COM_PONTO}'].Id | [0]" \
    --output text 2>/dev/null)

if [ -z "$ZONE_ID" ] || [ "$ZONE_ID" = "None" ]; then
    echo "❌ Zona '$ZONA' não encontrada nesta conta."
    echo ""
    echo "   Crie a zona hospedada no Route 53 e rode este script de novo."
    exit 1
fi

# O list-hosted-zones devolve "/hostedzone/ZXXXX".
ZONE_ID="${ZONE_ID##*/}"

NS=$(aws route53 get-hosted-zone --id "$ZONE_ID" \
    --query 'DelegationSet.NameServers[]' --output text 2>/dev/null | tr '\t' '\n')

if [ -z "$NS" ]; then
    echo "❌ Não foi possível ler os nameservers da zona $ZONA."
    exit 1
fi

DOMINIO_PAI="${ZONA#*.}"

echo ""
echo "============================================================"
echo " DELEGAÇÃO DA ZONA $ZONA"
echo "============================================================"
echo ""
echo "Zona hospedada : $ZONE_ID"
echo "Zona pai       : $DOMINIO_PAI"
echo ""
echo "Na conta que hospeda '$DOMINIO_PAI', crie ou edite o registro NS"
echo "de '$ZONA' com EXATAMENTE estes valores:"
echo ""
printf '%s\n' "$NS" | sed 's/^/    /'
echo ""
echo "Conferir a propagação (pode levar alguns minutos):"
echo ""
echo "    dig +short NS $ZONA @8.8.8.8"
echo ""
