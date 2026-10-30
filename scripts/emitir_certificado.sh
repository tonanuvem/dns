#!/usr/bin/env bash
#
# Emite o certificado curinga da turma e o guarda na API, de onde a VM de
# cada aluno o busca. Roda do lado do INSTRUTOR.
#
#   ./scripts/emitir_certificado.sh              # staging (nao gasta cota)
#   ./scripts/emitir_certificado.sh --producao   # certificado de verdade
#   ./scripts/emitir_certificado.sh --auto       # so emite se precisar
#   ./scripts/emitir_certificado.sh --forcar --producao
#
# POR QUE AQUI, E NAO NO LABPROXY
#
# A zona, o state e a tabela do certificado vivem neste projeto; o labproxy
# apenas CONSOME o certificado. Emissao aqui e consumo la e a divisao que
# evita um repositorio precisar de credencial do outro. Este script nasceu
# do emitir-cert.sh do labproxy e herda o que foi aprendido la -- o --user
# do Docker, o env-file, o EXEC_MODE fora do ambiente -- com duas adicoes:
# a guarda de cota e o PUT no fim.
#
# A GUARDA, QUE E O MOTIVO DE ISTO PODER RODAR NO DEPLOY
#
# A Let's Encrypt limita 5 certificados por conjunto identico de nomes a
# cada 7 dias, sem excecao. O deploy.sh e rodado sem cerimonia -- varias
# vezes por tarde durante desenvolvimento -- e sem guarda a turma queimaria
# a cota da semana e ficaria DIAS sem conseguir emitir. Com --auto, so emite
# se nao houver certificado ou se faltarem menos de $DIAS_MINIMOS dias.
#
# A validade e lida direto do DynamoDB, e nao pela API: o GET /certificado
# exige o token de posse de um aluno, que o instrutor nao tem, e seria
# estranho baixar a chave privada inteira so para ler uma data.
#
set -euo pipefail

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

PRODUCAO=0
FORCAR=0
AUTO=0
DIAS_MINIMOS="${DNS_CERT_DIAS:-30}"

while [ $# -gt 0 ]; do
    case "$1" in
        --producao) PRODUCAO=1 ;;
        --forcar)   FORCAR=1 ;;
        --auto)     AUTO=1 ;;
        --dias)     shift; DIAS_MINIMOS="${1:?--dias precisa de um numero}" ;;
        *) echo "argumento desconhecido: $1" >&2; exit 1 ;;
    esac
    shift
done

N=$'\033[1m'; F=$'\033[0m'; V=$'\033[32m'; A=$'\033[33m'; R=$'\033[31m'
ok()    { printf '  %s✓%s %s\n' "$V" "$F" "$*"; }
aviso() { printf '  %s!%s %s\n' "$A" "$F" "$*"; }
erro()  { printf '  %s✗%s %s\n' "$R" "$F" "$*" >&2; exit 1; }
# Em --auto, desistir nao e falha: o deploy segue.
desistir() { aviso "$*"; exit "$([ "$AUTO" = 1 ] && echo 0 || echo 1)"; }

# ------------------------------------------------------------
# De onde vem a configuracao: o tfvars, como no limpar_ambiente.sh
# ------------------------------------------------------------

TFVARS="$BASE_DIR/terraform/terraform.tfvars"
[ -f "$TFVARS" ] || erro "nao achei $TFVARS. Rode o config.sh primeiro."

ler_tfvar() {
    sed -n "s/^$1[[:space:]]*=[[:space:]]*\"\(.*\)\"/\1/p" "$TFVARS" | tail -1
}

TURMA=$(ler_tfvar nome_aluno)
DOMINIO=$(ler_tfvar nome_dominio)
[ -n "$TURMA" ] && [ -n "$DOMINIO" ] \
    || erro "nome_aluno ou nome_dominio ausentes em $TFVARS"

