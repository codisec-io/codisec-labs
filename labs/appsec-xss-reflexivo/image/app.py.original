"""
Busca com reflexão de HTML sem escaping — versão VULNERÁVEL (XSS refletido).
Estado inicial do lab appsec-xss-reflexivo.
"""
from flask import Flask, request, Response

app = Flask(__name__)


@app.route("/search")
def search():
    q = request.args.get("q", "")
    # VULNERÁVEL: o termo de busca é inserido direto no HTML via f-string,
    # sem nenhum escaping. Qualquer tag/script no valor de "q" é
    # interpretado pelo navegador de quem abrir essa URL.
    html = f"""
    <html>
      <head><title>Busca</title></head>
      <body>
        <h1>Resultados para: {q}</h1>
        <p>Nenhum resultado encontrado.</p>
      </body>
    </html>
    """
    return Response(html, mimetype="text/html")


@app.route("/healthz")
def healthz():
    return {"status": "ok"}


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
