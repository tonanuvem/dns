import json
import boto3
import os
import hashlib
import hmac
import base64
from datetime import datetime

try:
    # Configuração dos clientes AWS
    print("Inicializando clientes AWS...")
    dynamodb = boto3.resource('dynamodb')
    route53 = boto3.client('route53')
    table = dynamodb.Table(os.environ['DYNAMODB_TABLE'])

    # Configurações
    SENHA_API = os.environ['SENHA_API']
    TTL_DNS = int(os.environ['TTL_DNS'])
    NAMESERVERS = os.environ['NAMESERVERS'].split(',')
    ZONA_ID = os.environ['ZONA_ID']
except Exception as e:
    print(f"Erro ao inicializar configurações ou clientes AWS: {e}")
    raise

def verificar_senha(senha_fornecida):
    print(f"Verificando senha fornecida: {senha_fornecida}")
    return hmac.compare_digest(senha_fornecida, SENHA_API)

def lambda_handler(event, context):
    print(f"lambda_handler chamado com event: {event}")
    try:
        http_method = event.get('httpMethod', '')
        path = event.get('path', '')
        print(f"HTTP Method: {http_method}, Path: {path}")

        headers = event.get('headers', {})
        senha = headers.get('X-API-Key', '')
        print(f"Header X-API-Key: {senha}")

        if not verificar_senha(senha):
            print("Senha inválida")
            return {
                'statusCode': 401,
                'body': json.dumps({'erro': 'Senha inválida'})
            }

        if http_method == 'GET' and path == '/registros':
            print("Chamando listar_registros()")
            return listar_registros()
        elif http_method == 'POST' and path == '/registros':
            print("Chamando criar_registro()")
            return criar_registro(json.loads(event.get('body', '{}')))
        elif http_method == 'DELETE' and path.startswith('/registros/'):
            subdominio = path.split('/')[-1]
            print(f"Chamando deletar_registro() para subdominio: {subdominio}")
            return deletar_registro(subdominio)
        elif http_method == 'GET' and path == '/info':
            print("Chamando obter_info()")
            return obter_info()
        else:
            print("Rota não encontrada")
            return {
                'statusCode': 404,
                'body': json.dumps({'erro': 'Rota não encontrada'})
            }

    except Exception as e:
        print(f"Erro no lambda_handler: {e}")
        return {
            'statusCode': 500,
            'body': json.dumps({'erro': str(e)})
        }

def listar_registros():
    print("Iniciando listar_registros()")
    try:
        response = table.scan()
        print(f"Resposta do DynamoDB scan: {response}")
        registros = response.get('Items', [])
        qtd = len(registros)
        content_range = f"registros 0-{qtd-1}/{qtd}" if qtd > 0 else "registros 0-0/0"

        print(f"Registros encontrados: {qtd}")
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
        print(f"Erro em listar_registros: {e}")
        return {
            'statusCode': 500,
            'body': json.dumps({'erro': f'Erro ao listar registros: {str(e)}'})
        }

def criar_registro(dados):
    print(f"Iniciando criar_registro() com dados: {dados}")
    try:
        subdominio = dados.get('subdominio')
        endereco_ip = dados.get('endereco_ip')

        if not subdominio or not endereco_ip:
            print("Subdomínio ou endereço IP não fornecido")
            return {
                'statusCode': 400,
                'body': json.dumps({'erro': 'Subdomínio e endereço IP são obrigatórios'})
            }

        nome_registro = f'{subdominio}.{NAMESERVERS[0].split(".")[-2]}.{NAMESERVERS[0].split(".")[-1]}'
        print(f"Criando registro no Route53: {nome_registro} -> {endereco_ip}")

        change_batch = {
            'Changes': [
                {
                    'Action': 'UPSERT',
                    'ResourceRecordSet': {
                        'Name': nome_registro,
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
        print("Registro criado no Route53")

        table.put_item(
            Item={
                'subdominio': subdominio,
                'endereco_ip': endereco_ip,
                'data_criacao': datetime.now().isoformat()
            }
        )
        print("Registro salvo no DynamoDB")

        return {
            'statusCode': 201,
            'body': json.dumps({
                'mensagem': 'Registro criado com sucesso',
                'nameservers': NAMESERVERS,
                'zona_id': ZONA_ID
            })
        }
    except Exception as e:
        print(f"Erro em criar_registro: {e}")
        return {
            'statusCode': 500,
            'body': json.dumps({'erro': f'Erro ao criar registro: {str(e)}'})
        }

def deletar_registro(subdominio):
    print(f"Iniciando deletar_registro() para subdominio: {subdominio}")
    try:
        response = table.get_item(
            Key={'subdominio': subdominio}
        )
        print(f"Resposta do DynamoDB get_item: {response}")

        if 'Item' not in response:
            print("Registro não encontrado no DynamoDB")
            return {
                'statusCode': 404,
                'body': json.dumps({'erro': 'Registro não encontrado'})
            }

        endereco_ip = response['Item']['endereco_ip']
        nome_registro = f'{subdominio}.{NAMESERVERS[0].split(".")[-2]}.{NAMESERVERS[0].split(".")[-1]}'
        print(f"Deletando registro no Route53: {nome_registro} -> {endereco_ip}")

        change_batch = {
            'Changes': [
                {
                    'Action': 'DELETE',
                    'ResourceRecordSet': {
                        'Name': nome_registro,
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
        print("Registro deletado do Route53")

        table.delete_item(
            Key={'subdominio': subdominio}
        )
        print("Registro deletado do DynamoDB")

        return {
            'statusCode': 200,
            'body': json.dumps({
                'mensagem': 'Registro deletado com sucesso',
                'nameservers': NAMESERVERS,
                'zona_id': ZONA_ID
            })
        }
    except Exception as e:
        print(f"Erro em deletar_registro: {e}")
        return {
            'statusCode': 500,
            'body': json.dumps({'erro': f'Erro ao deletar registro: {str(e)}'})
        }

def obter_info():
    print("Iniciando obter_info()")
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
        print(f"Erro em obter_info: {e}")
        return {
            'statusCode': 500,
            'body': json.dumps({'erro': f'Erro ao obter informações: {str(e)}'})
        }