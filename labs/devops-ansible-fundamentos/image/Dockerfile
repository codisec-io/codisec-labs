# Imagem do lab devops-ansible-fundamentos — publicada em
# ghcr.io/codisec-io/lab-ansible-fundamentos
FROM debian:12-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
        vim \
        nano \
        curl \
        python3 \
        python3-pip \
        python3-apt

# IMPORTANTE: ao contrário dos outros labs, aqui NÃO limpamos
# /var/lib/apt/lists/* — o exercício instala um pacote novo (htop) em
# runtime via Ansible, e sem o índice do apt cacheado isso falha com
# "No package matching 'htop' is available", mesmo com internet
# disponível. O ganho de espaço não compensa quebrar o propósito do lab.

# --break-system-packages necessário no Debian 12 (PEP 668, Python
# "externally managed") — mesmo ajuste que já precisamos fazer no
# build_catalog.py do site.
RUN pip install --no-cache-dir --break-system-packages "ansible-core==2.17.*"

WORKDIR /app

COPY inventory.ini /app/inventory.ini

CMD ["tail", "-f", "/dev/null"]
