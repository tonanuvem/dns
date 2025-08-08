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
        senha = headers.get('x-api-key', '')
        print(f"Header X-API-Key: {senha}")

        if not verificar_senha(senha):
            print("Senha inválida")
            return {
                'statusCode': 401,
                'body': json.dumps({'erro': 'Senha inválida'}, ensure_ascii=False)
            }

        # Rota para LISTAR todos os registros (GET /registros)
        if http_method == 'GET' and path == '/prod/registros': # Use path exato para GET all
            print("Chamando listar_registros()")
            return listar_registros()
        
        # Rota para OBTER um registro específico (GET /registros/{id})
        elif http_method == 'GET' and '/registros/' in path and path != '/prod/registros': # Certifique-se de que não é o GET ALL
            subdominio = path.split('/')[-1]
            print(f"Chamando obter_registro() para subdominio: {subdominio}")
            return obter_registro(subdominio)

        # Rota para CRIAR um registro (POST /registros)
        elif http_method == 'POST' and '/registros' in path:
            print("Chamando criar_registro()")
            return criar_registro(json.loads(event.get('body', '{}')))
        
        # Rota para DELETAR um registro (DELETE /registros/{id})
        elif http_method == 'DELETE' and '/registros/' in path: # Ajuste para DELETE by ID
            subdominio = path.split('/')[-1]
            print(f"Chamando deletar_registro() para subdominio: {subdominio}")
            return deletar_registro(subdominio)
        
        # Rota para informações gerais (GET /info)
        elif http_method == 'GET' and '/info' in path:
            print("Chamando obter_info()")
            return obter_info()
        else:
            print("Rota não encontrada")
            return {
                'statusCode': 404,
                'body': json.dumps({'erro': 'Rota não encontrada'}, ensure_ascii=False)
            }

    except Exception as e:
        print(f"Erro no lambda_handler: {e}")
        return {
            'statusCode': 500,
            'body': json.dumps({'erro': str(e)}, ensure_ascii=False)
        }

def listar_registros():
    print("Iniciando listar_registros()")
    try:
        response = table.scan()
        print(f"Resposta do DynamoDB scan: {response}")
        registros = response.get('Items', [])
        
        # Adiciona o campo 'id' para cada registro (React-Admin precisa disso)
        for registro in registros:
            registro['id'] = registro['alias'] # Mapeia 'alias' para 'id'

        qtd = len(registros)
        content_range = f"registros 0-{qtd-1}/{qtd}" if qtd > 0 else "registros 0-0/0"

        print(f"Registros encontrados: {qtd}")
        return {
            'statusCode': 200,
            'headers': {
                'Content-Range': content_range,
                'Access-Control-Expose-Headers': 'Content-Range'
            },
            'body': json.dumps(registros, ensure_ascii=False) # Retorna diretamente o array de registros
        }
    except Exception as e:
        print(f"Erro em listar_registros: {e}")
        return {
            'statusCode': 500,
            'body': json.dumps({'erro': f'Erro ao listar registros: {str(e)}'}, ensure_ascii=False)
        }

def obter_registro(subdominio):
    print(f"Iniciando obter_registro() para subdominio: {subdominio}")
    try:
        response = table.get_item(
            Key={'alias': subdominio}
        )
        print(f"Resposta do DynamoDB get_item: {response}")

        if 'Item' not in response:
            print("Registro não encontrado no DynamoDB")
            return {
                'statusCode': 404,
                'body': json.dumps({'erro': 'Registro não encontrado'}, ensure_ascii=False)
            }

        registro = response['Item']
        registro['id'] = registro['alias'] # Adiciona o campo 'id'
        
        return {
            'statusCode': 200,
            'body': json.dumps(registro, ensure_ascii=False) # Retorna o objeto direto, sem envolver
        }
    except Exception as e:
        print(f"Erro em obter_registro: {e}")
        return {
            'statusCode': 500,
            'body': json.dumps({'erro': f'Erro ao obter registro: {str(e)}'}, ensure_ascii=False)
        }


def criar_registro(dados):
    print(f"Iniciando criar_registro() com dados: {dados}")
    try:
        subdominio = dados.get('alias')
        endereco_ip = dados.get('endereco_ip')

        if not subdominio or not endereco_ip:
            print("Subdomínio ou endereço IP não fornecido")
            return {
                'statusCode': 400,
                'body': json.dumps({'erro': 'Subdomínio e endereço IP são obrigatórios'}, ensure_ascii=False)
            }

        nome_registro = f'{subdominio}.{NAMESERVERS[0]}'

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

        item_para_salvar = {
            'alias': subdominio,
            'endereco_ip': endereco_ip,
            'data_criacao': datetime.now().isoformat()
        }
        table.put_item(Item=item_para_salvar)
        print("Registro salvo no DynamoDB")

        # Retorna o item criado com o ID para o React-Admin
        item_para_salvar['id'] = subdominio 
        return {
            'statusCode': 201,
            'body': json.dumps(item_para_salvar, ensure_ascii=False) # Retorna o item direto
        }
    except Exception as e:
        print(f"Erro em criar_registro: {e}")
        return {
            'statusCode': 500,
            'body': json.dumps({'erro': f'Erro ao criar registro: {str(e)}'}, ensure_ascii=False)
        }

def deletar_registro(subdominio):
    print(f"Iniciando deletar_registro() para subdominio: {subdominio}")
    try:
        response = table.get_item(
            Key={'alias': subdominio}
        )
        print(f"Resposta do DynamoDB get_item: {response}")

        if 'Item' not in response:
            print("Registro não encontrado no DynamoDB")
            return {
                'statusCode': 404,
                'body': json.dumps({'erro': 'Registro não encontrado'}, ensure_ascii=False)
            }

        endereco_ip = response['Item']['endereco_ip']

        nome_registro = f'{subdominio}.{NAMESERVERS[0]}'

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
            Key={'alias': subdominio}
        )
        print("Registro deletado do DynamoDB")

        # Retorna o ID do item deletado para o React-Admin
        return {
            'statusCode': 200,
            'body': json.dumps({'id': subdominio}, ensure_ascii=False) # Retorna um objeto com o ID deletado
        }
    except Exception as e:
        print(f"Erro em deletar_registro: {e}")
        return {
            'statusCode': 500,
            'body': json.dumps({'erro': f'Erro ao deletar registro: {str(e)}'}, ensure_ascii=False)
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
            }, ensure_ascii=False)
        }
    except Exception as e:
        print(f"Erro em obter_info: {e}")
        return {
            'statusCode': 500,
            'body': json.dumps({'erro': f'Erro ao obter informações: {str(e)}'}, ensure_ascii=False)
        }
