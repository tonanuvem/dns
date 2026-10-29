#!/bin/bash

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Função para imprimir mensagens
print_message() {
    echo -e "${2}${1}${NC}"
}

# Função para verificar status do comando
check_status() {
    if [ $? -eq 0 ]; then
        print_message "✓ $1" "$GREEN"
    else
        print_message "✗ $2" "$RED"
        exit 1
    fi
}

# Obter o diretório base do projeto
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Verificar se o AWS CLI está instalado
if ! command -v aws &> /dev/null; then
    print_message "AWS CLI não está instalado. Por favor, instale-o primeiro." "$RED"
    exit 1
fi

# Verificar se as credenciais AWS estão configuradas
#print_message "Verificando credenciais AWS..." "$YELLOW"
#if ! aws sts get-caller-identity &> /dev/null; then
#    print_message "Credenciais AWS não configuradas ou inválidas." "$RED"
#    print_message "Por favor, configure suas credenciais AWS:" "$YELLOW"
#    aws configure
#    check_status "Credenciais AWS configuradas com sucesso" "Erro ao configurar credenciais AWS"
#fi

# Verificar se as variáveis de ambiente AWS estão configuradas
#if [ -z "$AWS_ACCESS_KEY_ID" ] || [ -z "$AWS_SECRET_ACCESS_KEY" ] || [ -z "$AWS_DEFAULT_REGION" ]; then
#    print_message "Configurando variáveis de ambiente AWS..." "$YELLOW"
#    export AWS_ACCESS_KEY_ID=$(aws configure get aws_access_key_id)
#    export AWS_SECRET_ACCESS_KEY=$(aws configure get aws_secret_access_key)
#    export AWS_DEFAULT_REGION=$(aws configure get region)
#    check_status "Variáveis de ambiente AWS configuradas com sucesso" "Erro ao configurar variáveis de ambiente AWS"
#fi

# Verificar se estamos no diretório correto
if [ ! -f "$BASE_DIR/terraform/main.tf" ]; then
    print_message "Erro: Arquivo main.tf não encontrado. Execute este script do diretório raiz do projeto." "$RED"
    exit 1
fi

# Verificar se o arquivo ZIP da função Lambda existe
# if [ ! -f "$BASE_DIR/lambda_zip/gerenciador_dns.zip" ]; then
#     print_message "Erro: Arquivo ZIP da função Lambda não encontrado. Execute ./scripts/create_backend.sh primeiro." "$RED"
#     exit 1
# fi

# # Verificar se o build do frontend existe
# if [ ! -d "$BASE_DIR/frontend/build" ]; then
#     print_message "Erro: Build do frontend não encontrado. Execute ./scripts/create_frontend.sh primeiro." "$RED"
#     exit 1
# fi

# Navegar para o diretório terraform
cd "$BASE_DIR/terraform"

# ============================================================
# BACKEND REMOTO DO STATE
#
# O state ficava em terraform.tfstate, local. Numa VM de lab isso e
# fragil: perdida a VM, perde-se o unico registro do que existe na
# conta, e os recursos ficam orfaos sem destroy possivel.
#
# O bucket segue o padrao do repositorio config (derivado do account
# id) e tem versionamento, que e o que permite voltar um state
# corrompido no meio de uma aula.
# ============================================================

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null)

if [ -z "$ACCOUNT_ID" ]; then
    print_message "Não foi possível obter o account id. Verifique as credenciais da AWS." "$RED"
    exit 1
fi

AWS_REGION="${AWS_REGION:-us-east-1}"
BUCKET_STATE="tfstate-dns-${ACCOUNT_ID}"

print_message "Verificando bucket de state: $BUCKET_STATE" "$YELLOW"

if aws s3api head-bucket --bucket "$BUCKET_STATE" >/dev/null 2>&1; then
    print_message "✓ Bucket de state já existe" "$GREEN"
else
    print_message "Criando bucket de state..." "$YELLOW"

    if [ "$AWS_REGION" = "us-east-1" ]; then
        aws s3api create-bucket --bucket "$BUCKET_STATE" --region "$AWS_REGION"
    else
        aws s3api create-bucket --bucket "$BUCKET_STATE" --region "$AWS_REGION" \
            --create-bucket-configuration LocationConstraint="$AWS_REGION"
    fi
    check_status "Bucket de state criado" "Erro ao criar o bucket de state"

    aws s3api put-bucket-versioning --bucket "$BUCKET_STATE" \
        --versioning-configuration Status=Enabled
    check_status "Versionamento habilitado" "Erro ao habilitar versionamento"
fi

# Um state local de um deploy anterior faria o init pedir migracao e
# abortar com -input=false. Avisa em vez de decidir sozinho.
if [ -s terraform.tfstate ] && \
   [ "$(jq -r '.resources | length' terraform.tfstate 2>/dev/null || echo 0)" -gt 0 ]; then
    print_message "Existe um state LOCAL com recursos em terraform.tfstate." "$YELLOW"
    print_message "Rode 'terraform destroy' com o código anterior, ou migre o state" "$YELLOW"
    print_message "manualmente, antes de seguir com o backend remoto." "$YELLOW"
    exit 1
fi

# Inicializar o Terraform
print_message "Inicializando Terraform..." "$YELLOW"
terraform init -reconfigure -input=false \
    -backend-config="bucket=$BUCKET_STATE" \
    -backend-config="key=dns/terraform.tfstate" \
    -backend-config="region=$AWS_REGION" \
    -backend-config="use_lockfile=true" \
    -backend-config="encrypt=true"
check_status "Terraform inicializado com sucesso" "Erro ao inicializar Terraform"

# Criar arquivo de plano
print_message "Criando plano de execução..." "$YELLOW"
terraform plan -out=tfplan
check_status "Plano criado com sucesso" "Erro ao criar plano"

# Aplicar as mudanças
print_message "Aplicando mudanças..." "$YELLOW"
terraform apply tfplan
check_status "Mudanças aplicadas com sucesso" "Erro ao aplicar mudanças"

# ============================================================
# RESULTADO
#
# As URLs saem dos outputs, nao de texto fixo: o hostname do frontend
# carrega um sufixo sorteado a cada criacao.
# ============================================================

print_message "" "$NC"
print_message "============================================" "$GREEN"
print_message " AMBIENTE PRONTO" "$GREEN"
print_message "============================================" "$GREEN"
print_message "" "$NC"
echo "  Site (HTTP) : $(terraform output -raw frontend_url 2>/dev/null)"
echo "  Site (HTTPS): $(terraform output -raw frontend_url_https 2>/dev/null)"
echo "  API         : $(terraform output -raw api_url 2>/dev/null)"
echo "  Zona DNS    : $(terraform output -raw zona_dns 2>/dev/null)"
echo ""
# Sensivel, entao nao sai no bloco de outputs do apply -- e preciso
# pedir explicitamente.
echo "  Senha de instrutor (para mexer em registro de aluno pela"
echo "  interface; NÃO é a senha da turma):"
echo ""
echo "      $(terraform output -raw senha_admin 2>/dev/null)"
echo ""
echo "  O certificado do API Gateway pode levar alguns minutos para"
echo "  propagar. Se o site responder 403 logo apos o deploy, aguarde"
echo "  e recarregue."
echo ""

print_message "Deploy concluído com sucesso!" "$GREEN"