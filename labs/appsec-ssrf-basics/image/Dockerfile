# Imagem do lab appsec-ssrf-basics — publicada em
# ghcr.io/codisec-io/lab-ssrf-preview
#
# ATENÇÃO: precisa de CAP_NET_ADMIN em runtime (não precisa de
# --privileged completo) pra adicionar o IP 169.254.169.254 na
# interface loopback — é o endereço clássico de serviço de metadados
# de nuvem (AWS/GCP/Azure) que o lab simula. Ver docs/SECURITY.md e a
# discussão sobre required_capabilities vs. requires_privileged.
FROM python:3.11-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
        vim \
        nano \
        curl \
        supervisor \
        iproute2 \
    && rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir flask==3.0.3 requests==2.32.3

WORKDIR /app

COPY app.py /app/app.py
COPY app.py.vulnerable /app/app.py.vulnerable
COPY app.py.original /app/app.py.original
COPY metadata_service.py /app/metadata_service.py
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 5000 8080

ENTRYPOINT ["/entrypoint.sh"]
