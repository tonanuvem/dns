"""Gerenciador de aliases DNS do laboratorio.

Cada aluno cria um registro A dentro da zona compartilhada da turma
(ex.: joao.aluno.lab.tonanuvem.com). A API guarda o alias no DynamoDB
e aplica o registro correspondente no Route 53.

O frontend e o React-Admin, entao a listagem devolve o header
Content-Range e cada item carrega um campo "id".
"""

import ipaddress
import json
import hmac
import os
import re
from datetime import datetime

import boto3
from botocore.exceptions import ClientError

try:
    dynamodb = boto3.resource('dynamodb')
    route53 = boto3.client('route53')
    table = dynamodb.Table(os.environ['DYNAMODB_TABLE'])

    SENHA_API = os.environ['SENHA_API']
    TTL_DNS = int(os.environ['TTL_DNS'])
    ZONA_ID = os.environ['ZONA_ID']

    # A variavel se chamava NAMESERVERS, mas sempre guardou o dominio da
    # zona (ex.: "aluno.lab.tonanuvem.com") -- nunca uma lista de
    # nameservers. O nome antigo continua aceito para nao quebrar uma
    # funcao que ainda nao foi reimplantada.
    DOMINIO = os.environ.get('DOMINIO') or os.environ['NAMESERVERS']
except Exception as e:
    print(f"ERRO na inicializacao: {e}")
    raise

# Em producao o ideal seria restringir a origem; aqui o frontend sobe
# num bucket com nome sorteado, entao a origem muda a cada deploy.
COMMON_HEADERS = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "GET,POST,PUT,DELETE,OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type,X-API-Key,Authorization,Range",
    "Access-Control-Expose-Headers": "Content-Range",
    "Access-Control-Max-Age": "600",
    "Content-Type": "application/json"
}

# Um label de DNS: letras, digitos e hifen, sem comecar nem terminar
# com hifen. Nao aceita ponto, entao o aluno nao consegue criar um
# subdominio de varios niveis nem escapar da zona da turma.
ALIAS_VALIDO = re.compile(r'^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$')

# A zona e compartilhada pela turma inteira e a criacao usa UPSERT.
# Sem esta lista, um aluno que escolhesse o alias "api" sobrescreveria
# o registro da propria API e derrubaria o lab para todos. O padrao
# www\d* cobre o bucket do frontend (wwwNN) e o proxy HTTPS (www2).
ALIAS_RESERVADOS = re.compile(r'^(api|www\d*)$')


def _resposta(status, corpo, headers_extra=None):
    headers = dict(COMMON_HEADERS)
    if headers_extra:
        headers.update(headers_extra)
    return {
        'statusCode': status,
        'headers': headers,
        'body': '' if corpo is None else json.dumps(corpo, ensure_ascii=False)
    }


def _erro(status, mensagem):
    return _resposta(status, {'erro': mensagem})


def verificar_senha(senha_fornecida):
    # compare_digest exige str; um header ausente chega como None.
    return hmac.compare_digest(senha_fornecida or '', SENHA_API)


def _normalizar_path(event):
    """Remove o prefixo do stage do path.

    Pela URL de invoke o path chega como "/prod/registros"; pelo dominio
    personalizado (api.<turma>.<dominio>) chega como "/registros". Sem
    normalizar, so um dos dois casava com as rotas -- e era por isso que
    a listagem dava 404 no dominio personalizado.
    """
    path = event.get('path') or '/'
    stage = (event.get('requestContext') or {}).get('stage')

    if stage and stage != '$default':
        prefixo = f'/{stage}'
        if path == prefixo:
            path = '/'
        elif path.startswith(prefixo + '/'):
            path = path[len(prefixo):]

    return path.rstrip('/') or '/'


def _validar_entrada(alias, endereco_ip):
    """Devolve (alias_normalizado, mensagem_de_erro)."""
    if not alias or not endereco_ip:
        return None, 'Os campos alias e endereco_ip sao obrigatorios'

    alias = str(alias).strip().lower()

    if not ALIAS_VALIDO.match(alias):
        return None, (
            'Alias invalido. Use apenas letras minusculas, numeros e hifen '
            '(ate 63 caracteres, sem ponto e sem comecar ou terminar com hifen).'
        )

    if ALIAS_RESERVADOS.match(alias):
        return None, f"O alias '{alias}' e reservado pela infraestrutura do laboratorio"

    try:
        ip = ipaddress.ip_address(str(endereco_ip).strip())
    except ValueError:
        return None, f"Endereco IP invalido: {endereco_ip}"

    if ip.version != 4:
        return None, 'Apenas enderecos IPv4 sao aceitos (registro do tipo A)'

    return alias, None


def _nome_registro(alias):
    return f'{alias}.{DOMINIO}'


def _aplicar_no_route53(acao, alias, endereco_ip):
    route53.change_resource_record_sets(
        HostedZoneId=ZONA_ID,
        ChangeBatch={
            'Changes': [{
                'Action': acao,
                'ResourceRecordSet': {
                    'Name': _nome_registro(alias),
                    'Type': 'A',
                    'TTL': TTL_DNS,
                    'ResourceRecords': [{'Value': endereco_ip}]
                }
            }]
        }
    )


