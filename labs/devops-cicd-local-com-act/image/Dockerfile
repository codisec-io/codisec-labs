# Imagem do lab devops-cicd-local-com-act — publicada em
# ghcr.io/codisec-io/lab-act-cicd
#
# ATENÇÃO: `act` (nektos/act) precisa de um daemon Docker de verdade pra
# rodar os jobs do workflow como containers — mesma necessidade dos labs
# devops-docker-fundamentos e devsecops-container-scan-trivy. Este lab
# também precisa de requires_privileged: true no lab.yaml.
#
# TAMBÉM PRECISA DE INTERNET EM RUNTIME: o `act` baixa a imagem de
# runner (catthehacker/ubuntu:act-22.04, ~500MB+) na primeira execução,
# e o pip install do próprio workflow também busca pacotes do PyPI.
FROM docker:24-dind

RUN apk add --no-cache git bash

# Instala o act via script oficial
RUN wget -qO- https://raw.githubusercontent.com/nektos/act/master/install.sh | bash -s -- -b /usr/local/bin

WORKDIR /app

COPY repo/ /app/repo/
RUN cp /app/repo/requirements.txt /app/repo/requirements.txt.vulnerable \
    && cp /app/repo/requirements.txt /app/repo/requirements.txt.original

# Inicializa um repositório git — act/actions/checkout esperam esse
# contexto mesmo rodando localmente.
RUN cd /app/repo \
    && git init -q \
    && git config user.email "lab@codisec.com.br" \
    && git config user.name "Codisec Lab" \
    && git add . \
    && git commit -q -m "commit inicial"

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
