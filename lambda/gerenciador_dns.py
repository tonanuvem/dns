"""Gerenciador de aliases DNS do laboratorio.

Cada aluno cria um registro A dentro da zona compartilhada da turma
(ex.: joao.aluno.lab.tonanuvem.com). A API guarda o alias no DynamoDB
e aplica o registro correspondente no Route 53.

O frontend e o React-Admin, entao a listagem devolve o header
Content-Range e cada item carrega um campo "id".
"""

import hashlib
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

    # Senha do instrutor, para mexer em registro de aluno pela interface.
    #
    # Precisa ser DIFERENTE da SENHA_API: aquela e a senha da turma, vai
    # no bundle publico do frontend e embutida no dns.sh, entao todo
    # aluno a conhece -- usa-la aqui tornaria todos administradores.
    # Esta nunca sai da configuracao da Lambda; o instrutor a digita na
    # tela. Vazia (o padrao) desliga o override.
    SENHA_ADMIN = os.environ.get('SENHA_ADMIN', '')

    # Tabela do certificado da turma. Opcional de proposito: com .get()
    # em vez de [], este codigo sobe numa conta cujo Terraform ainda nao
    # criou a tabela, e as rotas /certificado respondem 503 em vez de a
    # Lambda inteira falhar na inicializacao e derrubar /registros com
    # ela. Vale enquanto a rota for nova; quando toda turma estiver
    # aplicada, pode virar obrigatoria.
    NOME_TABELA_CERT = os.environ.get('DYNAMODB_TABLE_CERT', '')
    tabela_cert = dynamodb.Table(NOME_TABELA_CERT) if NOME_TABELA_CERT else None
except Exception as e:
    print(f"ERRO na inicializacao: {e}")
    raise

# Em producao o ideal seria restringir a origem; aqui o frontend sobe
# num bucket com nome sorteado, entao a origem muda a cada deploy.
COMMON_HEADERS = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "GET,POST,PUT,DELETE,OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type,X-API-Key,X-Admin-Key,Authorization,Range",
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
# o registro da propria API e derrubaria o lab para todos. Os padroes
# cobrem os hostnames da infraestrutura: "api", "https" (o proxy com
# TLS) e wwwNN (o bucket do frontend, cujo sufixo e sorteado no apply).
# Os \d* tambem barram variacoes como www2 ou https1, deixadas para
# tras por deploys antigos.
ALIAS_RESERVADOS = re.compile(r'^(api|www\d*|https\d*)$')

# Os campos de um registro que podem sair na resposta. Ver _publico:
# e uma allowlist de proposito, para um campo novo nao nascer publico.
CAMPOS_PUBLICOS = ('alias', 'endereco_ip', 'data_criacao', 'data_atualizacao')

# ============================================================
# DESAFIO DNS-01 DO ACME
#
# O certificado da turma e emitido por DNS-01, o que exige criar um TXT
# em _acme-challenge.<nome> durante a validacao e apaga-lo depois. Quem
# emite rodava o lego com --dns route53 e precisava de credencial da
# conta da turma -- que no AWS Academy e de sessao e expira em horas,
# no meio da emissao. Esta Lambda nao tem esse problema: ela ja e dona
# da zona e roda com a LabRole, que nao expira.
#
# O lego chama /acme/present e /acme/cleanup pelo provider "exec", por
# meio de um script de cola que manda os mesmos headers de qualquer
# cliente da API. Foi essa a razao de escolher exec em vez do provider
# httpreq nativo: o httpreq so emite basic auth, nao consegue mandar
# x-admin-key, e a rota teria de furar o portao da senha da turma
# ANTES do roteamento -- uma excecao privilegiada no unico arquivo
# onde todo o resto passa pelo portao.
#
# O prefixo e fixo e a zona e conferida porque, sem isso, a rota vira
# escrita livre no Route 53: daria para forjar a validacao ACME de
# qualquer nome da zona e emitir certificado em nome dela.
# ============================================================

PREFIXO_ACME = '_acme-challenge.'

# O valor do desafio e um SHA-256 em base64url, 43 caracteres. Limitar
# ao alfabeto do base64url nao e so sanidade: o TXT vai para o Route 53
# entre aspas duplas, e uma aspa ou barra invertida no valor quebraria
# a codificacao do registro.
VALOR_ACME = re.compile(r'^[A-Za-z0-9_-]{1,255}$')

