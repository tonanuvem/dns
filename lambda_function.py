import json
import boto3
import hashlib
import os
import time
import dns.resolver
from datetime import datetime
from botocore.exceptions import ClientError

# Inicialização dos clientes AWS
dynamodb = boto3.resource('dynamodb')
route53 = boto3.client('route53')
tabela = dynamodb.Table(os.environ['TABELA_DYNAMODB'])
ID_ZONA_HOSPEDADA = os.environ['ID_ZONA_HOSPEDADA']
SENHA_COMPARTILHADA = os.environ['SENHA_COMPARTILHADA']
NOME_DOMINIO = os.environ['NOME_DOMINIO']

def verificar_propagacao_dns(subdominio, endereco_ip, max_tentativas=30, intervalo=10):
    """
    Verifica se o registro DNS já foi propagado.
    
    Args:
        subdominio: Nome do subdomínio
        endereco_ip: IP esperado
        max_tentativas: Número máximo de tentativas
        intervalo: Intervalo entre tentativas em segundos
    
    Returns:
        bool: True se propagado, False se não propagado após todas as tentativas
    """
    nome_completo = f"{subdominio}.{NOME_DOMINIO}"
    tentativas = 0
    
    while tentativas < max_tentativas:
        try:
            resposta = dns.resolver.resolve(nome_completo, 'A')
            for registro in resposta:
                if str(registro) == endereco_ip:
                    return True
        except dns.resolver.NXDOMAIN:
            pass
        except dns.resolver.NoAnswer:
            pass
        except Exception:
            pass
        
        tentativas += 1
        time.sleep(intervalo)
    
    return False

def verificar_senha(senha):
    """Verifica se a senha fornecida corresponde à senha compartilhada."""
    hash_entrada = hashlib.sha256(senha.encode()).hexdigest()
    hash_armazenado = hashlib.sha256(SENHA_COMPARTILHADA.encode()).hexdigest()
    return hash_entrada == hash_armazenado

def criar_registro_dns(subdominio, endereco_ip):
    """Cria um registro A no Route 53."""
    try:
        lote_alteracoes = {
            'Changes': [
                {
                    'Action': 'UPSERT',
                    'ResourceRecordSet': {
                        'Name': f"{subdominio}.{NOME_DOMINIO}",
                        'Type': 'A',
                        'TTL': 60,  # Reduzido para 60 segundos para propagação mais rápida
                        'ResourceRecords': [
                            {
                                'Value': endereco_ip
                            }
                        ]
                    }
                }
            ]
        }
        
        resposta = route53.change_resource_record_sets(
            HostedZoneId=ID_ZONA_HOSPEDADA,
            ChangeBatch=lote_alteracoes
        )
        return resposta['ChangeInfo']['Id']
    except ClientError as e:
        raise Exception(f"Falha ao criar registro DNS: {str(e)}")

def criar_registro(subdominio, endereco_ip, senha):
    """Cria um novo registro DNS e armazena no DynamoDB."""
    if not verificar_senha(senha):
        raise Exception("Senha inválida")
    
    # Criar registro DNS
    id_alteracao = criar_registro_dns(subdominio, endereco_ip)
    
    # Armazenar no DynamoDB
    item = {
        'subdominio': subdominio,
        'endereco_ip': endereco_ip,
        'id_alteracao': id_alteracao,
        'data_criacao': datetime.utcnow().isoformat(),
        'status': 'PENDENTE'
    }
    
    tabela.put_item(Item=item)
    
    # Iniciar verificação de propagação
    propagado = verificar_propagacao_dns(subdominio, endereco_ip)
    
    # Atualizar status no DynamoDB
    if propagado:
        tabela.update_item(
            Key={'subdominio': subdominio},
            UpdateExpression='SET status = :status',
            ExpressionAttributeValues={
                ':status': 'PROPAGADO'
            }
        )
    else:
        tabela.update_item(
            Key={'subdominio': subdominio},
            UpdateExpression='SET status = :status',
            ExpressionAttributeValues={
                ':status': 'AGUARDANDO_PROPAGACAO'
            }
        )
    
    return item