ZONA="${TURMA}.${DOMINIO}"
NOME="*.${ZONA}"
API_URL="${DNS_API_URL:-https://api.${ZONA}}"
API_KEY=$(ler_tfvar senha_compartilhada)
TABELA="certificado-turma-${TURMA}"
EMAIL="${ACME_EMAIL:-instrutor@tonanuvem.com}"
LEGO_IMG="${LEGO_IMG:-goacme/lego:v5.6.0}"
SAIDA="${SAIDA:-$BASE_DIR/cert-${TURMA}}"

echo ""
echo "============================================"
echo " CERTIFICADO DA TURMA"
echo "============================================"
echo ""
echo "  Zona  : $ZONA"
echo "  Nome  : $NOME"
echo "  API   : $API_URL"
echo ""

# ------------------------------------------------------------
# A senha de instrutor: do state, nunca de argumento
# ------------------------------------------------------------

ADMIN_KEY="${DNS_ADMIN_KEY:-}"
if [ -z "$ADMIN_KEY" ]; then
    ADMIN_KEY=$(cd "$BASE_DIR/terraform" && terraform output -raw senha_admin 2>/dev/null) || true
fi
[ -n "$ADMIN_KEY" ] \
    || desistir "nao li a senha de instrutor (terraform output -raw senha_admin).
       Rode o deploy.sh antes, ou exporte DNS_ADMIN_KEY."

# ------------------------------------------------------------
# A GUARDA
# ------------------------------------------------------------

# Imprime "<dias> <ambiente>", ou uma palavra de diagnostico no lugar dos
# dias. O ambiente sai vazio quando o certificado guardado e anterior a
# este campo existir.
estado_guardado() {
    local item
    item=$(aws dynamodb get-item --table-name "$TABELA" \
        --key '{"turma":{"S":"atual"}}' \
        --projection-expression 'expira_em,ambiente' \
        --output json 2>/dev/null) || { echo "sem-tabela"; return; }

    printf '%s' "$item" | python3 -I -c '
import json, sys
from datetime import datetime, timezone
try:
    d = json.load(sys.stdin)
except Exception:
    print("sem-item"); raise SystemExit
item = d.get("Item") or {}
ambiente = (item.get("ambiente") or {}).get("S", "")
bruto = (item.get("expira_em") or {}).get("S", "")
if not bruto:
    print("sem-validade" if item else "sem-item", ambiente); raise SystemExit
try:
    alvo = datetime.fromisoformat(bruto.replace("Z", "+00:00"))
except ValueError:
    print("validade-ilegivel", ambiente); raise SystemExit
if alvo.tzinfo is None:
    alvo = alvo.replace(tzinfo=timezone.utc)
print(int((alvo - datetime.now(timezone.utc)).total_seconds() // 86400), ambiente)
'
}

if [ "$FORCAR" = "0" ]; then
    read -r DIAS AMBIENTE <<< "$(estado_guardado)"
    AMBIENTE="${AMBIENTE:-}"

    case "$DIAS" in
        sem-tabela)
            desistir "tabela $TABELA nao existe. Rode o deploy.sh para cria-la." ;;
        sem-item)
            ok "nenhum certificado guardado ainda: vou emitir" ;;
        sem-validade|validade-ilegivel)
            desistir "ha certificado guardado, mas sem validade legivel ($DIAS).
       Nao vou emitir as cegas e gastar cota. Use --forcar se for o caso." ;;
        *)
            # Um certificado de STAGING tem os mesmos 90 dias de validade
            # que o de verdade, entao olhar so a data nunca trocaria um
            # pelo outro -- e a turma rodaria dois meses com o navegador
            # recusando, exibindo o mesmo cadeado quebrado do
            # autoassinado. Sintoma que nao muda e sintoma que ninguem
            # investiga. Por isso pedir producao sobre algo que nao e
            # producao emite, independente da data.
            if [ "$PRODUCAO" = "1" ] && [ "$AMBIENTE" != "producao" ]; then
                aviso "guardado e ${AMBIENTE:-de ambiente desconhecido} e vence em $DIAS dias:"
                aviso "vou emitir em producao para substitui-lo"
            elif [ "$DIAS" -gt "$DIAS_MINIMOS" ]; then
                ok "certificado guardado (${AMBIENTE:-ambiente desconhecido}) vence em $DIAS dias (minimo $DIAS_MINIMOS): nada a fazer"
                echo ""
                exit 0
            else
                aviso "certificado guardado vence em $DIAS dias: vou renovar"
            fi ;;
    esac
