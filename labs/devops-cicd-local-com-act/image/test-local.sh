#!/usr/bin/env bash
# Testa a imagem localmente contra os MESMOS comandos que o lab.yaml usa.
# Precisa rodar com --privileged (act usa Docker de verdade por dentro)
# e de internet (baixa a imagem de runner + pacotes do PyPI).
#
# Uso:
#   cd labs/devops-cicd-local-com-act/image
#   chmod +x test-local.sh entrypoint.sh
#   ./test-local.sh
set -e

IMAGE="lab-act-cicd:test"
CONTAINER="lab-act-test"

echo "==> Limpando execuções anteriores (se houver)"
docker rm -f "$CONTAINER" >/dev/null 2>&1 || true

echo "==> Build da imagem"
docker build -t "$IMAGE" .

echo "==> Subindo container PRIVILEGIADO"
docker run -d --privileged --name "$CONTAINER" "$IMAGE"

echo "==> Aguardando o dockerd interno ficar pronto..."
for i in $(seq 1 30); do
  if docker exec "$CONTAINER" docker info >/dev/null 2>&1; then
    echo "    dockerd interno respondendo."
    break
  fi
  sleep 1
done

echo ""
echo "==> Task 1 (run-broken): act -j test deve falhar (baixa a imagem de runner, pode demorar bastante na primeira vez)"
docker exec -w /app/repo "$CONTAINER" act -j test > /tmp/act_out.txt 2>&1 || true
cat /tmp/act_out.txt
if grep -qi "failure" /tmp/act_out.txt; then
  echo "    ✅ passou — o job falhou, como esperado"
else
  echo "    ⚠️  ATENÇÃO: não encontrou 'failure' na saída. Isso pode significar"
  echo "        que pytest==4.6.0 instalou e rodou sem problema no ambiente"
  echo "        do runner — o que quebraria a premissa do lab (precisa de uma"
  echo "        versão que falhe de verdade). Reveja a saída completa acima."
  exit 1
fi

echo ""
echo "==> Task 2 (diagnose): confirmar a causa raiz no requirements.txt"
docker exec "$CONTAINER" sh -c "grep -q 'pytest==4' /app/repo/requirements.txt"
echo "    ✅ passou"

echo ""
echo "==> Task 3 (fix): corrigir e rodar de novo"
docker exec "$CONTAINER" sh -c "sed -i 's/pytest==4.6.0/pytest>=7.0/' /app/repo/requirements.txt"
docker exec -w /app/repo "$CONTAINER" act -j test > /tmp/act_out2.txt 2>&1 || true
cat /tmp/act_out2.txt
if grep -qi "success" /tmp/act_out2.txt; then
  echo "    ✅ passou — pipeline passando localmente"
else
  echo "    ❌ falhou — esperava 'success' na saída"
  exit 1
fi

echo ""
echo "==> Testando reset (recovery.reset_command)"
docker exec "$CONTAINER" sh -c "cp /app/repo/requirements.txt.original /app/repo/requirements.txt"
RESTORED=$(docker exec "$CONTAINER" cat /app/repo/requirements.txt)
if echo "$RESTORED" | grep -q "4.6.0"; then
  echo "    ✅ reset funcionou — requirements.txt voltou ao estado quebrado"
else
  echo "    ❌ reset falhou"
  exit 1
fi

echo ""
echo "==> Limpando"
docker rm -f "$CONTAINER" >/dev/null

echo ""
echo "🎉 Todos os testes passaram. Pronto pra publicar:"
echo "   docker tag $IMAGE ghcr.io/codisec-io/lab-act-cicd:latest"
echo "   docker push ghcr.io/codisec-io/lab-act-cicd:latest"
echo ""
echo "⚠️  Lembrete: confirme que labs/devops-cicd-local-com-act/lab.yaml"
echo "   tem 'requires_privileged: true' declarado (mesmo padrão dos"
echo "   labs devops-docker-fundamentos e devsecops-container-scan-trivy)."
