#!/bin/bash

# ============================================================
# LIMPEZA DO AMBIENTE DO GERENCIADOR DNS
#
# O destruir.sh so remove o que esta no state do Terraform. Este script
# varre a CONTA e remove o que sobrou fora dele -- o caso que aparece
# toda vez que:
#
#   - um apply e interrompido no meio (recursos criados, state parcial);
#   - a VM e recriada e leva junto o terraform.tfstate local;
#   - o sufixo sorteado muda e deixa o bucket anterior para tras.
#
# Sem essa limpeza, o proximo apply falha com "already exists" na
# tabela do DynamoDB e nos CNAMEs de validacao do ACM -- exatamente o
# que aconteceu em 28/10/2026.
#
# NAO remove a zona hospedada: ela e criada a mao pelo instrutor e a
# delegacao na conta pai aponta para os nameservers dela.
#
# Uso:
#   ./scripts/limpar_ambiente.sh                      # lê a zona do tfvars
#   ./scripts/limpar_ambiente.sh aluno.lab.tonanuvem.com
#   ./scripts/limpar_ambiente.sh --sim                # sem confirmação
# ============================================================

set -u

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

msg()  { echo -e "${2}${1}${NC}"; }
item() { echo "     - $1"; }

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

ZONA=""
AUTO=0

for ARG in "$@"; do
    case "$ARG" in
        --sim|-s|--yes|-y) AUTO=1 ;;
        *) ZONA="$ARG" ;;
    esac
done

# ------------------------------------------------------------
# Zona e nome da turma
# ------------------------------------------------------------

if [ -z "$ZONA" ]; then
    TFVARS="$BASE_DIR/terraform/terraform.tfvars"

    if [ ! -f "$TFVARS" ]; then
        msg "Informe a zona ou rode o config.sh antes." "$RED"
        echo "   Uso: $0 <zona>"
        exit 1
    fi

    NOME_ALUNO=$(sed -n 's/^nome_aluno[[:space:]]*=[[:space:]]*"\(.*\)"/\1/p' "$TFVARS" | tail -1)
    NOME_DOMINIO=$(sed -n 's/^nome_dominio[[:space:]]*=[[:space:]]*"\(.*\)"/\1/p' "$TFVARS" | tail -1)

    if [ -z "$NOME_ALUNO" ] || [ -z "$NOME_DOMINIO" ]; then
        msg "Não foi possível ler a zona do terraform.tfvars." "$RED"
        exit 1
    fi

    ZONA="${NOME_ALUNO}.${NOME_DOMINIO}"
else
    NOME_ALUNO="${ZONA%%.*}"
fi

if ! aws sts get-caller-identity >/dev/null 2>&1; then
    msg "Credenciais da AWS ausentes ou expiradas." "$RED"
    echo "   Rode:  source ./credenciais_config.sh"
    exit 1
fi

CONTA=$(aws sts get-caller-identity --query Account --output text)

ZONE_ID=$(aws route53 list-hosted-zones \
    --query "HostedZones[?Name=='${ZONA}.'].Id | [0]" --output text 2>/dev/null)
ZONE_ID="${ZONE_ID##*/}"

echo ""
echo "============================================================"
echo " LIMPEZA DO AMBIENTE"
echo "============================================================"
echo ""
echo " Conta  : $CONTA"
echo " Zona   : $ZONA ${ZONE_ID:+($ZONE_ID)}"
echo " Turma  : $NOME_ALUNO"
echo ""

# ------------------------------------------------------------
# Inventario, antes de remover qualquer coisa
# ------------------------------------------------------------

msg "Levantando o que existe..." "$YELLOW"
echo ""

# Buckets wwwNN.<turma>.<dominio> -- inclui os de sorteios anteriores.
BUCKETS=$(aws s3api list-buckets \
    --query "Buckets[?ends_with(Name, '.${ZONA}')].Name" --output text 2>/dev/null | tr '\t' '\n' | grep -v '^$')

TABELA="registros-dns-${NOME_ALUNO}"
TEM_TABELA=""
aws dynamodb describe-table --table-name "$TABELA" >/dev/null 2>&1 && TEM_TABELA="$TABELA"

LAMBDA="gerenciador-dns-${NOME_ALUNO}"
TEM_LAMBDA=""
aws lambda get-function --function-name "$LAMBDA" >/dev/null 2>&1 && TEM_LAMBDA="$LAMBDA"

# API Gateway v2 (a API da Lambda) e v1 (o proxy do S3).
APIS_V2=$(aws apigatewayv2 get-apis \
    --query "Items[?Name=='api-gerenciador-dns'].ApiId" --output text 2>/dev/null | tr '\t' '\n' | grep -v '^$')
