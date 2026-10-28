############################
# FRONTEND
#
# Este modulo NAO usa aws_s3_bucket (nem aws_s3_bucket_acl, _policy,
# _website_configuration, _ownership_controls, _public_access_block).
#
# Motivo: a SCP da organizacao do AWS Academy nega
# s3:GetBucketObjectLockConfiguration. O provider le essa configuracao
# de volta logo apos criar o bucket e, na particao "aws", trata o erro
# como fatal -- entao todo apply morria com:
#
#   Error: reading S3 Bucket (wwwNN...) object lock configuration:
#   ... AccessDenied ... explicit deny in a service control policy
#
# Deny de SCP nao se contorna de dentro da conta e o provider nao tem
# flag para pular a leitura. O bucket passa a ser criado pelo AWS CLI
# (scripts/criar_bucket_frontend.sh), que so escreve o que pedimos.
#
# O endpoint de website e deterministico, entao o CNAME e a integracao
# do proxy continuam funcionando sem ler nada do S3.
############################

############################
# SUFIXO NUMÉRICO ALEATÓRIO
#
# Nome de bucket e global na AWS: o sorteio evita colidir com outra
# conta que ja tenha www.<turma>.<dominio>.
############################
resource "random_integer" "frontend" {
  min = 0
  max = 99
}

data "aws_region" "atual" {}

############################
# DOMÍNIO E ENDPOINT
#
# O bucket precisa ter o mesmo nome do host, porque o S3 website
# roteia pelo Host da requisicao.
############################
locals {
  frontend_domain = "www${random_integer.frontend.result}.${var.frontend_nome_aluno}.${var.frontend_nome_dominio}"

  # Mesma forma que o atributo website_endpoint do provider devolvia.
  website_endpoint = "${local.frontend_domain}.s3-website-${data.aws_region.atual.name}.amazonaws.com"

  bucket_arn = "arn:aws:s3:::${local.frontend_domain}"
}

############################
# CRIAÇÃO DO BUCKET (via CLI)
#
# O script e idempotente: cria se faltar e reaplica website, public
# access block e policy em toda execucao.
############################
resource "null_resource" "criar_bucket" {
  triggers = {
    bucket = local.frontend_domain
    regiao = data.aws_region.atual.name
  }

  provisioner "local-exec" {
    working_dir = "${path.root}/.."

    command = "bash ./scripts/criar_bucket_frontend.sh ${local.frontend_domain} ${data.aws_region.atual.name}"
  }
}

############################
# BUILD DO FRONTEND
############################
resource "null_resource" "build_frontend" {
  depends_on = [
    var.api_gateway_stage_id
  ]

  triggers = {
    api_url = var.api_gateway_invoke_url
    api_key = var.api_key_value

    # O hash observava "../frontend_app", pasta que nao existe: o
    # resultado era sempre da39a3ee... (o sha1 da string vazia), entao
    # editar o frontend nunca disparava um novo build. O codigo esta em
    # dns_admin/, e o padrao lista so o que entra no bundle -- sem o
    # filtro, node_modules/ e build/ tornariam o hash inviavel.
    frontend_app_hash = sha1(join("", [
      for f in fileset("${path.root}/../dns_admin", "{src/**,public/**,index.html,package.json,vite.config.js}") :
      filemd5("${path.root}/../dns_admin/${f}")
    ]))
  }

  provisioner "local-exec" {
    working_dir = "${path.root}/.."

    command = <<EOT
      bash ./scripts/create_frontend_yarn.sh \
        --api-url ${var.api_gateway_invoke_url} \
        --api-key ${var.api_key_value}
    EOT
  }
}

############################
# UPLOAD DOS ARQUIVOS
#
# O upload usava aws_s3_object com for_each sobre um fileset do
# frontend_build. O fileset e resolvido no PLAN, antes de o
# null_resource gerar o build -- entao no primeiro apply a pasta nem
# existia, nenhum objeto entrava no plano e o site subia vazio.
#
# O sync roda no apply, depois do build, e o --delete remove sobras de
# builds anteriores. O proprio CLI define o Content-Type pela extensao.
############################
resource "null_resource" "upload_frontend" {
  triggers = {
    bucket   = local.frontend_domain
    build_id = null_resource.build_frontend.id
  }

  provisioner "local-exec" {
    working_dir = "${path.root}/.."

    command = "aws s3 sync ./terraform/frontend_build s3://${local.frontend_domain} --delete"
  }

  depends_on = [
    null_resource.criar_bucket,
    null_resource.build_frontend
  ]
}

############################
# ROUTE53 (CNAME → S3 WEBSITE)
############################
resource "aws_route53_record" "frontend" {
  name    = local.frontend_domain
  type    = "CNAME"
  zone_id = var.frontend_id_zona_hospedada
  ttl     = 60

  records = [local.website_endpoint]

  depends_on = [
    null_resource.criar_bucket
  ]
}
