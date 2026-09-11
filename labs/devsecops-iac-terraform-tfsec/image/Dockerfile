# Imagem do lab devsecops-iac-terraform-tfsec — publicada em
# ghcr.io/codisec-io/lab-terraform-tfsec
#
# NOTA DE MANUTENÇÃO: tfsec foi descontinuado pela Aqua Security em 2024
# ("tfsec is now part of Trivy") — o motor de regras foi incorporado ao
# Trivy (`trivy config`), que é o sucessor oficial mantido. O binário
# standalone continua funcionando e as regras que este lab usa
# (aws-s3-*, aws-vpc-no-public-ingress-sgr) continuam ativas na última
# release (v1.28.13), mas não recebe novidade nenhuma desde então.
# Considerar migrar este lab pra `trivy config` no futuro — é troca de
# comando quase mecânica (`tfsec .` vira `trivy config .`), mas exige
# reescrever o lab.yaml (steps/validation), não só a imagem.
FROM debian:12-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
        vim \
        nano \
        curl \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN curl -sSL -o /usr/local/bin/tfsec \
        https://github.com/aquasecurity/tfsec/releases/download/v1.28.13/tfsec-linux-amd64 \
    && chmod +x /usr/local/bin/tfsec

WORKDIR /app

COPY infra/ /app/infra/

# Backup completo do estado inicial, usado pelo recovery.reset_command
RUN cp -r /app/infra /app/infra.original

CMD ["tail", "-f", "/dev/null"]