def obter_registro(subdominio):
    """Recupera um registro do DynamoDB."""
    resposta = tabela.get_item(Key={'subdominio': subdominio})
    return resposta.get('Item')

def atualizar_registro(subdominio, endereco_ip, senha):
    """Atualiza um registro DNS existente."""
    if not verificar_senha(senha):
        raise Exception("Senha inválida")
    
    # Atualizar registro DNS
    id_alteracao = criar_registro_dns(subdominio, endereco_ip)
    
    # Atualizar DynamoDB
    tabela.update_item(
        Key={'subdominio': subdominio},
        UpdateExpression='SET endereco_ip = :ip, id_alteracao = :cid, data_atualizacao = :upd',
        ExpressionAttributeValues={
            ':ip': endereco_ip,
            ':cid': id_alteracao,
            ':upd': datetime.utcnow().isoformat()
        }
    )
    
    return obter_registro(subdominio)

def excluir_registro(subdominio, senha):
    """Exclui um registro DNS."""
    if not verificar_senha(senha):
        raise Exception("Senha inválida")
    
    try:
        # Excluir do Route 53
        lote_alteracoes = {
            'Changes': [
                {
                    'Action': 'DELETE',
                    'ResourceRecordSet': {
                        'Name': f"{subdominio}.{NOME_DOMINIO}",
                        'Type': 'A',
                        'TTL': 300,
                        'ResourceRecords': [
                            {
                                'Value': obter_registro(subdominio)['endereco_ip']
                            }
                        ]
                    }
                }
            ]
        }
        
        route53.change_resource_record_sets(
            HostedZoneId=ID_ZONA_HOSPEDADA,
            ChangeBatch=lote_alteracoes
        )
        
        # Excluir do DynamoDB
        tabela.delete_item(Key={'subdominio': subdominio})
        return {'mensagem': 'Registro excluído com sucesso'}
    except ClientError as e:
        raise Exception(f"Falha ao excluir registro: {str(e)}")

def listar_registros():
    """Lista todos os registros do DynamoDB."""
    resposta = tabela.scan()
    return resposta.get('Items', [])

def lambda_handler(evento, contexto):
    """Função principal do Lambda."""
    try:
        metodo_http = evento['httpMethod']
        caminho = evento['path']
        
        # Extrair parâmetros da query
        parametros_query = evento.get('queryStringParameters', {}) or {}
        corpo = json.loads(evento.get('body', '{}'))
        
        # Combinar parâmetros da query e corpo
        parametros = {**parametros_query, **corpo}
        
        if metodo_http == 'POST' and caminho == '/registros':
            return {
                'statusCode': 200,
                'body': json.dumps(criar_registro(
                    parametros['subdominio'],
                    parametros['endereco_ip'],
                    parametros['senha']
                ))
            }
            
        elif metodo_http == 'GET' and caminho == '/registros':
            if 'subdominio' in parametros:
                return {
                    'statusCode': 200,
                    'body': json.dumps(obter_registro(parametros['subdominio']))
                }
            return {
                'statusCode': 200,
                'body': json.dumps(listar_registros())
            }
            
        elif metodo_http == 'PUT' and caminho == '/registros':
            return {
                'statusCode': 200,
                'body': json.dumps(atualizar_registro(
                    parametros['subdominio'],
                    parametros['endereco_ip'],
                    parametros['senha']
                ))
            }
            
        elif metodo_http == 'DELETE' and caminho == '/registros':
            return {
                'statusCode': 200,
                'body': json.dumps(excluir_registro(
                    parametros['subdominio'],
                    parametros['senha']
                ))
            }
            
        return {
            'statusCode': 400,
            'body': json.dumps({'erro': 'Requisição inválida'})
        }
        
    except Exception as e:
        return {
            'statusCode': 500,
            'body': json.dumps({'erro': str(e)})
        } 