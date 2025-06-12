#!/bin/bash

# Verifica se o AWS CLI está instalado
if ! command -v aws &> /dev/null; then
    echo "AWS CLI não encontrado. Por favor, instale-o primeiro."
    exit 1
fi

# Verifica se o Terraform está instalado
if ! command -v terraform &> /dev/null; then
    echo "Terraform não encontrado. Por favor, instale-o primeiro."
    exit 1
fi

# Verifica se as variáveis de ambiente necessárias estão definidas
if [ -z "$AWS_ACCESS_KEY_ID" ] || [ -z "$AWS_SECRET_ACCESS_KEY" ]; then
    echo "Por favor, defina as variáveis de ambiente AWS_ACCESS_KEY_ID e AWS_SECRET_ACCESS_KEY"
    exit 1
fi

# Navega para o diretório terraform
cd ../terraform

# Inicializa o Terraform
echo "Inicializando o Terraform..."
terraform init

# Plano de execução
echo "Criando plano de execução..."
terraform plan -out=tfplan

# Confirmação do usuário
read -p "Deseja aplicar as alterações? (s/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Ss]$ ]]; then
    # Aplica as alterações
    echo "Aplicando alterações..."
    terraform apply tfplan

    # Obtém a URL da API
    API_URL=$(terraform output -raw api_url)
    echo "API URL: $API_URL"

    # Atualiza o arquivo .env do frontend
    echo "REACT_APP_API_URL=$API_URL" > ../frontend/.env

    # Build do frontend
    echo "Fazendo build do frontend..."
    cd ../frontend
    npm install
    npm run build

    # Upload do frontend para o S3
    echo "Fazendo upload do frontend para o S3..."
    aws s3 sync build/ s3://frontend-$(cd ../terraform && terraform output -raw nome_dominio) --delete

    echo "Deploy concluído com sucesso!"
else
    echo "Operação cancelada pelo usuário."
fi 