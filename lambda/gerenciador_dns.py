import json
import boto3
import os
import hashlib
import hmac
import base64
from datetime import datetime

# Configuração dos clientes AWS
dynamodb = boto3.resource('dynamodb')
route53 = boto3.client('route53')
table = dynamodb.Table(os.environ['DYNAMODB_TABLE'])

# Configurações
SENHA_API = os.environ['SENHA_API']
TTL_DNS = int(os.environ['TTL_DNS'])
NAMESERVERS = os.environ['NAMESERVERS'].split(',')
ZONA_ID = os.environ['ZONA_ID']

def verificar_senha(senha_fornecida):
    """Verifica se a senha fornecida está correta"""
    return hmac.compare_digest(senha_fornecida, SENHA_API)

def lambda_handler(event, context):
    """Função principal do Lambda"""
    try:
        # Verificar método HTTP
        http_method = event.get('httpMethod', '')
        path = event.get('path', '')
        
        # Verificar autenticação
        headers = event.get('headers', {})
        senha = headers.get('X-API-Key', '')
        
        if not verificar_senha(senha):
            return {
                'statusCode': 401,
                'body': json.dumps({'erro': 'Senha inválida'})
            }
        
        # Roteamento baseado no método e caminho
        if http_method == 'GET' and path == '/registros':
            return listar_registros()
        elif http_method == 'POST' and path == '/registros':
            return criar_registro(json.loads(event.get('body', '{}')))
        elif http_method == 'DELETE' and path.startswith('/registros/'):
            subdominio = path.split('/')[-1]
            return deletar_registro(subdominio)
        elif http_method == 'GET' and path == '/info':
            return obter_info()
        else:
            return {
                'statusCode': 404,
                'body': json.dumps({'erro': 'Rota não encontrada'})
            }
            
    except Exception as e:
        return {
            'statusCode': 500,
            'body': json.dumps({'erro': str(e)})
        }

def listar_registros():
    """Lista todos os registros DNS, compatível com react-admin (ra-data-simple-rest)"""
    try:
        response = table.scan()
        registros = response.get('Items', [])
        qtd = len(registros)
        content_range = f"registros 0-{qtd-1}/{qtd}" if qtd > 0 else "registros 0-0/0"

        return {
            'statusCode': 200,
            'headers': {
                'Content-Range': content_range,
                'Access-Control-Expose-Headers': 'Content-Range'
            },
            'body': json.dumps({
                'registros': registros,
                'nameservers': NAMESERVERS,
                'zona_id': ZONA_ID
            })
        }
    except Exception as e:
        return {
            'statusCode': 500,
            'body': json.dumps({'erro': f'Erro ao listar registros: {str(e)}'})
        }

def criar_registro(dados):
    """Cria um novo registro DNS"""
    try:
        subdominio = dados.get('subdominio')
        endereco_ip = dados.get('endereco_ip')
        
        if not subdominio or not endereco_ip:
            return {
                'statusCode': 400,
                'body': json.dumps({'erro': 'Subdomínio e endereço IP são obrigatórios'})
            }
        
        # Criar registro no Route 53
        change_batch = {
            'Changes': [
                {
                    'Action': 'UPSERT',
                    'ResourceRecordSet': {
                        'Name': f'{subdominio}.{NAMESERVERS[0].split(".")[-2]}.{NAMESERVERS[0].split(".")[-1]}',
                        'Type': 'A',
                        'TTL': TTL_DNS,
                        'ResourceRecords': [
                            {'Value': endereco_ip}
                        ]
                    }
                }
            ]
        }
        
        route53.change_resource_record_sets(
            HostedZoneId=ZONA_ID,
            ChangeBatch=change_batch
        )
        
        # Salvar no DynamoDB
        table.put_item(
            Item={
                'subdominio': subdominio,
                'endereco_ip': endereco_ip,
                'data_criacao': datetime.now().isoformat()
            }
        )
        
        return {
            'statusCode': 201,
            'body': json.dumps({
                'mensagem': 'Registro criado com sucesso',
                'nameservers': NAMESERVERS,
                'zona_id': ZONA_ID
            })
        }
    except Exception as e:
        return {
            'statusCode': 500,
            'body': json.dumps({'erro': f'Erro ao criar registro: {str(e)}'})
        }

def deletar_registro(subdominio):
    """Deleta um registro DNS"""
    try:
        # Buscar registro no DynamoDB
        response = table.get_item(
            Key={'subdominio': subdominio}
        )
        
        if 'Item' not in response:
            return {
                'statusCode': 404,
                'body': json.dumps({'erro': 'Registro não encontrado'})
            }
        
        endereco_ip = response['Item']['endereco_ip']
        
        # Deletar registro no Route 53
        change_batch = {
            'Changes': [
                {
                    'Action': 'DELETE',
                    'ResourceRecordSet': {
                        'Name': f'{subdominio}.{NAMESERVERS[0].split(".")[-2]}.{NAMESERVERS[0].split(".")[-1]}',
                        'Type': 'A',
                        'TTL': TTL_DNS,
                        'ResourceRecords': [
                            {'Value': endereco_ip}
                        ]
                    }
                }
            ]
        }
        
        route53.change_resource_record_sets(
            HostedZoneId=ZONA_ID,
            ChangeBatch=change_batch
        )
        
        # Deletar do DynamoDB
        table.delete_item(
            Key={'subdominio': subdominio}
        )
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'mensagem': 'Registro deletado com sucesso',
                'nameservers': NAMESERVERS,
                'zona_id': ZONA_ID
            })
        }
    except Exception as e:
        return {
            'statusCode': 500,
            'body': json.dumps({'erro': f'Erro ao deletar registro: {str(e)}'})
        }

def obter_info():
    """Retorna informações sobre a zona DNS"""
    try:
        return {
            'statusCode': 200,
            'body': json.dumps({
                'nameservers': NAMESERVERS,
                'zona_id': ZONA_ID,
                'ttl': TTL_DNS
            })
        }
    except Exception as e:
        return {
            'statusCode': 500,
            'body': json.dumps({'erro': f'Erro ao obter informações: {str(e)}'})
        } 