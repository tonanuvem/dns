#!/bin/bash

# ============================================================
# DESTRUICAO DO AMBIENTE DO GERENCIADOR DNS
#
# Apaga o ambiente da TURMA INTEIRA: os registros de todos os alunos
# no Route 53, a tabela do DynamoDB, a API e o bucket do frontend.
# Por isso pergunta antes -- o limpar_ambiente.sh, no mesmo repo, ja
# fazia isso, e este script era o unico que nao fazia.
#
# Uso:
#   ./destruir.sh          # pergunta antes
#   ./destruir.sh --sim    # sem confirmacao (automacao)
# ============================================================

set -u

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Função para imprimir mensagens
print_message() {
    echo -e "${1}${2}${NC}"
}

# Função para verificar status
check_status() {
    if [ $? -eq 0 ]; then
        print_message "$GREEN" "✅ $1 concluído com sucesso!"
    else
        print_message "$RED" "❌ Erro ao $1"
        exit 1
    fi
}

# Obtém o diretório base do projeto
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 1. Verificar se estamos no diretório correto
print_message "$YELLOW" "\n1. Verificando diretório..."

if [ ! -f "$BASE_DIR/terraform/main.tf" ]; then
    print_message "$RED" "❌ Arquivo terraform/main.tf não encontrado."
    print_message "$YELLOW" "Execute o script do diretório raiz do projeto."
    exit 1
fi

# ============================================================
# 1b. CONFIRMACAO
#
# Antes de qualquer passo destrutivo, inclusive da remocao do zip:
# um script chamado "destruir" que nao pergunta nada e um acidente
# esperando a hora.
# ============================================================

SIM="nao"
[ "${1:-}" = "--sim" ] && SIM="sim"

if [ "$SIM" != "sim" ]; then
    ZONA_TFVARS=$(sed -n 's/^nome_aluno[[:space:]]*=[[:space:]]*"\(.*\)"/\1/p' \
        "$BASE_DIR/terraform/terraform.tfvars" 2>/dev/null | tail -1)

    print_message "$RED" "\nIsto apaga o ambiente da TURMA INTEIRA${ZONA_TFVARS:+ ($ZONA_TFVARS)}:"
    echo ""
    echo "  - os registros DNS de TODOS os alunos no Route 53"
    echo "  - a tabela do DynamoDB, com os tokens de posse"
    echo "  - a API, o API Gateway e os certificados"
    echo "  - o bucket S3 do frontend"
    echo ""
    print_message "$RED" "Ação IRREVERSÍVEL."
    echo ""
    read -rp "Para confirmar, digite DESTRUIR: " CONFIRMA
    if [ "$CONFIRMA" != "DESTRUIR" ]; then
        print_message "$YELLOW" "Cancelado."
        exit 0
    fi
fi

# ============================================================
# 1c. BACKEND REMOTO DO STATE
#
# O state saiu de terraform.tfstate local e foi para o S3, com backend
# PARCIAL (backend "s3" {} em main.tf): bucket, key e regiao chegam por
# -backend-config. O deploy.sh foi atualizado; este script nao, e sem
# init nenhum ele falhava exatamente quando mais importa -- em clone
# novo ou VM recriada, que e o cenario que o cabecalho do
# limpar_ambiente.sh lista como recorrente. O "terraform output"
# abaixo voltava vazio, o bucket do frontend era pulado em silencio
# pelo guard, e o destroy morria com "Backend initialization required".
#
# Aqui o bucket NAO e criado se faltar: sem state nao ha o que
# destruir, e criar um bucket vazio so esconderia o problema.
# ============================================================

print_message "$YELLOW" "\n1b. Inicializando o backend do Terraform..."

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null)

if [ -z "$ACCOUNT_ID" ]; then
    print_message "$RED" "❌ Não foi possível obter o account id. Verifique as credenciais da AWS."
    exit 1
fi

AWS_REGION="${AWS_REGION:-us-east-1}"
BUCKET_STATE="tfstate-dns-${ACCOUNT_ID}"

if ! aws s3api head-bucket --bucket "$BUCKET_STATE" >/dev/null 2>&1; then
    print_message "$RED" "❌ Bucket de state não encontrado: $BUCKET_STATE"
    echo ""
    echo "Sem o state não há o que destruir por aqui. Se sobraram recursos"
    echo "soltos na conta, use:"
    echo ""
    echo "   ./scripts/limpar_ambiente.sh"
    echo ""
    exit 1
fi

cd "$BASE_DIR/terraform" || exit 1

terraform init -reconfigure -input=false \
    -backend-config="bucket=$BUCKET_STATE" \
    -backend-config="key=dns/terraform.tfstate" \
    -backend-config="region=$AWS_REGION" \
    -backend-config="use_lockfile=true" \
    -backend-config="encrypt=true"
check_status "Inicialização do backend"

cd "$BASE_DIR" || exit 1

# 2. Limpar arquivos temporários
print_message "$YELLOW" "\n2. Limpando arquivos temporários..."

# Remover arquivo ZIP do Lambda
if [ -f "$BASE_DIR/terraform/modules/lambda_api/lambda_function.zip" ]; then
    rm "$BASE_DIR/terraform/modules/lambda_api/lambda_function.zip"
    check_status "Remoção do arquivo ZIP do Lambda"
fi

# 3. Remover o bucket S3 do frontend
#
# O bucket e criado pelo AWS CLI, fora do Terraform (ver o cabecalho de
# modules/frontend/main.tf: a SCP do AWS Academy inviabiliza o recurso
# aws_s3_bucket). Entao o destroy nao o remove -- e preciso fazer aqui,
# antes, enquanto o output ainda existe.
cd "$BASE_DIR/terraform"
BUCKET_NAME=$(terraform output -raw frontend_bucket_name 2>/dev/null)
cd "$BASE_DIR"

if [ -n "$BUCKET_NAME" ] && aws s3api head-bucket --bucket "$BUCKET_NAME" 2>/dev/null; then
  print_message "$YELLOW" "Removendo bucket S3: $BUCKET_NAME"
  aws s3 rb "s3://$BUCKET_NAME" --force
  check_status "Remoção do bucket $BUCKET_NAME"
fi

# 4. Executar terraform destroy
print_message "$YELLOW" "\n4. Executando terraform destroy..."

# Navegar para o diretório terraform
cd "$BASE_DIR/terraform"

# Executar terraform destroy
print_message "$YELLOW" "Executando terraform destroy..."
terraform destroy -auto-approve
check_status "Terraform destroy"

# 5. Limpar arquivos do Terraform
print_message "$YELLOW" "\n5. Limpando arquivos do Terraform..."

# Cache local do backend e dos providers. O terraform.tfstate e o
# .backup nao entram mais nesta lista: o state vive no S3, e as linhas
# que os apagavam eram restos de quando ele era local -- apagar
# arquivo que nao existe mascarava o fato de o script nao ter sido
# revisitado na migracao.
rm -f .terraform.lock.hcl
rm -rf .terraform
check_status "Limpeza dos arquivos do Terraform"

print_message "$GREEN" "\n✅ Processo de destruição concluído com sucesso!" 