fi

# ------------------------------------------------------------
# Emissao
# ------------------------------------------------------------

command -v docker >/dev/null || desistir "docker nao encontrado; nao da para rodar o lego."

if [ "$PRODUCAO" = "1" ]; then
    SERVIDOR="https://acme-v02.api.letsencrypt.org/directory"
    AMBIENTE_NOVO="producao"
    aviso "emitindo de ${N}VERDADE${F}: 5 por conjunto identico de nomes a cada 7 dias."
else
    SERVIDOR="https://acme-staging-v02.api.letsencrypt.org/directory"
    AMBIENTE_NOVO="staging"
    ok "usando o ${N}staging${F} (nao confiavel no navegador; valida o fluxo)"
fi

# Sobra de uma execucao em que o lego rodou como root: os arquivos ficam com
# dono root no bind mount e nem da para ler o certificado emitido.
if [ -e "$SAIDA" ] && [ ! -w "$SAIDA" ]; then
    erro "o diretorio $SAIDA existe e nao e seu.
       Apague com: sudo rm -rf $SAIDA"
fi
mkdir -p "$SAIDA"

# As credenciais num env-file temporario, nao na linha de comando.
ENVFILE=$(mktemp)
trap 'rm -f "$ENVFILE"' EXIT
chmod 600 "$ENVFILE"

# EXEC_MODE fica FORA do ambiente de proposito: a comparacao do lego e exata
# contra "RAW", e no modo padrao o script recebe o fqdn e o valor ja prontos.
{
    printf 'EXEC_PATH=/data/acme_desafio.sh\n'
    printf 'DNS_API_URL=%s\n'   "$API_URL"
    printf 'DNS_API_KEY=%s\n'   "$API_KEY"
    printf 'DNS_ADMIN_KEY=%s\n' "$ADMIN_KEY"
} > "$ENVFILE"

cp "$BASE_DIR/scripts/acme_desafio.sh" "$SAIDA/acme_desafio.sh"
chmod +x "$SAIDA/acme_desafio.sh"

echo ""
echo "  Pedindo ${N}${NOME}${F} pelo desafio DNS-01, via $API_URL/acme"
echo ""

# --user importa: sem ele o lego roda como root e os arquivos saem com dono
# root no bind mount. No Docker Desktop do macOS nao aparece, porque ele
# mapeia o dono; no Linux e no CloudShell aparece.
docker run --rm -i \
    --user "$(id -u):$(id -g)" \
    -v "$SAIDA:/data" -e LEGO_PATH=/data \
    --env-file "$ENVFILE" \
    "$LEGO_IMG" run \
        --server "$SERVIDOR" \
        --accept-tos --email "$EMAIL" \
        --dns exec \
        --dns.propagation.wait 30s \
        --key-type rsa2048 \
        -d "$NOME" \
    || erro "o lego falhou. Veja a mensagem acima."

CERT=$(find "$SAIDA/certificates" -name '*.crt' ! -name '*issuer*' 2>/dev/null | head -1)
CHAVE=$(find "$SAIDA/certificates" -name '*.key' 2>/dev/null | head -1)

[ -n "$CERT" ] && [ -f "$CERT" ] && [ -n "$CHAVE" ] && [ -f "$CHAVE" ] \
    || erro "o lego emitiu, mas nao consegui ler $SAIDA/certificates.
       Se a mensagem acima foi 'Permission denied', sobraram arquivos com dono
       root: sudo rm -rf $SAIDA e rode de novo."

chmod 600 "$CHAVE"