APIS_V1=$(aws apigateway get-rest-apis \
    --query "items[?name=='S3ProxyAPI'].id" --output text 2>/dev/null | tr '\t' '\n' | grep -v '^$')

# Dominios personalizados: api.<zona>, wwwNN.<zona>, httpsNN.<zona>.
#
# Os dois comandos abaixo devolvem os MESMOS objetos: no API Gateway o
# dominio personalizado e um recurso unico, compartilhado entre as APIs
# v1 e v2. Sem o sort -u, cada dominio aparecia duas vezes no
# inventario e o script tentava apagar o mesmo recurso duas vezes.
DOMINIOS=$( {
    aws apigatewayv2 get-domain-names \
        --query "Items[?ends_with(DomainName, '.${ZONA}')].DomainName" --output text 2>/dev/null
    aws apigateway get-domain-names \
        --query "items[?ends_with(domainName, '.${ZONA}')].domainName" --output text 2>/dev/null
} | tr '\t' '\n' | grep -v '^$' | sort -u)

CERTS=$(aws acm list-certificates \
    --query "CertificateSummaryList[?ends_with(DomainName, '.${ZONA}')].CertificateArn" --output text 2>/dev/null | tr '\t' '\n' | grep -v '^$')

# Registros da zona, menos o NS e o SOA do apex -- esses sao a propria
# zona e a delegacao; removê-los quebraria o ambiente.
REGISTROS=""
if [ -n "$ZONE_ID" ]; then
    REGISTROS=$(aws route53 list-resource-record-sets --hosted-zone-id "$ZONE_ID" \
        --query "ResourceRecordSets[?!(Name=='${ZONA}.' && (Type=='NS' || Type=='SOA'))].[Name,Type]" \
        --output text 2>/dev/null | grep -v '^$')
fi

echo "  Buckets S3:"
[ -n "$BUCKETS" ] && printf '%s\n' "$BUCKETS" | while read -r B; do item "$B"; done || item "(nenhum)"
echo "  DynamoDB:"
[ -n "$TEM_TABELA" ] && item "$TEM_TABELA" || item "(nenhuma)"
echo "  Lambda:"
[ -n "$TEM_LAMBDA" ] && item "$TEM_LAMBDA" || item "(nenhuma)"
echo "  API Gateway:"
[ -n "$APIS_V2$APIS_V1" ] && { printf '%s\n' $APIS_V2 $APIS_V1 | while read -r A; do item "$A"; done; } || item "(nenhuma)"
echo "  Domínios personalizados:"
[ -n "$DOMINIOS" ] && printf '%s\n' "$DOMINIOS" | while read -r D; do item "$D"; done || item "(nenhum)"
echo "  Certificados ACM:"
[ -n "$CERTS" ] && printf '%s\n' "$CERTS" | while read -r C; do item "${C##*/}"; done || item "(nenhum)"
echo "  Registros DNS (fora o NS/SOA do apex):"
[ -n "$REGISTROS" ] && printf '%s\n' "$REGISTROS" | while read -r N T; do item "$T $N"; done || item "(nenhum)"
echo ""

if [ -z "$BUCKETS$TEM_TABELA$TEM_LAMBDA$APIS_V2$APIS_V1$DOMINIOS$CERTS$REGISTROS" ]; then
    msg "Nada a remover. Ambiente já está limpo." "$GREEN"
    exit 0
fi

# ------------------------------------------------------------
# Confirmacao
# ------------------------------------------------------------

if [ "$AUTO" -ne 1 ]; then
    msg "Tudo acima será REMOVIDO. A zona hospedada é preservada." "$YELLOW"
    echo ""
    read -rp "Confirma? (digite LIMPAR): " RESP
    [ "$RESP" = "LIMPAR" ] || { echo "Cancelado."; exit 0; }
fi

echo ""
msg "Removendo..." "$YELLOW"
echo ""

# ------------------------------------------------------------
# Ordem: do dependente para o dependido.
#
# Tudo best-effort: a LabRole nega alguns deletes e a ordem entre
# recursos varia, entao cada passo ignora a falha e segue -- o
# importante e nao parar no primeiro erro e deixar o resto para tras.
# ------------------------------------------------------------

