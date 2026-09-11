# Imagem do lab appsec-jwt-alg-none — publicada em
# ghcr.io/codisec-io/lab-jwt-alg-none
FROM python:3.11-slim

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
COPY jwtlib.py /app/jwtlib.py
COPY forge_token.py /app/forge_token.py
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

EXPOSE 5000

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
