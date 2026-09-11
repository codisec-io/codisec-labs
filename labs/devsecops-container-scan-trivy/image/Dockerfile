# Imagem do lab devsecops-container-scan-trivy — publicada em
# ghcr.io/codisec-io/lab-trivy-scan
#
# ATENÇÃO: assim como devops-docker-fundamentos, este lab precisa rodar
# Docker de verdade por dentro (o usuário builda uma imagem nova na
# task 3), então também exige requires_privileged: true no lab.yaml.
# Confirme se isso já está declarado — se não estiver, é o mesmo gap
# de segurança que já identificamos antes, só que num lab diferente.
FROM docker:24-dind

# Instala o trivy (binário estático via script oficial). ca-certificates
# garante que o wget via HTTPS funcione — a base Alpine do docker:dind
# não vem com isso por padrão.
RUN apk add --no-cache ca-certificates \
    && wget -qO- https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin

WORKDIR /app

COPY Dockerfile.vulnerable-app /app/Dockerfile
COPY Dockerfile.vulnerable-app /app/Dockerfile.original

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