echo ""
ok "emitido: $(basename "$CERT")"
openssl x509 -in "$CERT" -noout -ext subjectAltName | sed 's/^/     /'
VALIDADE=$(openssl x509 -in "$CERT" -noout -enddate | cut -d= -f2)
ok "valido ate: $VALIDADE"

# ------------------------------------------------------------
# PUT na API
# ------------------------------------------------------------

ISO=$(date -u -d "$VALIDADE" +%Y-%m-%dT%H:%M:%S 2>/dev/null) || ISO=""
if [ -z "$ISO" ]; then
    # macOS, ou date sem -d: converte com python.
    ISO=$(VAL="$VALIDADE" python3 -I -c '
import os
from datetime import datetime, timezone
try:
    d = datetime.strptime(os.environ["VAL"], "%b %d %H:%M:%S %Y %Z")
    print(d.replace(tzinfo=timezone.utc).isoformat())
except Exception:
    print("")
')
fi

# O corpo e montado por python, e nao por interpolacao de shell: o PEM tem
# quebras de linha, que precisam ir escapadas no JSON.
CORPO=$(CERT="$CERT" CHAVE="$CHAVE" ISO="$ISO" AMB="$AMBIENTE_NOVO" python3 -I -c '
import json, os
corpo = {
    "cert": open(os.environ["CERT"]).read(),
    "key":  open(os.environ["CHAVE"]).read(),
    "ambiente": os.environ["AMB"],
}
if os.environ.get("ISO"):
    corpo["expira_em"] = os.environ["ISO"]
print(json.dumps(corpo))
')

echo ""
echo "  Guardando na API..."

# O Content-Type e obrigatorio: sem ele o API Gateway entrega o corpo em
# base64 e a API responde 400 reclamando de um JSON correto.
RESPOSTA=$(printf '%s' "$CORPO" | curl -s --max-time 60 -X PUT "$API_URL/certificado" \
    -H "X-API-Key: $API_KEY" \
    -H "X-Admin-Key: $ADMIN_KEY" \
    -H "Content-Type: application/json" \
    --data-binary @- \
    -w '\n%{http_code}')

STATUS=$(printf '%s' "$RESPOSTA" | tail -1)
CORPO_RESP=$(printf '%s' "$RESPOSTA" | sed '$d')

if [ "$STATUS" != "200" ]; then
    erro "o PUT falhou com HTTP $STATUS: $CORPO_RESP"
fi

ok "guardado: $CORPO_RESP"

# A API devolve o ambiente que gravou. Se nao vier o que mandamos, a Lambda
# implantada e anterior a esse campo e o descartou em SILENCIO -- e ai a
# guarda veria "ambiente desconhecido" na proxima execucao e emitiria de
# novo, e de novo, queimando a cota de 5 por semana que ela existe para
# proteger. Falha barulhenta aqui vale mais que um laco silencioso depois.
AMBIENTE_GRAVADO=$(printf '%s' "$CORPO_RESP" | python3 -I -c '
import json, sys
try:
    print(json.load(sys.stdin).get("ambiente", ""))
except Exception:
    print("")
')

if [ "$AMBIENTE_GRAVADO" != "$AMBIENTE_NOVO" ]; then
    echo ""
    aviso "${N}a API nao guardou o ambiente${F} (mandei '$AMBIENTE_NOVO', devolveu '${AMBIENTE_GRAVADO:-vazio}')."
    aviso "A Lambda implantada e anterior a esse campo. O certificado FOI guardado,"
    aviso "mas a guarda de cota vai achar que o ambiente e desconhecido e emitir de"
    aviso "novo na proxima execucao -- em producao isso queima a cota da semana."
    echo ""
    aviso "Publique a Lambda e emita de novo, nesta ordem:"
    aviso "    git pull && ./scripts/deploy.sh"
    echo ""
fi

echo ""
echo "  As VMs pegam sozinhas na proxima execucao do proxy.sh do labproxy."
echo "  A chave privada ficou em $CHAVE (modo 600) -- nao precisa copia-la"
echo "  para VM nenhuma."
echo ""
