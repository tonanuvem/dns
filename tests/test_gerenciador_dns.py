"""Teste local do gerenciador_dns, sem AWS e sem dependencias.

    python3 tests/test_gerenciador_dns.py

Instala um boto3 falso antes de importar a funcao, entao roda em
qualquer maquina com Python 3 -- inclusive na VM do lab, antes do
deploy. Sai com codigo 1 se algum caso falhar.

Cobre o que quebrou em producao: as duas formas de path (com e sem o
prefixo do stage), o PUT da tela de edicao, os aliases reservados da
zona compartilhada e o DELETE de um registro ja removido do Route 53.
"""
import json
import os
import sys
import types

# --- boto3 falso, instalado antes do import do modulo ---
ESTADO = {"itens": {}, "r53": []}


class FakeTable:
    def scan(self, **kw):
        return {"Items": [dict(v) for v in ESTADO["itens"].values()]}

    def get_item(self, Key):
        item = ESTADO["itens"].get(Key["alias"])
        return {"Item": dict(item)} if item else {}

    def put_item(self, Item):
        ESTADO["itens"][Item["alias"]] = dict(Item)

    def delete_item(self, Key):
        ESTADO["itens"].pop(Key["alias"], None)


class FakeDynamo:
    def Table(self, nome):
        return FakeTable()


class FakeR53:
    def change_resource_record_sets(self, HostedZoneId, ChangeBatch):
        ch = ChangeBatch["Changes"][0]
        ESTADO["r53"].append((ch["Action"], ch["ResourceRecordSet"]["Name"]))
        return {}


fake_boto3 = types.ModuleType("boto3")
fake_boto3.resource = lambda *a, **k: FakeDynamo()
fake_boto3.client = lambda *a, **k: FakeR53()
sys.modules["boto3"] = fake_boto3

fake_exc = types.ModuleType("botocore.exceptions")


class ClientError(Exception):
    def __init__(self, response, op):
        self.response = response


fake_exc.ClientError = ClientError
fake_botocore = types.ModuleType("botocore")
fake_botocore.exceptions = fake_exc
sys.modules["botocore"] = fake_botocore
sys.modules["botocore.exceptions"] = fake_exc

os.environ.update({
    "DYNAMODB_TABLE": "registros-dns-aluno",
    "SENHA_API": "aluno",
    "TTL_DNS": "60",
    "ZONA_ID": "Z09807023UJAU2NOXGU3L",
    "NAMESERVERS": "aluno.lab.tonanuvem.com",
})

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "lambda"))
import gerenciador_dns as g  # noqa: E402


def chamar(metodo, path, corpo=None, stage="prod", senha="aluno", token_header=None):
    evento = {
        "httpMethod": metodo,
        "path": path,
        "headers": {"X-Api-Key": senha},
        "requestContext": {"stage": stage},
    }
    if token_header is not None:
        evento["headers"]["x-dns-token"] = token_header
    if corpo is not None:
        evento["body"] = json.dumps(corpo)
    return g.lambda_handler(evento, None)


FALHAS = []


def checar(nome, cond, extra=""):
    print(f"{'ok  ' if cond else 'FALHA'} {nome} {extra if not cond else ''}")
    if not cond:
        FALHAS.append(nome)


# 1. Rota com prefixo de stage (URL de invoke)
r = chamar("GET", "/prod/registros")
checar("GET /prod/registros -> 200", r["statusCode"] == 200, r)

# 2. Mesma rota SEM stage (dominio personalizado) -- era o 404
r = chamar("GET", "/registros", stage="prod")
checar("GET /registros (dominio custom) -> 200", r["statusCode"] == 200, r)
checar("Content-Range presente", "Content-Range" in r["headers"], r["headers"])

# 3. Senha errada
r = chamar("GET", "/registros", senha="errada")
checar("senha errada -> 401", r["statusCode"] == 401, r)

# 4. Senha ausente
r = g.lambda_handler({"httpMethod": "GET", "path": "/registros", "headers": {}}, None)
checar("sem header -> 401", r["statusCode"] == 401, r)