# Curto de proposito, e nao TTL_DNS: o registro vive por segundos e um
# TTL alto faria um resolvedor guardar a ausencia dele na renovacao
# seguinte. Fixo aqui para nao mudar junto com o TTL dos registros A.
TTL_ACME = 60


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


# ============================================================
# POSSE DO ALIAS
#
# A senha da API e a mesma para a turma inteira, entao ela diz "voce e
# desta turma", nunca "este registro e seu". Sem mais nada, qualquer
# aluno sobrescreveria o alias de outro -- e o IP da VM muda a cada
# aula, entao re-registrar o mesmo nome precisa funcionar.
#
# O dns.sh gera um token aleatorio por aluno, guarda em
# ~/.fiap_dns_token e o envia ao criar. Guardamos apenas o SHA-256: da
# para apagar o registro pelo console do DynamoDB quando o aluno perde
# a VM, mas ninguem le o token de volta.
#
# Registro criado sem token (pelo React-Admin, por exemplo) nao ganha
# dono e continua editavel por quem tiver a senha da turma.
# ============================================================

def _hash_token(token):
    return hashlib.sha256(token.encode('utf-8')).hexdigest()


def _extrair_token(headers, dados):
    """Le o token do header x-dns-token ou do corpo.

    O DELETE do React-Admin nao manda corpo, e um curl de DELETE com
    corpo e desajeitado -- dai aceitar pelo header tambem.
    """
    for k, v in (headers or {}).items():
        if k.lower() == 'x-dns-token' and v:
            return v

    if isinstance(dados, dict):
        return dados.get('token') or None

    return None


def _publico(item):
    """Versao do item que pode sair na resposta.

    Lista o que SAI, em vez de remover o que nao pode sair. A versao
    anterior fazia o contrario -- descartava o token_hash e deixava
    passar todo o resto -- e isso quer dizer que qualquer campo novo em
    qualquer item nascia publico. Hoje os itens so tem alias, ip e
    datas, entao a resposta e exatamente a mesma; o que muda e o modo
    de falhar. Quem guardar algo num item daqui em diante esquece de
    exibir um campo, em vez de publicar um sem perceber.

    Isso importa porque listar_registros() varre a tabela inteira atras
    de um portao so: a x-api-key, que e a senha da turma e e publica.

    O token_hash fica de fora: sem isso o hash de todo mundo ficaria
    exposto a qualquer aluno com a senha da turma -- material para um
    ataque de dicionario offline. No lugar dele vai "tem_dono", um
    booleano, que permite a interface mostrar quais registros ela nao
    pode editar em vez de oferecer um botao que falha com 403.

    O "id" e exigido pelo React-Admin, e o FQDN evita que a tela
    precise remontar o nome.
    """
    publico = {k: item[k] for k in CAMPOS_PUBLICOS if k in item}
    publico['id'] = item['alias']
    publico['tem_dono'] = bool(item.get('token_hash'))
    publico['nome_completo'] = _nome_registro(item['alias'])
    return publico


def _eh_admin(headers):
    """True quando o header x-admin-key traz a senha do instrutor."""
    if not SENHA_ADMIN:
        return False

    for k, v in (headers or {}).items():
        if k.lower() == 'x-admin-key' and v:
            return hmac.compare_digest(v, SENHA_ADMIN)

    return False


def _dono_confere(item, token, admin=False):
    """True quando o registro nao tem dono, o token bate, ou e o admin."""
    if admin:
        return True

    esperado = item.get('token_hash')

    if not esperado:
        return True

    if not token:
        return False

    return hmac.compare_digest(_hash_token(token), esperado)


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


def _nomes_registro(alias):
    """Os dois nomes que cada aluno recebe.

    O wildcard NAO cobre o nome base: *.joao.<zona> casa
    app.joao.<zona>, mas nao joao.<zona>. Por isso os dois existem.

    Juntos eles atendem o proxy reverso que roda dentro da VM do
    aluno: qualquer subdominio chega no mesmo IP, e quem decide o
    destino e o proxy, pelo cabecalho Host.
    """
    base = _nome_registro(alias)
    return [base, f'*.{base}']


def _mudanca(acao, nome, valores, tipo='A', ttl=None):
    """Um item de ChangeBatch.

    Era fixo em A com um valor unico. Generalizado para o TXT do ACME,
    que precisa de outro tipo e, no caso de apex + curinga no mesmo
    certificado, de VARIOS valores no mesmo nome -- os dois validam em
    _acme-challenge.<zona> ao mesmo tempo.
    """
    return {
        'Action': acao,
        'ResourceRecordSet': {
            'Name': nome,
            'Type': tipo,
            'TTL': TTL_DNS if ttl is None else ttl,
            'ResourceRecords': [{'Value': v} for v in valores]
        }
    }


