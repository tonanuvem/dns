# Gerenciador de DNS para Laboratório

Este projeto implementa um sistema de gerenciamento de DNS para laboratórios, permitindo que alunos criem subdomínios apontando para suas máquinas virtuais criadas em nuvem. O sistema inclui uma interface administrativa e uma API REST para gerenciamento dos registros DNS.

## Arquitetura

- **Backend**: AWS Lambda + DynamoDB + API Gateway
- **Frontend**: React Admin hospedado em S3 + CloudFront
- **DNS**: Route 53
- **Infraestrutura**: Terraform

## Pré-requisitos

1. **AWS CLI**
   ```bash
   # Verificar instalação
   aws --version
   
   # Configurar credenciais
   aws configure
   ```

2. **Terraform**
   ```bash
   # Verificar instalação
   terraform --version
   ```

3. **Node.js e npm**
   ```bash
   # Verificar instalações
   node --version
   npm --version
   ```

4. **Python 3.9+**
   ```bash
   # Verificar instalação
   python3 --version
   ```

5. **Acesso AWS**
   - Conta AWS com permissões para criar recursos
   - Zona hospedada no Route 53 (ver seção "Configuração do Route 53" abaixo)

## Configuração do Route 53

O projeto assume que você já tem uma zona hospedada no Route 53. Se você ainda não tem, siga estes passos:

1. **Criar uma nova zona hospedada**
   ```bash
   # Criar a zona
   aws route53 create-hosted-zone \
     --name aluno.lab.tonanuvem.com \
     --caller-reference $(date +%s) \
     --hosted-zone-config '{"Comment": "Zona hospedada para laboratório", "PrivateZone": false, "TTL": 60}'
   ```

2. **Obter os servidores de nomes**
   ```bash
   # Listar todas as zonas hospedadas
   aws route53 list-hosted-zones
   # Para obter detalhes de uma zona específica
   aws route53 get-hosted-zone --id <ID_DA_ZONA>
   ```

3. **Configurar os servidores de nomes no seu registrador de domínio**
   - Acesse o painel do seu registrador de domínio
   - Copie os servidores de nomes (NS) listados no comando `get-hosted-zone`
   - No painel do registrador, localize a seção de configuração de DNS ou Nameservers
   - Na seção de "Criação rápida de registro" ou "Adicionar registro":
     - Tipo de registro: Selecione "NS" (Nameserver)
     - Nome/Host: Deixe em branco ou coloque "@" para o domínio raiz
     - Valor/Conteúdo: Cole cada um dos 4 servidores NS da AWS em registros separados
       (exemplo: ns-1234.awsdns-12.com, ns-567.awsdns-34.com, etc.)
     - TTL: Configure para 60 segundos (valor mínimo recomendado) para propagação mais rápida
   - Os servidores geralmente seguem o formato: ns-XXXX.awsdns-XX.com
   - Certifique-se de adicionar todos os servidores listados (geralmente 4)
   - Configure o registro SOA (Start of Authority):
     - Tipo de registro: SOA
     - Nome/Host: Deixe em branco ou coloque "@" para o domínio raiz
     - Valor/Conteúdo: Use o formato: ns-XXXX.awsdns-XX.com. awsdns-hostmaster.amazon.com. 1 7200 900 1209600 86400
     - TTL: 60 segundos
   - Salve as alterações
   - Aguarde a propagação (pode levar até 48 horas)

4. **Verificar a validação**
   ```bash
   # Verificar se a zona está ativa
   aws route53 get-hosted-zone --id <ID_DA_ZONA>
   
   # Verificar resolução DNS
   dig NS aluno.lab.tonanuvem.com
   ```

5. **Obter o ID da zona**
   ```bash
   # Listar zonas hospedadas
   aws route53 list-hosted-zones
   
   # Anotar o ID da zona (será necessário para o deploy)
   ```

## Configuração Inicial

1. **Clone o repositório**
   ```bash
   git clone <repositorio>
   cd <diretorio>
   ```

2. **Configure as variáveis de ambiente AWS**
   ```bash
   export AWS_ACCESS_KEY_ID="sua_access_key"
   export AWS_SECRET_ACCESS_KEY="sua_secret_key"
   export AWS_DEFAULT_REGION="us-east-1"
   ```

3. **Configure as variáveis do Terraform**
   ```bash
   cd terraform
   # Copie o arquivo de exemplo
   cp terraform.tfvars.example terraform.tfvars
   
   # Edite o arquivo terraform.tfvars com seus valores:
   # - nome_aluno: seu_nome (ex: joao, maria, etc)
   # - nome_dominio: lab.tonanuvem.com
   # - senha_compartilhada: sua_senha_segura
   # - ttl_dns: 60
   ```

## Deploy da Infraestrutura

1. **Inicialize o Terraform**
   ```bash
   cd terraform
   terraform init
   ```

2. **Verifique o plano de execução**
   ```bash
   terraform plan
   ```