# 5. Criar
r = chamar("POST", "/prod/registros", {"alias": "joao", "endereco_ip": "1.2.3.4"})
checar("POST valido -> 201", r["statusCode"] == 201, r)
checar("R53 recebeu UPSERT joao", ("UPSERT", "joao.aluno.lab.tonanuvem.com") in ESTADO["r53"], ESTADO["r53"])

# 6. Duplicado
r = chamar("POST", "/prod/registros", {"alias": "joao", "endereco_ip": "5.6.7.8"})
checar("POST duplicado -> 409", r["statusCode"] == 409, r)

# 7. Alias reservado
for reservado in ("api", "www", "www2", "www7", "https", "https7"):
    r = chamar("POST", "/registros", {"alias": reservado, "endereco_ip": "1.2.3.4"})
    checar(f"alias reservado '{reservado}' -> 400", r["statusCode"] == 400, r)

# 8. Alias invalido
for ruim in ("joao.silva", "-joao", "JOAO!", "a" * 64, ""):
    r = chamar("POST", "/registros", {"alias": ruim, "endereco_ip": "1.2.3.4"})
    checar(f"alias invalido {ruim!r} -> 400", r["statusCode"] == 400, r)

# 9. IP invalido
for ip in ("999.1.1.1", "abc", "2001:db8::1"):
    r = chamar("POST", "/registros", {"alias": "maria", "endereco_ip": ip})
    checar(f"ip invalido {ip!r} -> 400", r["statusCode"] == 400, r)

# 10. Maiuscula normalizada
r = chamar("POST", "/registros", {"alias": "MARIA", "endereco_ip": "9.9.9.9"})
checar("alias maiusculo -> 201 normalizado", r["statusCode"] == 201 and json.loads(r["body"])["alias"] == "maria", r)

# 11. PUT (edicao do React-Admin) -- antes caia em 404
r = chamar("PUT", "/prod/registros/joao", {"alias": "joao", "endereco_ip": "8.8.8.8"})
checar("PUT -> 200", r["statusCode"] == 200, r)
checar("PUT trocou o IP", ESTADO["itens"]["joao"]["endereco_ip"] == "8.8.8.8", ESTADO["itens"]["joao"])
checar("PUT preservou data_criacao", "data_criacao" in ESTADO["itens"]["joao"])

# 12. PUT em inexistente
r = chamar("PUT", "/registros/naoexiste", {"endereco_ip": "8.8.8.8"})
checar("PUT inexistente -> 404", r["statusCode"] == 404, r)

# 13. GET por id
r = chamar("GET", "/registros/joao")
checar("GET /registros/joao -> 200 com id", r["statusCode"] == 200 and json.loads(r["body"])["id"] == "joao", r)

# 14. Listagem paginada/ordenada
r = chamar("GET", "/registros")
itens = json.loads(r["body"])
checar("listagem ordenada", [i["alias"] for i in itens] == ["joao", "maria"], itens)
checar("Content-Range correto", r["headers"]["Content-Range"] == "registros 0-1/2", r["headers"])

# 15. DELETE
r = chamar("DELETE", "/prod/registros/joao")
checar("DELETE -> 200", r["statusCode"] == 200, r)
checar("item removido", "joao" not in ESTADO["itens"])

# 16. DELETE tolerante: R53 ja nao tem o registro
ESTADO["itens"]["orfao"] = {"alias": "orfao", "endereco_ip": "1.1.1.1"}


def falhar_invalid_change_batch(HostedZoneId, ChangeBatch):
    raise ClientError({"Error": {"Code": "InvalidChangeBatch"}}, "change")


g.route53.change_resource_record_sets = falhar_invalid_change_batch
r = chamar("DELETE", "/registros/orfao")
checar("DELETE com registro orfao -> 200", r["statusCode"] == 200, r)
checar("orfao saiu do DynamoDB", "orfao" not in ESTADO["itens"])
g.route53.change_resource_record_sets = FakeR53().change_resource_record_sets

# 17. OPTIONS (preflight)
r = chamar("OPTIONS", "/registros", senha="qualquer")
checar("OPTIONS -> 200 sem exigir senha", r["statusCode"] == 200, r)

