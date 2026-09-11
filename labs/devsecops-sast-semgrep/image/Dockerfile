# Imagem do lab devsecops-sast-semgrep — publicada em
# ghcr.io/codisec-io/lab-semgrep-python
FROM python:3.11-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
        vim \
        nano \
        curl \
        git \
    && rm -rf /var/lib/apt/lists/*

# semgrep --config=auto busca regras no registry da Semgrep em runtime,
# então o container precisa de acesso à internet quando o usuário rodar
# o scan (documentar isso no lab, já que é diferente dos outros labs).
RUN pip install --no-cache-dir semgrep==1.175.1

WORKDIR /app

COPY repo/ /app/repo/

# Backup completo do estado inicial, usado pelo recovery.reset_command
RUN cp -r /app/repo /app/repo.original

CMD ["tail", "-f", "/dev/null"]
