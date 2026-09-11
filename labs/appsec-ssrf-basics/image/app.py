"""
Serviço de "preview de link" — versão VULNERÁVEL (SSRF).
Estado inicial do lab appsec-ssrf-basics.
"""
import re
import requests
from flask import Flask, request, jsonify, abort

app = Flask(__name__)

TITLE_RE = re.compile(r"<title[^>]*>(.*?)</title>", re.IGNORECASE | re.DOTALL)


@app.route("/preview", methods=["POST"])
def preview():
    data = request.get_json(silent=True) or {}
    url = data.get("url", "")
    if not url:
        abort(400)

    # VULNERÁVEL: nenhuma validação de host/destino — o servidor faz
    # a requisição pra QUALQUER URL que o usuário mandar, inclusive
    # endereços internos como o de metadados de nuvem.
    try:
        resp = requests.get(url, timeout=5)
    except requests.RequestException as e:
        return jsonify({"error": str(e)}), 502

    match = TITLE_RE.search(resp.text)
    title = match.group(1).strip() if match else None

    return jsonify({"title": title, "body_snippet": resp.text[:500]})


@app.route("/healthz")
def healthz():
    return jsonify({"status": "ok"})


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