3. **Execute o deploy**
   ```bash
   ./deploy.sh
   ```

## Pontos de Verificação

### 1. Verificação da Infraestrutura AWS

1. **Lambda Function**
   ```bash
   # Verificar se a função foi criada
   aws lambda get-function --function-name gerenciador-dns-<seu_nome>
   
   # Verificar as variáveis de ambiente
   aws lambda get-function-configuration --function-name gerenciador-dns-<seu_nome>
   ```

2. **DynamoDB**
   ```bash
   # Verificar se a tabela foi criada
   aws dynamodb describe-table --table-name registros-dns-<seu_nome>
   ```

3. **API Gateway**
   ```bash
   # Obter a URL da API
   aws apigatewayv2 get-apis
   ```

4. **S3 e CloudFront**
   ```bash
   # Verificar o bucket
   aws s3 ls s3://frontend-<seu_nome>.lab.tonanuvem.com
   
   # Verificar a distribuição CloudFront
   aws cloudfront list-distributions
   ```

### 2. Verificação do DNS

1. **Verificar registros DNS**
   ```bash
   # Verificar se o domínio principal está configurado
   dig <seu_nome>.lab.tonanuvem.com
   
   # Verificar se o CloudFront está configurado
   dig +short <seu_nome>.lab.tonanuvem.com
   ```

2. **Testar criação de subdomínio**
   ```bash
   # Criar um registro de teste
   curl -X POST https://api.<seu_nome>.lab.tonanuvem.com/registros \
     -H "Content-Type: application/json" \
     -H "X-API-Key: sua_senha" \
     -d '{
       "subdominio": "teste",
       "endereco_ip": "1.1.1.1"
     }'
   
   # Verificar propagação
   dig teste.<seu_nome>.lab.tonanuvem.com
   ```

### 3. Verificação do Frontend

1. **Acessar a interface**
   - Abra https://<seu_nome>.lab.tonanuvem.com no navegador
   - Verifique se a interface carrega corretamente
   - Teste o login (se configurado)

2. **Testar operações CRUD**
   - Criar um novo registro
   - Editar um registro existente
   - Excluir um registro
   - Listar registros

3. **Verificar informações da zona**
   - Confirme se os nameservers estão visíveis
   - Verifique se o ID da zona está correto
   - Confirme se o TTL está configurado para 60 segundos

## Monitoramento e Logs

1. **CloudWatch Logs**
   ```bash
   # Verificar logs da Lambda
   aws logs get-log-events \
     --log-group-name /aws/lambda/gerenciador-dns-<seu_nome> \
     --log-stream-name <stream-name>
   ```

2. **CloudFront Logs**
   ```bash
   # Verificar logs de acesso
   aws cloudfront get-distribution-config \
     --id <distribution-id>
   ```

## Troubleshooting

1. **Problemas de DNS**
   - Verificar TTL dos registros (deve ser 60 segundos)
   - Limpar cache DNS local
   - Usar ferramentas como `dig` ou `nslookup`
   - Verificar se a zona está ativa no Route 53
   - Verificar se os servidores de nomes estão corretamente configurados
   - Confirmar se os nameservers estão corretamente propagados

2. **Problemas de API**
   - Verificar logs da Lambda
   - Testar endpoints diretamente
   - Verificar CORS
   - Confirmar se a senha está correta no header X-API-Key

3. **Problemas de Frontend**
   - Verificar console do navegador
   - Verificar logs do CloudFront
   - Verificar configuração do S3
   - Confirmar se os nameservers estão sendo exibidos corretamente

## Manutenção

1. **Atualizações de Código**
   ```bash
   # Atualizar Lambda
   cd terraform
   ./deploy.sh
   ```

2. **Backup do DynamoDB**
   ```bash
   # Criar backup
   aws dynamodb create-backup \
     --table-name registros-dns-<seu_nome> \
     --backup-name backup-$(date +%Y%m%d)
   ```

3. **Limpeza de Recursos**
   ```bash
   # Destruir infraestrutura
   cd terraform
   terraform destroy
   ```

## Segurança

1. **Verificar IAM Roles**
   ```bash
   # Verificar permissões da Lambda
   aws iam get-role-policy \
     --role-name lambda_gerenciador_dns_role_<seu_nome> \
     --policy-name lambda_gerenciador_dns_policy_<seu_nome>
   ```

2. **Verificar Políticas de Bucket**
   ```bash
   # Verificar políticas do S3
   aws s3api get-bucket-policy \
     --bucket frontend-<seu_nome>.lab.tonanuvem.com
   ```

3. **Verificar Certificados SSL**
   ```bash
   # Verificar certificado
   aws acm list-certificates
   ```

## Suporte

Para problemas ou dúvidas:
1. Verificar logs e métricas no AWS Console
2. Consultar documentação do Terraform
3. Verificar status dos serviços AWS
4. Abrir issue no repositório 