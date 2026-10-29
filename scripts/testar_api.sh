#!/bin/bash

# =======================================================
# Testa os endpoints da API de ponta a ponta.
#
# A versao anterior tinha a URL "https:/api.lab.aluno..." -- uma barra
# a menos e os rotulos trocados (a zona e <turma>.<dominio>), a chave
# fixa na string "SENHA" e o corpo com o campo "subdominio", que a API
# nunca aceitou (ela le "alias"). Nada disso chegava a funcionar.
#
# Agora os valores saem do state, que e a fonte da verdade do deploy.
# =======================================================

set -u

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$BASE_DIR/terraform" || exit 1

API_URL="${API_URL:-$(terraform output -raw api_url 2>/dev/null)}"
API_KEY="${API_KEY:-$(grep -E '^senha_compartilhada' terraform.tfvars 2>/dev/null | cut -d'"' -f2)}"

if [ -z "$API_URL" ] || [ -z "$API_KEY" ]; then
    echo "Nao consegui ler a URL ou a senha do Terraform."
    echo "Rode ./scripts/deploy.sh antes, ou exporte API_URL e API_KEY."
    exit 1
fi

# Um alias por execucao: a zona e compartilhada pela turma e um nome
# fixo colidiria com o registro de alguem.
ALIAS="teste-$(date +%s)"
IP="203.0.113.10"   # TEST-NET-3 (RFC 5737): nao e de ninguem.
# Com token, o registro nasce com dono -- e so o teste consegue apagar
# o que o teste criou.
TOKEN="teste-$(date +%s)-$RANDOM"

# O token de posse vai no header x-dns-token (o corpo tambem serve, mas
# o DELETE nao tem corpo). Passe "-t" como primeiro argumento para
# incluir o token na chamada.
chamar() {
    local cabecalhos=(-H "X-API-Key: $API_KEY")
    if [ "$1" = "-t" ]; then
        cabecalhos+=(-H "X-DNS-Token: $TOKEN")
        shift
    fi
    local metodo="$1" caminho="$2" corpo="${3:-}"
    echo ""
    echo "=> $metodo $caminho"
    if [ -n "$corpo" ]; then
        cabecalhos+=(-H "Content-Type: application/json" -d "$corpo")
    fi
    curl -s -w '\n[HTTP %{http_code}]\n' -X "$metodo" \
        "${cabecalhos[@]}" "$API_URL$caminho"
}

echo "========================================"
echo " API   : $API_URL"
echo " Alias : $ALIAS"
echo "========================================"

chamar GET /registros
chamar POST /registros "{\"alias\":\"$ALIAS\",\"endereco_ip\":\"$IP\",\"token\":\"$TOKEN\"}"
chamar -t PUT "/registros/$ALIAS" "{\"endereco_ip\":\"203.0.113.11\"}"
# Sem o token este DELETE devolve 403: e a prova de que a posse funciona.
chamar DELETE "/registros/$ALIAS"
chamar -t DELETE "/registros/$ALIAS"

echo ""
echo "========================================"
echo "Testes concluidos. O penultimo DELETE deve ter dado 403,"
echo "e o ultimo 200 -- e assim que a posse do registro aparece."
echo "========================================"
