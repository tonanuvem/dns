# Gerenciador DNS

Sistema que permite aos alunos criarem aliases DNS para suas máquinas usando AWS Route 53 e DynamoDB.

## Requisitos

- Node.js 18.x ou superior
- npm 9.x ou superior
- Python 3.8 ou superior
- AWS CLI 2.x
- Terraform 1.x

## Configuração Inicial

1. Clone o repositório:
```bash
git clone https://github.com/tonanuvem/dns.git
cd dns
```

1.1. Executar script de credenciais:
```bash
source ./credenciais_config.sh
```

2. Execute o script de configuração:
```bash
./config.sh <nome_aluno> <senha>
```

Este script irá:
- Configurar o ambiente Python
- Verificar as zonas DNS disponíveis
- Configurar as credenciais AWS
- Criar o arquivo de configuração do Terraform

## Desenvolvimento

### Backend

O backend é uma função Lambda em Python que gerencia os registros DNS.

Este projeto irá:
- Criar o arquivo ZIP da função Lambda
- Criar o build do frontend
- Verificar se todos os arquivos necessários foram criados

### Frontend

O frontend é uma aplicação React que permite aos alunos gerenciar seus aliases DNS.

## Deploy

Para fazer o deploy da infraestrutura:
```bash
./scripts/deploy.sh
```

Este script irá:
- Verificar se todos os arquivos necessários existem
- Inicializar o Terraform
- Criar um plano de execução
- Aplicar as mudanças

## Estrutura do Projeto

```
.
├── config.sh             # Configuração inicial (gera o terraform.tfvars)
├── lambda/               # Código da função Lambda
├── tests/                # Testes da Lambda (rodam sem AWS)
├── dns_admin/            # Frontend React-Admin
├── scripts/              # Scripts auxiliares
│   ├── deploy.sh             # Cria/atualiza todo o ambiente
│   ├── limpar_ambiente.sh    # Remove o que sobrou de um apply interrompido
│   ├── testar_api.sh         # Exercita a API de ponta a ponta
│   └── mostrar_delegacao.sh  # Imprime os NS para delegar na zona pai
└── terraform/            # Código Terraform
    ├── main.tf
    ├── variables.tf
    ├── outputs.tf
    └── modules/
        ├── lambda_api/       # Lambda + DynamoDB
        ├── api_gateway/      # HTTP API da aplicação
        ├── frontend/         # Bucket do site + build
        └── apigw_s3_proxy/   # Mesmo site com TLS
```

## Troubleshooting

### Erro ao executar config.sh
- Verifique se Python 3 está instalado
- Verifique se as credenciais AWS estão configuradas
- Verifique se a zona DNS do aluno existe

### Erro ao executar deploy.sh
- Verifique se as credenciais AWS são válidas
- Verifique se o arquivo terraform.tfvars está configurado corretamente 
- Verifique se o diretório lambda existe
- Verifique se o arquivo gerenciador_dns.py existe
- Verifique se o Node.js e npm estão instalados
