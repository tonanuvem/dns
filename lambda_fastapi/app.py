# app.py
from fastapi import FastAPI, Depends, Header, HTTPException
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import os
import boto3
import hmac
from datetime import datetime

# --- Inicialização da aplicação e clientes AWS ---
app = FastAPI(
    title="API de Gerenciamento de DNS",
    description="Uma API para gerenciar registros DNS no AWS Route53.",
    version="1.0.0"
)

# --- Configuração do Middleware CORS ---
# Permite que seu frontend (React-Admin) acesse a API
# O "Access-Control-Expose-Headers" é crucial para que o React-Admin leia o Content-Range
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Substitua por seu domínio em produção
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
    expose_headers=["Content-Range"]
)

try:
    dynamodb = boto3.resource('dynamodb')
    route53 = boto3.client('route53')
    table = dynamodb.Table(os.environ['DYNAMODB_TABLE'])

    SENHA_API = os.environ['SENHA_API']
    TTL_DNS = int(os.environ['TTL_DNS'])
    NAMESERVERS = os.environ['NAMESERVERS'].split(',')
    ZONA_ID = os.environ['ZONA_ID']
except KeyError as e:
    raise RuntimeError(f"Variável de ambiente {e} não configurada.")
except Exception as e:
    raise RuntimeError(f"Erro ao inicializar clientes AWS: {e}")

# --- Modelos Pydantic para validação ---
class Registro(BaseModel):
    subdominio: str
    endereco_ip: str

# --- Lógica de Validação da API Key ---
def verificar_senha(x_api_key: str = Header(...)):
    if not hmac.compare_digest(x_api_key, SENHA_API):
        raise HTTPException(status_code=401, detail="Senha inválida")
    return True

# --- Rotas da API ---

@app.get("/info")
def obter_info(api_key_valida: bool = Depends(verificar_senha)):
    return {
        "nameservers": NAMESERVERS,
        "zona_id": ZONA_ID,
        "ttl": TTL_DNS
    }

@app.get("/registros")
def listar_registros(api_key_valida: bool = Depends(verificar_senha)):
    try:
        response = table.scan()
        registros = response.get('Items', [])
        qtd = len(registros)
        
        # Constrói o header Content-Range no formato esperado pelo React-Admin
        content_range = f"registros 0-{qtd-1}/{qtd}" if qtd > 0 else "registros 0-0/0"
        
        # Retorna uma JSONResponse customizada com o header Content-Range
        return JSONResponse(
            content=registros,
            headers={"Content-Range": content_range}
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Erro ao listar registros: {str(e)}")

@app.post("/registros", status_code=201)
def criar_registro(registro: Registro, api_key_valida: bool = Depends(verificar_senha)):
    try:
        nome_registro = f'{registro.subdominio}.{NAMESERVERS[0]}'

        change_batch = {
            'Changes': [{'Action': 'UPSERT', 'ResourceRecordSet': {'Name': nome_registro, 'Type': 'A', 'TTL': TTL_DNS, 'ResourceRecords': [{'Value': registro.endereco_ip}]}}]
        }
        route53.change_resource_record_sets(HostedZoneId=ZONA_ID, ChangeBatch=change_batch)
        table.put_item(Item={'alias': registro.subdominio, 'endereco_ip': registro.endereco_ip, 'data_criacao': datetime.now().isoformat()})

        return {"mensagem": "Registro criado com sucesso", "subdominio": registro.subdominio, "nameservers": NAMESERVERS, "zona_id": ZONA_ID}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Erro ao criar registro: {str(e)}")

@app.delete("/registros/{subdominio}")
def deletar_registro(subdominio: str, api_key_valida: bool = Depends(verificar_senha)):
    try:
        response = table.get_item(Key={'alias': subdominio})
        if 'Item' not in response:
            raise HTTPException(status_code=404, detail="Registro não encontrado")

        endereco_ip = response['Item']['endereco_ip']
        nome_registro = f'{subdominio}.{NAMESERVERS[0]}'

        change_batch = {
            'Changes': [{'Action': 'DELETE', 'ResourceRecordSet': {'Name': nome_registro, 'Type': 'A', 'TTL': TTL_DNS, 'ResourceRecords': [{'Value': endereco_ip}]}}]
        }
        route53.change_resource_record_sets(HostedZoneId=ZONA_ID, ChangeBatch=change_batch)
        table.delete_item(Key={'alias': subdominio})

        return {"mensagem": "Registro deletado com sucesso", "subdominio": subdominio, "nameservers": NAMESERVERS, "zona_id": ZONA_ID}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Erro ao deletar registro: {str(e)}")