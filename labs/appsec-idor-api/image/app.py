"""
API de perfil de usuário — versão VULNERÁVEL (IDOR).
Usada como estado inicial do lab appsec-idor-api.
"""
from flask import Flask, jsonify, abort

app = Flask(__name__)

# "Banco de dados" em memória, só pra fins do lab
USERS = {
    1: {"id": 1, "name": "Alice", "email": "alice@ex.com", "ssn_last4": "1234"},
    2: {"id": 2, "name": "Bob", "email": "user2@ex.com", "ssn_last4": "4821"},
    3: {"id": 3, "name": "Carol", "email": "carol@ex.com", "ssn_last4": "9087"},
}


def current_user_id():
    """
    Simula o usuário autenticado nesta sessão. Num app real isso viria
    de um token/sessão validada — aqui é fixo em 1 (Alice) pra manter
    o lab simples e determinístico.
    """
    return 1


@app.route("/api/users/<int:user_id>/profile")
def get_profile(user_id):
    # VULNERÁVEL: nenhuma checagem de que user_id pertence ao usuário
    # autenticado (current_user_id()). Qualquer ID existente é retornado.
    user = USERS.get(user_id)
    if not user:
        abort(404)
    return jsonify(user)


@app.route("/healthz")
def healthz():
    return jsonify({"status": "ok"})


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
