# Gerenciador DNS

Este projeto permite que alunos criem aliases DNS para suas máquinas usando AWS Route 53 e DynamoDB.

## Requisitos

- Node.js 16+
- npm 7+
- Python 3.8+
- AWS CLI configurado
- Terraform 1.0+

## Configuração Inicial

1. Clone o repositório:
```bash
git clone <url-do-repositorio>
cd dns-manager
```

2. Execute o script de configuração:
```bash
./config.sh
```

Este script irá:
- Configurar as variáveis de ambiente AWS
- Criar o arquivo ZIP da função Lambda
- Configurar o arquivo terraform.tfvars

## Desenvolvimento

### Frontend

O frontend é uma aplicação React Admin que permite gerenciar os registros DNS.

Para desenvolvimento:
```bash
cd frontend
npm install
npm run dev
```

### Backend

O backend é uma função Lambda em Python que gerencia os registros DNS no Route 53.

Para desenvolvimento:
```bash
cd lambda
python -m venv venv
source venv/bin/activate  # No Windows: venv\Scripts\activate
pip install -r requirements.txt
```

## Deploy

Antes de executar o deploy, é necessário preparar os arquivos do frontend e do backend:

1. Criar o build do frontend:
```bash
./scripts/create_frontend.sh
```

2. Criar o arquivo ZIP do backend:
```bash
./scripts/create_backend.sh
```

3. Executar o deploy:
```bash
./scripts/deploy.sh
```

## Atualização do Frontend

Para atualizar apenas o frontend após fazer alterações:

1. Criar o build do frontend:
```bash
./scripts/create_frontend.sh
```

2. Atualizar os arquivos no S3:
```bash
./scripts/update_frontend.sh
```

## Estrutura do Projeto

- `frontend/` - Aplicação React Admin
- `lambda/` - Função Lambda em Python
- `terraform/` - Configuração do Terraform
- `scripts/` - Scripts de automação
  - `create_frontend.sh` - Cria o build do frontend
  - `create_backend.sh` - Cria o arquivo ZIP da função Lambda
  - `deploy.sh` - Executa o deploy do Terraform
  - `update_frontend.sh` - Atualiza o frontend no S3 