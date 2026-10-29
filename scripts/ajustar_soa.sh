#!/bin/bash

# ============================================================
# Reduz o cache negativo da zona.
#
# O tempo que um resolvedor guarda um NXDOMAIN e min(campo "minimum"
# do SOA, TTL do proprio SOA) -- RFC 2308. Com os valores padrao do
# Route 53 isso da 900 s: o aluno consulta o nome para ver se esta
# livre, registra, e continua recebendo "nao existe" por 15 minutos.
#
# O curinga da zona (modules/apigw_s3_proxy) ja elimina a resposta
# negativa para os nomes sob ela. Este script cobre o que sobra -- a
# consulta a propria zona, que o curinga nao alcanca -- e serve de
# defesa em profundidade.
#
# Idempotente: se o SOA ja estiver ajustado, nao faz nada.
#
# Uso: ./scripts/ajustar_soa.sh <zone_id> [ttl]
# ============================================================

set -u

ZONA="${1:-}"
TTL="${2:-60}"

if [ -z "$ZONA" ]; then
    echo "Uso: $0 <zone_id> [ttl]"
    exit 1
fi

NOME=$(aws route53 get-hosted-zone --id "$ZONA" \
    --query 'HostedZone.Name' --output text 2>/dev/null)

if [ -z "$NOME" ] || [ "$NOME" = "None" ]; then
    echo "Nao consegui ler a zona $ZONA."
    exit 1
fi

# Le o SOA atual em vez de montar um do zero: o primeiro campo e o
# nameserver sorteado pela AWS na criacao da zona, e inventa-lo
# quebraria a zona.
SOA_ATUAL=$(aws route53 list-resource-record-sets --hosted-zone-id "$ZONA" \
    --query "ResourceRecordSets[?Type=='SOA' && Name=='$NOME']|[0].ResourceRecords[0].Value" \
    --output text 2>/dev/null)

TTL_ATUAL=$(aws route53 list-resource-record-sets --hosted-zone-id "$ZONA" \
    --query "ResourceRecordSets[?Type=='SOA' && Name=='$NOME']|[0].TTL" \
    --output text 2>/dev/null)

if [ -z "$SOA_ATUAL" ] || [ "$SOA_ATUAL" = "None" ]; then
    echo "Nao encontrei o SOA de $NOME."
    exit 1
fi

# MNAME RNAME SERIAL REFRESH RETRY EXPIRE MINIMUM -- so o ultimo muda.
read -r MNAME RNAME SERIAL REFRESH RETRY EXPIRE MINIMUM <<< "$SOA_ATUAL"

if [ "$MINIMUM" = "$TTL" ] && [ "$TTL_ATUAL" = "$TTL" ]; then
    echo "✓ SOA de $NOME já está em ${TTL}s (cache negativo curto)"
    exit 0
fi

echo "Ajustando o SOA de $NOME"
echo "  antes : TTL=$TTL_ATUAL minimum=$MINIMUM  (cache negativo de $(( TTL_ATUAL < MINIMUM ? TTL_ATUAL : MINIMUM ))s)"
echo "  depois: TTL=$TTL minimum=$TTL"

LOTE=$(cat <<JSON
{"Changes":[{"Action":"UPSERT","ResourceRecordSet":{
  "Name":"$NOME","Type":"SOA","TTL":$TTL,
  "ResourceRecords":[{"Value":"$MNAME $RNAME $SERIAL $REFRESH $RETRY $EXPIRE $TTL"}]
}}]}
JSON
)

if aws route53 change-resource-record-sets --hosted-zone-id "$ZONA" \
    --change-batch "$LOTE" >/dev/null; then
    echo "✓ SOA ajustado"
else
    # Nao e motivo para abortar o deploy: o curinga ja faz o trabalho
    # principal, e isto aqui e a segunda camada.
    echo "✗ Nao consegui ajustar o SOA (o deploy segue mesmo assim)"
fi
