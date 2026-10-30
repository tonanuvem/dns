#!/bin/sh
#
# Cola entre o lego e a rota /acme desta API. Chamada pelo provider "exec":
#
#   $1 = present | cleanup
#   $2 = fqdn do desafio, com ponto final
#   $3 = valor do TXT
#
# RODA DENTRO DO CONTAINER DO LEGO, que e Alpine: so existe "sh", o "wget" do
# busybox, awk e sed. Sem bash, sem curl, sem python3 -- uma versao anterior
# deste tipo de script, do lado do labproxy, morria com "env: can't execute
# 'bash'", e o teste contra endpoint simulado nao pegava porque ali o script
# rodava no macOS. Por isso /bin/sh e wget, e nada mais.
#
# O Content-Type e OBRIGATORIO. Sem ele o API Gateway nao reconhece o corpo
# como texto, entrega em base64 e a API responde 400 "Corpo da requisicao nao
# e um JSON valido" -- reclamando de um JSON correto, o que manda depurar o
# lugar errado. Medido contra a API de verdade em 30/10. O busybox nao
# acrescenta o x-www-form-urlencoded dele quando --header ja define um.
#
# Nao valida a contagem de argumentos: o lego passa tres hoje, e ignorar
# extras e mais barato que quebrar numa atualizacao dele.
#
set -eu

ACAO="${1:?uso: $0 present|cleanup <fqdn> <valor>}"
FQDN="${2:?falta o fqdn}"
VALOR="${3:?falta o valor}"

: "${DNS_API_URL:?defina DNS_API_URL}"
: "${DNS_API_KEY:?defina DNS_API_KEY}"
: "${DNS_ADMIN_KEY:?defina DNS_ADMIN_KEY}"

case "$ACAO" in
    present|cleanup) ;;
    *) echo "acao desconhecida: $ACAO" >&2; exit 1 ;;
esac

# printf em vez de echo: o valor do desafio e base64url e pode comecar com
# "-", que o echo de alguns shells trataria como opcao.
CORPO=$(printf '{"fqdn":"%s","value":"%s"}' "$FQDN" "$VALOR")

# Saida nao-zero aborta o lego, que e o que queremos: um desafio que nao foi
# criado deve interromper a emissao, nao deixa-la expirar sozinha depois.
if ! RESPOSTA=$(wget -q -O - \
        --header "Content-Type: application/json" \
        --header "X-API-Key: $DNS_API_KEY" \
        --header "X-Admin-Key: $DNS_ADMIN_KEY" \
        --post-data "$CORPO" \
        "$DNS_API_URL/acme/$ACAO" 2>&1); then
    echo "acme_desafio: $ACAO falhou em $DNS_API_URL/acme/$ACAO" >&2
    echo "  $RESPOSTA" >&2
    exit 1
fi

echo "acme_desafio: $ACAO ok -- $RESPOSTA"
