"""
API com autenticação JWT — versão VULNERÁVEL (aceita alg=none).
Estado inicial do lab appsec-jwt-alg-none.
"""
from flask import Flask, request, Response, jsonify, abort
import jwtlib as jwt

app = Flask(__name__)

SECRET_KEY = "chave-secreta-do-servidor-nao-compartilhe"


@app.route("/login", methods=["POST"])
def login():
    user = request.form.get("user", "anonimo")
    token = jwt.encode({"user": user, "role": "user"}, SECRET_KEY)
    return Response(token, mimetype="text/plain")


@app.route("/admin")
def admin():
    auth = request.headers.get("Authorization", "")
    if not auth.startswith("Bearer "):
        abort(401)
    token = auth[len("Bearer "):]

    try:
        # VULNERÁVEL: sem o parâmetro 'algorithms', o decode confia no
        # algoritmo que o PRÓPRIO token declara — inclusive "none".
        payload = jwt.decode(token, SECRET_KEY)
    except jwt.InvalidTokenError:
        abort(401)

    if payload.get("role") != "admin":
        abort(403)

    return jsonify({"painel-admin": True, "usuario": payload.get("user")})


@app.route("/healthz")
def healthz():
    return jsonify({"status": "ok"})


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
