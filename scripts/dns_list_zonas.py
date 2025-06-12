#!/usr/bin/env python3

import boto3
import json
import sys
from pathlib import Path

def listar_zonas():
    """Lista todas as zonas hospedadas no Route 53"""
    try:
        route53 = boto3.client('route53')
        response = route53.list_hosted_zones()
        
        zonas = []
        for zona in response['HostedZones']:
            zonas.append({
                'id': zona['Id'].split('/')[-1],
                'nome': zona['Name'],
                'comentario': zona.get('Config', {}).get('Comment', ''),
                'privada': zona.get('Config', {}).get('PrivateZone', False)
            })
        
        return zonas
    except Exception as e:
        print(f"Erro ao listar zonas: {str(e)}")
        return None

def obter_zone_id(nome_zona):
    """Obtém o ID de uma zona específica pelo nome"""
    zonas = listar_zonas()
    if not zonas:
        return None
    
    # Remover ponto final se existir
    nome_zona = nome_zona.rstrip('.')
    
    # Procurar pela zona
    for zona in zonas:
        if zona['nome'].rstrip('.') == nome_zona:
            return zona['id']
    
    return None

def main():
    # Se um nome de zona for fornecido, retorna apenas o ID
    if len(sys.argv) > 1:
        nome_zona = sys.argv[1]
        zone_id = obter_zone_id(nome_zona)
        if zone_id:
            print(zone_id)
            return 0
        else:
            print(f"Zona '{nome_zona}' não encontrada", file=sys.stderr)
            return 1
    
    # Caso contrário, lista todas as zonas
    zonas = listar_zonas()
    if zonas:
        print(json.dumps(zonas, indent=2))
        return 0
    else:
        print("Nenhuma zona encontrada", file=sys.stderr)
        return 1

if __name__ == "__main__":
    sys.exit(main()) 