# 1. Registros DNS. Vao primeiro: enquanto um A-alias apontar para um
#    dominio do API Gateway, o delete do dominio e recusado.
if [ -n "$ZONE_ID" ] && [ -n "$REGISTROS" ]; then
    echo "  Registros DNS:"
    aws route53 list-resource-record-sets --hosted-zone-id "$ZONE_ID" \
        --query "ResourceRecordSets[?!(Name=='${ZONA}.' && (Type=='NS' || Type=='SOA'))]" \
        --output json 2>/dev/null |
    jq -c '.[]' 2>/dev/null |
    while read -r RR; do
        NOME=$(echo "$RR" | jq -r '.Name')
        TIPO=$(echo "$RR" | jq -r '.Type')
        LOTE=$(jq -n --argjson rr "$RR" '{Changes:[{Action:"DELETE",ResourceRecordSet:$rr}]}')
        if aws route53 change-resource-record-sets --hosted-zone-id "$ZONE_ID" \
            --change-batch "$LOTE" >/dev/null 2>&1; then
            item "$TIPO $NOME"
        else
            item "$TIPO $NOME (falhou)"
        fi
    done
fi

# 2. Dominios personalizados.
#
# Um dominio e um recurso unico, mas pode ter sido criado pela API v1
# ou pela v2, e cada uma so apaga o que conhece -- entao tentamos as
# duas e so reportamos falha se nenhuma funcionar.
if [ -n "$DOMINIOS" ]; then
    echo "  Domínios personalizados:"
    for D in $DOMINIOS; do
        if aws apigatewayv2 delete-domain-name --domain-name "$D" >/dev/null 2>&1 ||
           aws apigateway delete-domain-name --domain-name "$D" >/dev/null 2>&1; then
            item "$D"
        else
            item "$D (falhou — veja a mensagem abaixo)"
            aws apigateway delete-domain-name --domain-name "$D" 2>&1 | sed 's/^/       /' | head -3
        fi
    done
fi

# 3. APIs.
if [ -n "$APIS_V2$APIS_V1" ]; then
    echo "  APIs:"
    for A in $APIS_V2; do
        aws apigatewayv2 delete-api --api-id "$A" >/dev/null 2>&1 \
            && item "API v2 $A" || item "API v2 $A (falhou)"
    done
    for A in $APIS_V1; do
        aws apigateway delete-rest-api --rest-api-id "$A" >/dev/null 2>&1 \
            && item "API v1 $A" || item "API v1 $A (falhou)"
    done
fi

# 4. Certificados.
#
# Um certificado em uso nao pode ser apagado, e a AWS leva algum tempo
# para registrar que o dominio que o usava sumiu. Dai a pausa e a
# segunda tentativa: sem elas, a primeira execucao do script sempre
# deixava os certificados para tras.
if [ -n "$CERTS" ]; then
    echo "  Certificados ACM:"
    sleep 15
    for C in $CERTS; do
        if aws acm delete-certificate --certificate-arn "$C" >/dev/null 2>&1; then
            item "${C##*/}"
        else
            sleep 15
            if aws acm delete-certificate --certificate-arn "$C" >/dev/null 2>&1; then
                item "${C##*/}"
            else
                item "${C##*/} (ainda em uso; rode o script de novo em alguns minutos)"
            fi
        fi
    done
fi

# 5. Lambda e DynamoDB.
if [ -n "$TEM_LAMBDA$TEM_TABELA" ]; then
    echo "  Lambda e DynamoDB:"
    [ -n "$TEM_LAMBDA" ] && { aws lambda delete-function --function-name "$TEM_LAMBDA" >/dev/null 2>&1 \
        && item "lambda $TEM_LAMBDA" || item "lambda $TEM_LAMBDA (falhou)"; }
    [ -n "$TEM_TABELA" ] && { aws dynamodb delete-table --table-name "$TEM_TABELA" >/dev/null 2>&1 \
        && item "tabela $TEM_TABELA" || item "tabela $TEM_TABELA (falhou)"; }
fi

# 6. Buckets.
if [ -n "$BUCKETS" ]; then
    echo "  Buckets:"
    for B in $BUCKETS; do
        aws s3 rb "s3://$B" --force >/dev/null 2>&1 \
            && item "$B" || item "$B (falhou)"
    done
fi

# ------------------------------------------------------------
# Estado local
# ------------------------------------------------------------

echo ""
msg "Limpando arquivos locais do Terraform..." "$YELLOW"

rm -f "$BASE_DIR/terraform/terraform.tfstate" \
      "$BASE_DIR/terraform/terraform.tfstate.backup" \
      "$BASE_DIR/terraform/tfplan" \
      "$BASE_DIR/terraform/modules/lambda_api/lambda_function.zip"
rm -rf "$BASE_DIR/terraform/frontend_build" "$BASE_DIR/dns_admin/build"

echo ""
msg "Limpeza concluída." "$GREEN"
echo ""
echo "A zona $ZONA foi preservada. Para recriar o ambiente:"
echo ""
echo "    ./config.sh $NOME_ALUNO <senha>"
echo "    ./scripts/deploy.sh"
echo ""