def _enviar_ao_route53(mudancas):
    route53.change_resource_record_sets(
        HostedZoneId=ZONA_ID,
        ChangeBatch={'Changes': mudancas}
    )


def _aplicar_no_route53(acao, alias, endereco_ip):
    """Aplica a acao aos dois nomes, num lote so (atomico)."""
    _enviar_ao_route53([
        _mudanca(acao, nome, [endereco_ip])
        for nome in _nomes_registro(alias)
    ])


def _remover_do_route53(alias, endereco_ip):
    """Remove os dois nomes, tolerando que um deles ja nao exista.

    Um ChangeBatch e atomico: se o wildcard foi apagado a mao no
    console, ou se o registro vem de antes de o wildcard existir, o
    lote inteiro falha e NENHUM dos dois sai. Dai a segunda tentativa,
    um nome por vez.
    """
    try:
        _aplicar_no_route53('DELETE', alias, endereco_ip)
        return
    except ClientError as e:
        if e.response['Error']['Code'] != 'InvalidChangeBatch':
            raise

    for nome in _nomes_registro(alias):
        try:
            _enviar_ao_route53([_mudanca('DELETE', nome, [endereco_ip])])
        except ClientError as e:
            if e.response['Error']['Code'] != 'InvalidChangeBatch':
                raise
            print(f"_remover_do_route53: {nome} ja nao existia")


# ============================================================
# TXT DO ACME: validacao e leitura do conjunto existente
# ============================================================

def _validar_desafio_acme(dados):
    """Devolve (nome, valor_entre_aspas, mensagem_de_erro).

    O lego manda o fqdn com ponto final ("_acme-challenge.x.y.z."); o
    Route 53 aceita com ou sem, mas a comparacao com o que ja existe na
    zona precisa de uma forma unica, entao normalizamos sem o ponto.
    """
    fqdn = dados.get('fqdn')
    valor = dados.get('value')

    if not isinstance(fqdn, str) or not isinstance(valor, str):
        return None, None, 'Os campos fqdn e value sao obrigatorios'

    nome = fqdn.strip().lower().rstrip('.')
    valor = valor.strip()

    if not nome.startswith(PREFIXO_ACME):
        return None, None, f"O fqdn precisa comecar com '{PREFIXO_ACME}'"

    # Compara com o ponto na frente: sem ele, "_acme-challenge.x" mais
    # um dominio terminando no nome da zona (zonadoutro.lab...) tambem
    # casaria.
    if not nome.endswith('.' + DOMINIO):
        return None, None, f'O fqdn precisa estar dentro da zona {DOMINIO}'

    if not VALOR_ACME.match(valor):
        return None, None, 'O value precisa ser base64url (letras, numeros, - e _)'

    return nome, f'"{valor}"', None


def _txt_existentes(nome):
    """Devolve (valores_entre_aspas, ttl) do TXT nesse nome exato.

    ([], None) quando nao existe. A leitura e o que permite somar e
    subtrair um valor em vez de sobrescrever o conjunto: com apex e
    curinga no mesmo certificado, os dois desafios convivem no mesmo
    nome, e um UPSERT de valor unico apagaria o que ainda esta em voo.
    """
    resposta = route53.list_resource_record_sets(
        HostedZoneId=ZONA_ID,
        StartRecordName=nome,
        StartRecordType='TXT',
        MaxItems='1'
    )

    for rrset in resposta.get('ResourceRecordSets', []):
        mesmo_nome = (rrset.get('Name') or '').rstrip('.').lower() == nome
        if mesmo_nome and rrset.get('Type') == 'TXT':
            valores = [r['Value'] for r in rrset.get('ResourceRecords', [])]
            return valores, rrset.get('TTL')

    return [], None


def _trocar_txt(nome, antigos, ttl_antigo, novos):
    """Troca o conjunto de valores detectando escrita concorrente.

    O caminho obvio seria UPSERT, mas o UPSERT substitui o RRset
    INTEIRO: montar a uniao a partir de uma leitura perde um valor em
    silencio se outro escritor mexer no nome entre a leitura e a
    escrita -- e sem erro nenhum, o que e o pior jeito de falhar.

    Um ChangeBatch e atomico, e o DELETE exige o RRset exatamente como
    esta na zona (valores e TTL). Entao [DELETE antigo, CREATE novo] e
    um compare-and-swap: se alguem escreveu no meio, o DELETE nao casa,
    o lote inteiro e recusado e nada se perde. O CREATE sozinho cobre o
    outro lado -- ele falha se o registro apareceu entretanto.
    """
    mudancas = []

    if antigos:
        mudancas.append(_mudanca(
            'DELETE', nome, antigos, tipo='TXT',
            ttl=ttl_antigo if ttl_antigo is not None else TTL_ACME
        ))

    if novos:
        mudancas.append(_mudanca('CREATE', nome, novos, tipo='TXT', ttl=TTL_ACME))

    if mudancas:
        _enviar_ao_route53(mudancas)


