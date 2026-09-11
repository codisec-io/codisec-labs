# Imagem do lab devsecops-secrets-detection — publicada em
# ghcr.io/codisec-io/lab-gitleaks
FROM debian:12-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
        git \
        curl \
        vim \
        nano \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Instala o gitleaks (binário estático, sem dependências)
RUN curl -sSL -o /tmp/gitleaks.tar.gz \
        https://github.com/gitleaks/gitleaks/releases/download/v8.30.1/gitleaks_8.30.1_linux_x64.tar.gz \
    && tar -xzf /tmp/gitleaks.tar.gz -C /usr/local/bin gitleaks \
    && chmod +x /usr/local/bin/gitleaks \
    && rm /tmp/gitleaks.tar.gz

WORKDIR /app

COPY setup-repo.sh /tmp/setup-repo.sh
RUN chmod +x /tmp/setup-repo.sh && /tmp/setup-repo.sh && rm /tmp/setup-repo.sh

CMD ["tail", "-f", "/dev/null"]
