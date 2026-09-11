"""
Simula um serviço de metadados de nuvem (mesmo padrão de endereço usado
por AWS/GCP/Azure de verdade: 169.254.169.254). Normalmente NÃO seria
acessível de fora — só de dentro da própria instância/container. O lab
demonstra como um SSRF permite que um atacante externo alcance esse
serviço "por dentro", usando o servidor vulnerável como proxy.
"""
from flask import Flask, jsonify

app = Flask(__name__)


@app.route("/latest/meta-data/iam-credentials")
def iam_credentials():
    # Credencial FALSA, só pra fins didáticos — nunca algo real.
    return jsonify({
        "AccessKeyId": "FAKE_SECRET_AKIAEXAMPLE",
        "SecretAccessKey": "FAKE_SECRET_dummy1234567890",
        "Token": "FAKE_SECRET_token",
    })


if __name__ == "__main__":
    # Escuta especificamente no IP de metadados, não em 0.0.0.0 — isso
    # é intencional: só quem alcançar esse IP exato consegue acessar.
    app.run(host="169.254.169.254", port=8080)