def _atualizar_txt(nome, transformar, tentativas=3):
    """Le, transforma e grava, repetindo se a zona mudou no meio.

    transformar(valores) devolve a nova lista, ou None quando nao ha
    nada a fazer -- e o caso idempotente.
    """
    for tentativa in range(tentativas):
        atuais, ttl = _txt_existentes(nome)
        novos = transformar(atuais)

        if novos is None:
            return atuais, False

        try:
            _trocar_txt(nome, atuais, ttl, novos)
            return novos, True
        except ClientError as e:
            if e.response['Error']['Code'] != 'InvalidChangeBatch':
                raise
            if tentativa == tentativas - 1:
                raise
            print(f"_atualizar_txt: {nome} mudou no meio, relendo")


# ============================================================
# CERTIFICADO DA TURMA
#
# O painel do labproxy roda HTTPS no nome de cada aluno, e o
# certificado e um curinga unico da turma (*.<turma>.<dominio>), emitido
# uma vez a cada 90 dias. Esta rota o guarda e o distribui, para a VM do
# aluno nao precisar de credencial AWS nem de cliente ACME.
#
#   PUT /certificado   x-admin-key                 -> o instrutor sobe
#   GET /certificado   x-api-key + x-dns-token     -> a VM busca
#
# O GET autentica pelo TOKEN DE POSSE, nunca pela senha da turma: a
# senha esta no bundle do frontend e embutida no dns.sh, entao serviria
# a chave privada a qualquer um. O token prova que quem pede e dono de
# algum nome da zona -- a mesma prova do _dono_confere, sem exigir um
# alias especifico.
#
# A chave e guardada no campo "chave" e so vira "key" na resposta, que
# e o contrato do cliente do labproxy. A assimetria e de proposito: um
# dump da tabela nao tem o mesmo nome de campo que o payload publico,
# o que estorva uma copia descuidada de um lado para o outro.
# ============================================================

# Guardado num item unico, com a turma como chave.
CHAVE_CERT = 'atual'

INICIO_CERT = '-----BEGIN CERTIFICATE-----'
INICIO_CHAVE = '-----BEGIN'  # RSA PRIVATE KEY, PRIVATE KEY, EC PRIVATE KEY...


def _token_conhecido(token):
    """True quando o token bate com o de ALGUM registro da zona.

    Sem alias: o aluno pede o certificado da turma, nao um registro.
    Varre a tabela projetando so o token_hash -- a turma tem dezenas de
    itens, nao milhares, e isto roda uma vez por subida de VM.
    """
    if not token:
        return False

    alvo = _hash_token(token)
    kwargs = {'ProjectionExpression': 'token_hash'}

    while True:
        resposta = table.scan(**kwargs)

        for item in resposta.get('Items', []):
            guardado = item.get('token_hash')
            if guardado and hmac.compare_digest(guardado, alvo):
                return True

        if 'LastEvaluatedKey' not in resposta:
            return False

        kwargs['ExclusiveStartKey'] = resposta['LastEvaluatedKey']


def guardar_certificado(dados):
    """PUT /certificado -- so o instrutor."""
    if tabela_cert is None:
        return _erro(503, 'Armazenamento do certificado nao configurado nesta conta')

    cert = dados.get('cert')
    chave = dados.get('key')

    if not isinstance(cert, str) or not isinstance(chave, str):
        return _erro(400, 'Os campos cert e key sao obrigatorios')

    cert = cert.strip()
    chave = chave.strip()

    if INICIO_CERT not in cert:
        return _erro(400, 'O campo cert nao parece um certificado PEM')

    if INICIO_CHAVE not in chave or 'PRIVATE KEY' not in chave:
        return _erro(400, 'O campo key nao parece uma chave privada PEM')

    # Identifica a versao sem precisar ler o certificado: o cliente
    # manda de volta e a gente responde 304 se nao mudou.
    impressao = hashlib.sha256(cert.encode()).hexdigest()[:16]

    item = {
        'turma': CHAVE_CERT,
        'cert': cert,
        'chave': chave,
        'emitido_em': datetime.now().isoformat(),
        'impressao': impressao
    }

    # A validade vem de quem emitiu: ler o X.509 exigiria dependencia
    # fora da stdlib, e o emitir-cert.sh ja tem o openssl na mao.
    expira_em = dados.get('expira_em')
    if isinstance(expira_em, str) and expira_em.strip():
        item['expira_em'] = expira_em.strip()

    tabela_cert.put_item(Item=item)

    print(f"guardar_certificado: impressao {impressao}")

    return _resposta(200, {
        'impressao': impressao,
        'emitido_em': item['emitido_em'],
        'expira_em': item.get('expira_em', '')
    })