def lambda_handler(event, context):
    metodo = event.get('httpMethod', '')
    path = _normalizar_path(event)

    # Nada de logar headers ou corpo: o header x-api-key carrega a senha
    # da turma, e o CloudWatch fica legivel para quem tiver a LabRole.
    print(f"{metodo} {path}")

    try:
        if metodo == 'OPTIONS':
            return _resposta(200, None)

        headers = event.get('headers') or {}
        # O API Gateway nao garante a caixa do nome do header.
        senha = next(
            (v for k, v in headers.items() if k.lower() == 'x-api-key'),
            ''
        )

        if not verificar_senha(senha):
            return _erro(401, 'Senha invalida')

        partes = [p for p in path.split('/') if p]

        if path == '/info' and metodo == 'GET':
            return obter_info()

        if partes and partes[0] == 'registros':
            subdominio = partes[1] if len(partes) > 1 else None

            if metodo == 'GET' and subdominio is None:
                return listar_registros()
            if metodo == 'GET':
                return obter_registro(subdominio)
            if metodo == 'POST' and subdominio is None:
                return criar_registro(json.loads(event.get('body') or '{}'))
            if metodo == 'PUT' and subdominio:
                return atualizar_registro(
                    subdominio, json.loads(event.get('body') or '{}')
                )
            if metodo == 'DELETE' and subdominio:
                return deletar_registro(subdominio)

        return _erro(404, 'Rota nao encontrada')

    except json.JSONDecodeError:
        return _erro(400, 'Corpo da requisicao nao e um JSON valido')
    except Exception as e:
        print(f"ERRO em {metodo} {path}: {e}")
        return _erro(500, str(e))


def listar_registros():
    registros = []
    kwargs = {}

    # O scan e paginado: com uma turma grande, sem o loop a listagem
    # mostraria so a primeira pagina.
    while True:
        resposta = table.scan(**kwargs)
        registros.extend(resposta.get('Items', []))
        if 'LastEvaluatedKey' not in resposta:
            break
        kwargs['ExclusiveStartKey'] = resposta['LastEvaluatedKey']

    registros.sort(key=lambda r: r.get('alias', ''))

    for registro in registros:
        registro['id'] = registro['alias']

    qtd = len(registros)
    content_range = f"registros 0-{qtd - 1}/{qtd}" if qtd else "registros 0-0/0"

    print(f"listar_registros: {qtd} registro(s)")
    return _resposta(200, registros, {'Content-Range': content_range})


def obter_registro(subdominio):
    item = table.get_item(Key={'alias': subdominio}).get('Item')

    if not item:
        return _erro(404, 'Registro nao encontrado')

    item['id'] = item['alias']
    return _resposta(200, item)


def criar_registro(dados):
    alias, erro = _validar_entrada(dados.get('alias'), dados.get('endereco_ip'))
    if erro:
        return _erro(400, erro)

    endereco_ip = str(dados['endereco_ip']).strip()

    if table.get_item(Key={'alias': alias}).get('Item'):
        return _erro(409, f"O alias '{alias}' ja esta em uso")

    _aplicar_no_route53('UPSERT', alias, endereco_ip)

    item = {
        'alias': alias,
        'endereco_ip': endereco_ip,
        'data_criacao': datetime.now().isoformat()
    }
    table.put_item(Item=item)

    print(f"criar_registro: {_nome_registro(alias)} -> {endereco_ip}")

    item['id'] = alias
    return _resposta(201, item)


def atualizar_registro(subdominio, dados):
    """Troca o IP de um alias existente.

    A tela de edicao do React-Admin envia PUT /registros/{id}; sem esta
    rota o metodo caia no 404 e a edicao nao funcionava. O alias e a
    chave do DynamoDB e do Route 53, entao ele nao muda: o que o PUT
    altera e o IP.
    """
    item_atual = table.get_item(Key={'alias': subdominio}).get('Item')

    if not item_atual:
        return _erro(404, 'Registro nao encontrado')

    alias, erro = _validar_entrada(subdominio, dados.get('endereco_ip'))
    if erro:
        return _erro(400, erro)

    if alias != subdominio:
        return _erro(400, 'O alias nao pode ser alterado; apague e crie outro')

    endereco_ip = str(dados['endereco_ip']).strip()

    # UPSERT no mesmo nome e tipo substitui o valor anterior.
    _aplicar_no_route53('UPSERT', alias, endereco_ip)

    item = {
        'alias': alias,
        'endereco_ip': endereco_ip,
        'data_criacao': item_atual.get('data_criacao', datetime.now().isoformat()),
        'data_atualizacao': datetime.now().isoformat()
    }
    table.put_item(Item=item)

    print(f"atualizar_registro: {_nome_registro(alias)} -> {endereco_ip}")

    item['id'] = alias
    return _resposta(200, item)


def deletar_registro(subdominio):
    item = table.get_item(Key={'alias': subdominio}).get('Item')

    if not item:
        return _erro(404, 'Registro nao encontrado')

    try:
        _aplicar_no_route53('DELETE', subdominio, item['endereco_ip'])
    except ClientError as e:
        # O registro pode ter sido apagado direto no console do Route 53.
        # Antes isso virava um 500 e o item ficava preso no DynamoDB, sem
        # jeito de remover pela interface.
        if e.response['Error']['Code'] != 'InvalidChangeBatch':
            raise
        print(f"deletar_registro: {_nome_registro(subdominio)} ja nao existia no Route 53")

    table.delete_item(Key={'alias': subdominio})

    print(f"deletar_registro: {_nome_registro(subdominio)}")

    return _resposta(200, {'id': subdominio})


def obter_info():
    return _resposta(200, {
        'dominio': DOMINIO,
        'zona_id': ZONA_ID,
        'ttl': TTL_DNS
    })
