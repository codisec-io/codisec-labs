#!/usr/bin/env bash
# Testa a imagem localmente contra os MESMOS comandos que o lab.yaml usa.
# Precisa rodar com --privileged (Docker-in-Docker de verdade).
#
# Uso:
#   cd labs/devsecops-container-scan-trivy/image
#   chmod +x test-local.sh entrypoint.sh
#   ./test-local.sh
set -e

IMAGE="lab-trivy-scan:test"
CONTAINER="lab-trivy-test"

echo "==> Limpando execuções anteriores (se houver)"
docker rm -f "$CONTAINER" >/dev/null 2>&1 || true

echo "==> Build da imagem (baixa docker:24-dind + instala trivy, pode demorar)"
docker build -t "$IMAGE" .

echo "==> Subindo container PRIVILEGIADO"
docker run -d --privileged --name "$CONTAINER" "$IMAGE"

echo "==> Aguardando o dockerd interno E a imagem app-vulneravel:old ficarem prontos..."
for i in $(seq 1 60); do
  if docker exec "$CONTAINER" docker image inspect app-vulneravel:old >/dev/null 2>&1; then
    echo "    app-vulneravel:old pronta."
    break
  fi
  sleep 2
done

echo ""
echo "==> Task 1 (scan): trivy deve encontrar CVEs na imagem antiga"
docker exec "$CONTAINER" trivy image app-vulneravel:old --severity HIGH,CRITICAL > /tmp/trivy_out.txt 2>&1 || true
cat /tmp/trivy_out.txt
if grep -qi CVE /tmp/trivy_out.txt; then
  echo "    ✅ passou — CVEs encontradas"
else
  echo "    ❌ falhou — nenhuma CVE reportada (inesperado pra debian:9)"
  exit 1
fi

echo ""
echo "==> Task 2 (count): contar CVEs críticas"
OLD_COUNT=$(docker exec "$CONTAINER" sh -c "trivy image app-vulneravel:old --severity CRITICAL --format json 2>/dev/null | grep -c VulnerabilityID || true")
echo "    CVEs críticas na imagem antiga: $OLD_COUNT"
if [ "$OLD_COUNT" -gt "0" ]; then
  echo "    ✅ passou"
else
  echo "    ❌ falhou — esperava pelo menos 1 CVE crítica"
  exit 1
fi

echo ""
echo "==> Task 3 (fix): editar /app/Dockerfile e reconstruir como :new"
docker exec "$CONTAINER" sh -c "sed -i 's/FROM debian:9/FROM debian:12-slim/' /app/Dockerfile"
docker exec "$CONTAINER" docker build -t app-vulneravel:new /app
CVE_COUNT=$(docker exec "$CONTAINER" sh -c "trivy image app-vulneravel:new --severity CRITICAL --format json 2>/dev/null | grep -c CVE-2019-12900 || true")
echo "    Ocorrências de CVE-2019-12900 na imagem nova: $CVE_COUNT"
if [ "$CVE_COUNT" = "0" ]; then
  echo "    ✅ passou — a CVE específica não aparece mais na imagem nova"
else
  echo "    ❌ falhou — CVE-2019-12900 ainda presente na imagem nova"
  exit 1
fi

echo ""
echo "==> Testando reset (recovery.reset_command)"
docker exec "$CONTAINER" sh -c "cp /app/Dockerfile.original /app/Dockerfile"
RESTORED=$(docker exec "$CONTAINER" cat /app/Dockerfile)
if echo "$RESTORED" | grep -q "debian:9"; then
  echo "    ✅ reset funcionou — /app/Dockerfile voltou a referenciar debian:9"
else
  echo "    ❌ reset falhou — /app/Dockerfile não foi restaurado corretamente"
  exit 1
fi

echo ""
echo "==> Limpando"
docker rm -f "$CONTAINER" >/dev/null

echo ""
echo "🎉 Todos os testes passaram. Pronto pra publicar:"
echo "   docker tag $IMAGE ghcr.io/codisec-io/lab-trivy-scan:latest"
echo "   docker push ghcr.io/codisec-io/lab-trivy-scan:latest"
echo ""
echo "⚠️  Lembrete: confirme que labs/devsecops-container-scan-trivy/lab.yaml"
echo "   tem 'requires_privileged: true' declarado (mesmo gap do lab"
echo "   devops-docker-fundamentos, mas aqui ainda não tinha sido revisado)."