def obter_certificado(token, params):
    """GET /certificado -- autenticado pelo token de posse do aluno."""
    if tabela_cert is None:
        return _erro(503, 'Armazenamento do certificado nao configurado nesta conta')

    # Mensagem unica: nao distingue "token ausente" de "token nao bate",
    # para a resposta nao dizer se um token existe na zona.
    if not _token_conhecido(token):
        return _erro(403, 'Token de posse invalido')

    item = tabela_cert.get_item(Key={'turma': CHAVE_CERT}).get('Item')

    if not item:
        return _erro(404, 'Nenhum certificado publicado para esta turma')

    impressao = item.get('impressao', '')

    # 304: o proxy.sh roda a cada subida de VM e sem isto rebaixaria o
    # certificado do disco por nada.
    if impressao and params.get('impressao') == impressao:
        print("obter_certificado: 304, cliente ja tem esta versao")
        return _resposta(304, None)

    print(f"obter_certificado: entregue, impressao {impressao}")

    return _resposta(200, {
        'cert': item.get('cert', ''),
        'key': item.get('chave', ''),
        'emitido_em': item.get('emitido_em', ''),
        'expira_em': item.get('expira_em', ''),
        'impressao': impressao
    })


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

        # Rota propria, e nao um caso dentro de /registros: la a posse e
        # do aluno, provada pelo token em ~/.fiap_dns_token, e o TXT do
        # ACME nao tem dono aluno nenhum -- e o instrutor agindo sobre a
        # zona inteira. Pendurar no /registros obrigaria a abrir excecao
        # no _dono_confere e no _validar_entrada, que validam alias de
        # registro A.
        if partes and partes[0] == 'acme':
            if not _eh_admin(headers):
                return _erro(403, 'Esta rota exige a senha de instrutor (x-admin-key)')

            corpo = json.loads(event.get('body') or '{}')

            if metodo == 'POST' and partes[1:] == ['present']:
                return acme_present(corpo)
            if metodo == 'POST' and partes[1:] == ['cleanup']:
                return acme_cleanup(corpo)

        if partes == ['certificado']:
            corpo = json.loads(event.get('body') or '{}')
            params = event.get('queryStringParameters') or {}

            # Excecao contida AQUI, e nao no except geral: aquele loga
            # str(e), e a mensagem de um erro do DynamoDB pode carregar
            # pedaco do item -- que neste caminho inclui a chave
            # privada. Daqui so o TIPO da excecao chega ao CloudWatch.
            try:
                if metodo == 'PUT':
                    if not _eh_admin(headers):
                        return _erro(403, 'Esta rota exige a senha de instrutor (x-admin-key)')
                    return guardar_certificado(corpo)

                if metodo == 'GET':
                    return obter_certificado(_extrair_token(headers, corpo), params)

            except Exception as e:
                print(f"ERRO em {metodo} /certificado: {type(e).__name__}")
                return _erro(500, 'Erro ao processar o certificado')

        if partes and partes[0] == 'registros':
            subdominio = partes[1] if len(partes) > 1 else None
            corpo = json.loads(event.get('body') or '{}')
            token = _extrair_token(headers, corpo)
            admin = _eh_admin(headers)

            if metodo == 'GET' and subdominio is None:
                return listar_registros()
            if metodo == 'GET':
                return obter_registro(subdominio)
            if metodo == 'POST' and subdominio is None:
                return criar_registro(corpo, token)
            if metodo == 'PUT' and subdominio:
                return atualizar_registro(subdominio, corpo, token, admin)
            if metodo == 'DELETE' and subdominio:
                return deletar_registro(subdominio, token, admin)

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
    registros = [_publico(r) for r in registros]

    qtd = len(registros)
    content_range = f"registros 0-{qtd - 1}/{qtd}" if qtd else "registros 0-0/0"

    print(f"listar_registros: {qtd} registro(s)")
    return _resposta(200, registros, {'Content-Range': content_range})


