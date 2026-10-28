#!/bin/bash

# ============================================================
# BUCKET DO FRONTEND, VIA AWS CLI
#
# Por que nao e um aws_s3_bucket do Terraform:
#
# A SCP da organizacao do AWS Academy nega
# s3:GetBucketObjectLockConfiguration. Depois de criar um bucket, o
# provider le as configuracoes de volta, e uma delas e a de object
# lock; no codigo do provider (resourceBucketRead) esse erro so e
# tolerado para MethodNotAllowed, NotImplemented e XNotImplemented --
# qualquer outro, na particao "aws", e fatal. Entao todo apply morria
# em:
#
#   Error: reading S3 Bucket (wwwNN...) object lock configuration:
#   ... AccessDenied ... explicit deny in a service control policy
#
# Um deny de SCP nao pode ser contornado de dentro da conta, e o
# provider nao tem flag para pular a leitura. O CLI, por outro lado,
# nunca faz essa chamada: ele so escreve o que pedimos.
#
# O endpoint de website e deterministico
# (<bucket>.s3-website-<regiao>.amazonaws.com), entao o Terraform
# continua montando o CNAME e a integracao do proxy sem precisar ler
# nada do S3.
#
# Idempotente: pode rodar quantas vezes for, em bucket novo ou ja
# existente.
#
# Uso: criar_bucket_frontend.sh <nome_do_bucket> [regiao]
# ============================================================

set -u

BUCKET="${1:-}"
REGIAO="${2:-us-east-1}"

if [ -z "$BUCKET" ]; then
    echo "Uso: $0 <nome_do_bucket> [regiao]"
    exit 1
fi

echo ">> Bucket do frontend: $BUCKET ($REGIAO)"

# ------------------------------------------------------------
# 1. Criar (se ainda nao existe)
# ------------------------------------------------------------

if aws s3api head-bucket --bucket "$BUCKET" >/dev/null 2>&1; then
    echo "   Bucket já existe."
else
    echo "   Criando bucket..."

    if [ "$REGIAO" = "us-east-1" ]; then
        aws s3api create-bucket --bucket "$BUCKET" --region "$REGIAO" >/dev/null
    else
        aws s3api create-bucket --bucket "$BUCKET" --region "$REGIAO" \
            --create-bucket-configuration LocationConstraint="$REGIAO" >/dev/null
    fi

    if [ $? -ne 0 ]; then
        echo "   ❌ Não foi possível criar o bucket $BUCKET."
        echo ""
        echo "   Nome de bucket é global na AWS. Se o erro for"
        echo "   BucketAlreadyExists, rode o deploy de novo: o sufixo"
        echo "   numérico é sorteado e vai mudar."
        exit 1
    fi

    # O create-bucket retorna antes de o bucket estar consistente para
    # as chamadas seguintes.
    aws s3api wait bucket-exists --bucket "$BUCKET" 2>/dev/null
fi

# ------------------------------------------------------------
# 2. Liberar acesso publico
#
# Site estatico de laboratorio: o conteudo e publico por definicao.
# A ordem importa -- enquanto o public access block estiver ativo, a
# policy publica do passo 4 e recusada.
# ------------------------------------------------------------

echo "   Liberando acesso público..."

aws s3api put-public-access-block --bucket "$BUCKET" \
    --public-access-block-configuration \
    "BlockPublicAcls=false,IgnorePublicAcls=false,BlockPublicPolicy=false,RestrictPublicBuckets=false" \
    >/dev/null || {
    echo "   ❌ Falha ao ajustar o public access block."
    exit 1
}

# A propagacao nao e imediata: sem esta pausa a policy abaixo volta
# AccessDenied de vez em quando. Era o que o time_sleep de 15s fazia
# no modulo Terraform.
sleep 10

# ------------------------------------------------------------
# 3. Configurar como website
# ------------------------------------------------------------

echo "   Configurando website..."

# error_document aponta para o index: o React-Admin faz roteamento no
# cliente, entao qualquer caminho precisa devolver o index.html.
aws s3api put-bucket-website --bucket "$BUCKET" \
    --website-configuration '{
        "IndexDocument": {"Suffix": "index.html"},
        "ErrorDocument": {"Key": "index.html"}
    }' >/dev/null || {
    echo "   ❌ Falha ao configurar o website."
    exit 1
}

# ------------------------------------------------------------
# 4. Policy de leitura publica
# ------------------------------------------------------------

echo "   Aplicando policy de leitura pública..."

aws s3api put-bucket-policy --bucket "$BUCKET" --policy "{
    \"Version\": \"2012-10-17\",
    \"Statement\": [{
        \"Sid\": \"LeituraPublicaDoSite\",
        \"Effect\": \"Allow\",
        \"Principal\": \"*\",
        \"Action\": \"s3:GetObject\",
        \"Resource\": \"arn:aws:s3:::${BUCKET}/*\"
    }]
}" >/dev/null || {
    echo "   ❌ Falha ao aplicar a policy pública."
    exit 1
}

echo "   ✅ Bucket pronto: http://${BUCKET}.s3-website-${REGIAO}.amazonaws.com"
