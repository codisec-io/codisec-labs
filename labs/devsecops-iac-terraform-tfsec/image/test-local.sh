#!/usr/bin/env bash
# Testa a imagem localmente contra os MESMOS comandos que o lab.yaml usa.
#
# Uso:
#   cd labs/devsecops-iac-terraform-tfsec/image
#   chmod +x test-local.sh
#   ./test-local.sh
set -e

IMAGE="lab-terraform-tfsec:test"
CONTAINER="lab-tfsec-test"

echo "==> Limpando execuções anteriores (se houver)"
docker rm -f "$CONTAINER" >/dev/null 2>&1 || true

echo "==> Build da imagem"
docker build -t "$IMAGE" .

echo "==> Subindo container"
docker run -d --name "$CONTAINER" "$IMAGE"
sleep 1

echo ""
echo "==> Task 1 (scan): tfsec deve encontrar o achado de S3"
docker exec "$CONTAINER" sh -c "cd /app/infra && tfsec ." > /tmp/tfsec_out.txt 2>&1 || true
cat /tmp/tfsec_out.txt
if grep -q "aws-s3" /tmp/tfsec_out.txt; then
  echo "    ✅ passou — achado aws-s3 encontrado"
else
  echo "    ❌ falhou — nenhum achado 'aws-s3' na saída"
  exit 1
fi

echo ""
echo "==> Task 2 (fix-s3): adicionar bloqueio de acesso público"
docker exec "$CONTAINER" sh -c "cat >> /app/infra/s3.tf << 'EOF'

resource \"aws_s3_bucket_public_access_block\" \"dados\" {
  bucket                  = aws_s3_bucket.dados.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
EOF"
S3_COUNT=$(docker exec "$CONTAINER" sh -c "cd /app/infra && tfsec . 2>&1 | grep -c 'aws-s3'" || true)
if [ "$S3_COUNT" = "0" ]; then
  echo "    ✅ passou — achado aws-s3 não aparece mais"
else
  echo "    ❌ falhou — ainda há $S3_COUNT ocorrência(s) de 'aws-s3'"
  exit 1
fi

echo ""
echo "==> Task 3 (fix-sg): restringir o CIDR do ingress na porta 22"
docker exec "$CONTAINER" sh -c "sed -i 's|cidr_blocks = \[\"0.0.0.0/0\"\]|cidr_blocks = [\"10.0.0.0/16\"]|' /app/infra/sg.tf"
# só o primeiro cidr_blocks (ingress) deveria mudar; o egress também usa
# 0.0.0.0/0 de propósito (saída ampla é aceitável e não é o achado
# verificado por essa regra) — se o sed pegar os dois, sem problema pro
# teste, mas documentar essa nuance.
SG_COUNT=$(docker exec "$CONTAINER" sh -c "cd /app/infra && tfsec . 2>&1 | grep -c 'aws-vpc-no-public-ingress'" || true)
if [ "$SG_COUNT" = "0" ]; then
  echo "    ✅ passou — achado de ingress público não aparece mais"
else
  echo "    ❌ falhou — ainda há $SG_COUNT ocorrência(s) de 'aws-vpc-no-public-ingress'"
  exit 1
fi

echo ""
echo "==> Testando reset (recovery.reset_command)"
docker exec "$CONTAINER" sh -c "cp -r /app/infra.original/* /app/infra/"
S3_COUNT_AFTER=$(docker exec "$CONTAINER" sh -c "cd /app/infra && tfsec . 2>&1 | grep -c 'aws-s3'" || true)
if [ "$S3_COUNT_AFTER" -gt "0" ]; then
  echo "    ✅ reset funcionou — achado de S3 voltou a aparecer"
else
  echo "    ❌ reset falhou — achado de S3 não voltou"
  exit 1
fi

echo ""
echo "==> Limpando"
docker rm -f "$CONTAINER" >/dev/null

echo ""
echo "🎉 Todos os testes passaram. Pronto pra publicar:"
echo "   docker tag $IMAGE ghcr.io/codisec-io/lab-terraform-tfsec:latest"
echo "   docker push ghcr.io/codisec-io/lab-terraform-tfsec:latest"