def obter_registro(subdominio):
    item = table.get_item(Key={'alias': subdominio}).get('Item')

    if not item:
        return _erro(404, 'Registro nao encontrado')

    return _resposta(200, _publico(item))


def criar_registro(dados, token=None):
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

    if token:
        item['token_hash'] = _hash_token(token)

    table.put_item(Item=item)

    print(f"criar_registro: {_nome_registro(alias)} (+ wildcard) -> {endereco_ip}"
          f"{' (com dono)' if token else ''}")

    return _resposta(201, _publico(item))


def atualizar_registro(subdominio, dados, token=None, admin=False):
    """Troca o IP de um alias existente.

    A tela de edicao do React-Admin envia PUT /registros/{id}; sem esta
    rota o metodo caia no 404 e a edicao nao funcionava. O alias e a
    chave do DynamoDB e do Route 53, entao ele nao muda: o que o PUT
    altera e o IP.
    """
    item_atual = table.get_item(Key={'alias': subdominio}).get('Item')

    if not item_atual:
        return _erro(404, 'Registro nao encontrado')

    if not _dono_confere(item_atual, token, admin):
        return _erro(403, f"O alias '{subdominio}' pertence a um aluno. "
                         "Use o token dele ou a senha de instrutor.")

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

    # O dono e preservado: sem isto, uma atualizacao apagaria o
    # token_hash e o registro voltaria a ser de todo mundo.
    if item_atual.get('token_hash'):
        item['token_hash'] = item_atual['token_hash']

    table.put_item(Item=item)

    print(f"atualizar_registro: {_nome_registro(alias)} (+ wildcard) -> {endereco_ip}")

    return _resposta(200, _publico(item))


def deletar_registro(subdominio, token=None, admin=False):
    item = table.get_item(Key={'alias': subdominio}).get('Item')

    if not item:
        return _erro(404, 'Registro nao encontrado')

    if not _dono_confere(item, token, admin):
        return _erro(403, f"O alias '{subdominio}' pertence a um aluno. "
                         "Use o token dele ou a senha de instrutor.")

    # Tolera o registro ja ter sido apagado no console do Route 53.
    # Antes isso virava 500 e o item ficava preso no DynamoDB, sem jeito
    # de remover pela interface.
    _remover_do_route53(subdominio, item['endereco_ip'])

    table.delete_item(Key={'alias': subdominio})

    print(f"deletar_registro: {_nome_registro(subdominio)} (+ wildcard)")

    return _resposta(200, {'id': subdominio})


def acme_present(dados):
    """Cria o TXT do desafio, somando ao que ja existir no nome."""
    nome, valor, erro = _validar_desafio_acme(dados)
    if erro:
        return _erro(400, erro)

    # Idempotente: o lego trata qualquer 2xx como sucesso, e repetir o
    # present com o mesmo valor nao deve falhar nem duplicar.
    def somar(atuais):
        return None if valor in atuais else atuais + [valor]

    valores, mudou = _atualizar_txt(nome, somar)

    if not mudou:
        print(f"acme_present: {nome} ja tinha este valor")

    return _resposta(200, {'fqdn': nome, 'valores': len(valores)})


def acme_cleanup(dados):
    """Remove APENAS o proprio valor do TXT do desafio.

    Apagar o RRset inteiro derrubaria o desafio de outro nome que ainda
    esteja em voo -- e a emissao falharia no segundo nome, nao no
    primeiro, que e bem mais confuso de diagnosticar. O registro so sai
    da zona quando o conjunto esvazia.
    """
    nome, valor, erro = _validar_desafio_acme(dados)
    if erro:
        return _erro(400, erro)

    # Idempotente: o cleanup roda tambem depois de uma emissao que
    # falhou no meio, quando o valor pode nem ter sido criado.
    def subtrair(atuais):
        if valor not in atuais:
            return None
        return [v for v in atuais if v != valor]

    restantes, mudou = _atualizar_txt(nome, subtrair)

    if not mudou:
        print(f"acme_cleanup: {nome} ja nao tinha este valor")

    return _resposta(200, {'fqdn': nome, 'valores': len(restantes)})


def obter_info():
    return _resposta(200, {
        'dominio': DOMINIO,
        'zona_id': ZONA_ID,
        'ttl': TTL_DNS
    })
