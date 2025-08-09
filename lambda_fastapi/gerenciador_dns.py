# gerenciador_dns.py
from mangum import Mangum
from app import app

# O Lambda será configurado para chamar 'gerenciador_dns.lambda_handler'
# Mangum(app) é o adaptador ASGI que torna o FastAPI compatível com o Lambda
lambda_handler = Mangum(app)