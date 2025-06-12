#!/usr/bin/env python3

import os
import sys
import json
import shutil
from pathlib import Path

def validar_entrada(nome_aluno, senha):
    """Valida os parâmetros de entrada"""
    if not nome_aluno or not senha:
        print("Erro: nome_aluno e senha são obrigatórios")
        sys.exit(1)
    
    if not nome_aluno.isalnum():
        print("Erro: nome_aluno deve conter apenas letras e números")
        sys.exit(1)
    
    if len(senha) < 8:
        print("Erro: senha deve ter pelo menos 8 caracteres")
        sys.exit(1)

def configurar_terraform(nome_aluno, senha):
    """Configura as variáveis do Terraform"""
    # Caminho para o arquivo de exemplo
    tf_vars_example = Path("terraform/terraform.tfvars.example")
    tf_vars = Path("terraform/terraform.tfvars")
    
    if not tf_vars_example.exists():
        print(f"Erro: Arquivo {tf_vars_example} não encontrado")
        sys.exit(1)
    
    # Ler o arquivo de exemplo
    with open(tf_vars_example, 'r') as f:
        conteudo = f.read()
    
    # Substituir as variáveis
    conteudo = conteudo.replace('nome_aluno = "joao"', f'nome_aluno = "{nome_aluno}"')
    conteudo = conteudo.replace('senha_compartilhada = "sua_senha_segura_aqui"', f'senha_compartilhada = "{senha}"')
    conteudo = conteudo.replace('Aluno       = "joao"', f'Aluno       = "{nome_aluno}"')
    
    # Salvar o novo arquivo
    with open(tf_vars, 'w') as f:
        f.write(conteudo)
    
    print(f"✓ Arquivo {tf_vars} configurado com sucesso")

def configurar_frontend(nome_aluno):
    """Configura as variáveis do frontend"""
    # Criar arquivo .env para o frontend
    env_file = Path("frontend/.env")
    
    conteudo = f"""REACT_APP_API_URL=https://api.{nome_aluno}.lab.tonanuvem.com
REACT_APP_TITLE=Gerenciador DNS - {nome_aluno}
"""
    
    with open(env_file, 'w') as f:
        f.write(conteudo)
    
    print(f"✓ Arquivo {env_file} configurado com sucesso")

def configurar_lambda(nome_aluno, senha):
    """Configura as variáveis da Lambda"""
    # Criar arquivo .env para a Lambda
    env_file = Path("lambda/.env")
    
    conteudo = f"""DYNAMODB_TABLE=registros-dns-{nome_aluno}
SENHA_API={senha}
TTL_DNS=60
"""
    
    with open(env_file, 'w') as f:
        f.write(conteudo)
    
    print(f"✓ Arquivo {env_file} configurado com sucesso")

def criar_arquivo_env(nome_aluno, senha):
    """Cria arquivo .env na raiz do projeto"""
    env_file = Path(".env")
    
    conteudo = f"""NOME_ALUNO={nome_aluno}
SENHA_API={senha}
DOMINIO_BASE=lab.tonanuvem.com
TTL_DNS=60
"""
    
    with open(env_file, 'w') as f:
        f.write(conteudo)
    
    print(f"✓ Arquivo {env_file} configurado com sucesso")

def main():
    # Verificar argumentos
    if len(sys.argv) != 3:
        print("Uso: python configurar_aluno.py <nome_aluno> <senha>")
        sys.exit(1)
    
    nome_aluno = sys.argv[1]
    senha = sys.argv[2]
    
    # Validar entrada
    validar_entrada(nome_aluno, senha)
    
    print(f"\nConfigurando ambiente para o aluno: {nome_aluno}")
    print("=" * 50)
    
    # Configurar cada componente
    configurar_terraform(nome_aluno, senha)
    configurar_frontend(nome_aluno)
    configurar_lambda(nome_aluno, senha)
    criar_arquivo_env(nome_aluno, senha)
    
    print("\nConfiguração concluída com sucesso!")
    print("\nPróximos passos:")
    print("1. Execute 'cd terraform && terraform init'")
    print("2. Execute 'cd terraform && terraform plan'")
    print("3. Execute 'cd terraform && ./deploy.sh'")
    print("\nApós o deploy, você poderá acessar:")
    print(f"- Frontend: https://{nome_aluno}.lab.tonanuvem.com")
    print(f"- API: https://api.{nome_aluno}.lab.tonanuvem.com")

if __name__ == "__main__":
    main() 