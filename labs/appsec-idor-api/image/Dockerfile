# Imagem do lab appsec-idor-api — publicada em ghcr.io/codisec-io/lab-flask-idor
FROM python:3.11-slim

# vim/nano pra edição dentro do lab (o lab.yaml instrui `vi /app/app.py`);
# curl pra os comandos de validation/steps; supervisor pra permitir
# `supervisorctl restart flaskapp` como pede o lab.yaml
RUN apt-get update && apt-get install -y --no-install-recommends \
        vim \
        nano \
        curl \
        supervisor \
    && rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir flask==3.0.3

WORKDIR /app

COPY app.py /app/app.py
COPY app.py.vulnerable /app/app.py.vulnerable
COPY app.py.original /app/app.py.original
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

EXPOSE 5000

# supervisord em foreground como processo principal do container —
# assim `docker exec` pro terminal do lab funciona normalmente, e
# supervisorctl consegue reiniciar só o flaskapp sem matar o container
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
