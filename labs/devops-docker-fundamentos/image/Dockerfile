# Imagem do lab devops-docker-fundamentos — publicada em
# ghcr.io/codisec-io/lab-docker-fundamentos
#
# ATENÇÃO: este lab exige requires_privileged: true no lab.yaml. A CLI
# deve avisar o usuário e pedir confirmação antes de rodar este container
# com --privileged (ver docs/SECURITY.md do projeto — decisão já tomada
# e documentada: dind isolado, não socket mount do host).
FROM docker:24-dind

RUN mkdir -p /app/exemplo
COPY exemplo/Dockerfile /app/exemplo/Dockerfile

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

WORKDIR /app

ENTRYPOINT ["/entrypoint.sh"]