# 18. /info
r = chamar("GET", "/prod/info")
checar("GET /info -> 200", r["statusCode"] == 200 and json.loads(r["body"])["dominio"] == "aluno.lab.tonanuvem.com", r)

# 19. Rota desconhecida
r = chamar("GET", "/prod/outra")
checar("rota desconhecida -> 404", r["statusCode"] == 404, r)

# 20. JSON invalido
ev = {"httpMethod": "POST", "path": "/registros", "headers": {"x-api-key": "aluno"}, "body": "{nao-json"}
r = g.lambda_handler(ev, None)
checar("body nao-JSON -> 400", r["statusCode"] == 400, r)

# ============================================================
# POSSE DO ALIAS (token do dns.sh)
# ============================================================

ESTADO["itens"].clear()

# 21. Criar COM token
r = chamar("POST", "/registros", {"alias": "pedro", "endereco_ip": "1.1.1.1", "token": "segredo-do-pedro"})
checar("POST com token -> 201", r["statusCode"] == 201, r)
checar("token_hash gravado", "token_hash" in ESTADO["itens"]["pedro"], ESTADO["itens"]["pedro"])
checar("token_hash NAO volta na resposta", "token_hash" not in json.loads(r["body"]), r["body"])

# 22. Listagem nao vaza o hash
r = chamar("GET", "/registros")
checar("listagem nao vaza token_hash", all("token_hash" not in i for i in json.loads(r["body"])), r["body"])

# 23. GET por id nao vaza o hash
r = chamar("GET", "/registros/pedro")
checar("GET por id nao vaza token_hash", "token_hash" not in json.loads(r["body"]), r["body"])

# 24. PUT sem token -> 403
r = chamar("PUT", "/registros/pedro", {"endereco_ip": "2.2.2.2"})
checar("PUT sem token -> 403", r["statusCode"] == 403, r)
checar("IP nao mudou", ESTADO["itens"]["pedro"]["endereco_ip"] == "1.1.1.1")

# 25. PUT com token errado -> 403
r = chamar("PUT", "/registros/pedro", {"endereco_ip": "2.2.2.2", "token": "chute"})
checar("PUT com token errado -> 403", r["statusCode"] == 403, r)

# 26. PUT com token certo, no corpo (re-registro de aula nova)
r = chamar("PUT", "/registros/pedro", {"endereco_ip": "2.2.2.2", "token": "segredo-do-pedro"})
checar("PUT com token certo -> 200", r["statusCode"] == 200, r)
checar("IP atualizado", ESTADO["itens"]["pedro"]["endereco_ip"] == "2.2.2.2")
checar("dono preservado no PUT", "token_hash" in ESTADO["itens"]["pedro"], ESTADO["itens"]["pedro"])

# 27. PUT com token pelo header
r = chamar("PUT", "/registros/pedro", {"endereco_ip": "3.3.3.3"}, token_header="segredo-do-pedro")
checar("PUT com token no header -> 200", r["statusCode"] == 200, r)

# 28. DELETE sem token -> 403
r = chamar("DELETE", "/registros/pedro")
checar("DELETE sem token -> 403", r["statusCode"] == 403, r)
checar("registro continua", "pedro" in ESTADO["itens"])

# 29. DELETE com token pelo header -> 200
r = chamar("DELETE", "/registros/pedro", token_header="segredo-do-pedro")
checar("DELETE com token no header -> 200", r["statusCode"] == 200, r)
checar("registro removido", "pedro" not in ESTADO["itens"])

# 30. Registro SEM dono continua editavel sem token (React-Admin)
chamar("POST", "/registros", {"alias": "semdono", "endereco_ip": "4.4.4.4"})
r = chamar("PUT", "/registros/semdono", {"endereco_ip": "5.5.5.5"})
checar("PUT em registro sem dono -> 200", r["statusCode"] == 200, r)
r = chamar("DELETE", "/registros/semdono")
checar("DELETE em registro sem dono -> 200", r["statusCode"] == 200, r)

print()
print("FALHAS:", FALHAS if FALHAS else "nenhuma")
sys.exit(1 if FALHAS else 0)
