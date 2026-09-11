"""
Implementação mínima de JWT (HS256), com a mesma interface básica da
PyJWT (encode/decode), criada só pra este lab. Motivo de não usar a
PyJWT de verdade: versões atuais da lib já fecham a vulnerabilidade por
padrão (exigem 'algorithms' explícito), o que tornaria o cenário
"vulnerável" difícil de reproduzir de forma determinística. Aqui a
vulnerabilidade é intencional e controlada — decode() sem o parâmetro
'algorithms' confia cegamente no campo "alg" que vem DENTRO do próprio
token, exatamente o antipadrão real que originou esse tipo de CVE em
bibliotecas JWT de várias linguagens.
"""
import base64
import hashlib
import hmac
import json


def _b64url_encode(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode("ascii")


def _b64url_decode(data: str) -> bytes:
    padding = "=" * (-len(data) % 4)
    return base64.urlsafe_b64decode(data + padding)


def _sign(header_b64: str, payload_b64: str, key: str) -> str:
    msg = f"{header_b64}.{payload_b64}".encode("ascii")
    sig = hmac.new(key.encode("utf-8"), msg, hashlib.sha256).digest()
    return _b64url_encode(sig)


def encode(payload: dict, key: str, algorithm: str = "HS256") -> str:
    header = {"alg": algorithm, "typ": "JWT"}
    header_b64 = _b64url_encode(json.dumps(header).encode("utf-8"))
    payload_b64 = _b64url_encode(json.dumps(payload).encode("utf-8"))
    sig_b64 = _sign(header_b64, payload_b64, key)
    return f"{header_b64}.{payload_b64}.{sig_b64}"


class InvalidTokenError(Exception):
    pass


def decode(token: str, key: str, algorithms=None) -> dict:
    """
    Se 'algorithms' for None (VULNERÁVEL): confia no campo "alg" que
    vem dentro do próprio token pra decidir se verifica assinatura.
    Um token com alg=none passa direto, sem checagem nenhuma.

    Se 'algorithms' for uma lista (CORRIGIDO): só aceita token cujo
    "alg" declarado esteja nessa lista, e SEMPRE verifica a assinatura
    pro algoritmo esperado — nunca confia no que o token afirma sozinho.
    """
    try:
        header_b64, payload_b64, sig_b64 = token.split(".")
        header = json.loads(_b64url_decode(header_b64))
        payload = json.loads(_b64url_decode(payload_b64))
    except (ValueError, json.JSONDecodeError):
        raise InvalidTokenError("token malformado")

    alg = header.get("alg", "none")

    if algorithms is None:
        # Caminho vulnerável: o token manda no próprio algoritmo.
        if alg == "none":
            return payload
        if alg == "HS256":
            expected_sig = _sign(header_b64, payload_b64, key)
            if not hmac.compare_digest(expected_sig, sig_b64):
                raise InvalidTokenError("assinatura inválida")
            return payload
        raise InvalidTokenError(f"algoritmo não suportado: {alg}")

    # Caminho corrigido: algoritmo tem que estar na allowlist, sempre
    # verificando de verdade — nunca aceita "none".
    if alg not in algorithms:
        raise InvalidTokenError(f"algoritmo '{alg}' não permitido")
    if alg == "HS256":
        expected_sig = _sign(header_b64, payload_b64, key)
        if not hmac.compare_digest(expected_sig, sig_b64):
            raise InvalidTokenError("assinatura inválida")
        return payload
    raise InvalidTokenError(f"algoritmo '{alg}' não implementado")
