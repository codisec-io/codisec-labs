#!/usr/bin/env bash
# Testa a imagem contra os MESMOS comandos de validation do lab.yaml,
# e testa também o recovery.reset_command LITERAL pra confirmar se ele
# faz o que deveria (restaurar o estado vulnerável original).
#
# Uso:
#   cd labs/devsecops-secrets-detection/image
#   chmod +x test-local.sh
#   ./test-local.sh
set -e

IMAGE="lab-gitleaks:test"
CONTAINER="lab-gitleaks-test"

echo "==> Limpando execuções anteriores (se houver)"
docker rm -f "$CONTAINER" >/dev/null 2>&1 || true

echo "==> Build da imagem"
docker build -t "$IMAGE" .

echo "==> Subindo container"
docker run -d --name "$CONTAINER" "$IMAGE"
sleep 1

echo ""
echo "==> Task 1 (scan): gitleaks detect deve reportar exit code 1 (leaks encontrados)"
set +e
docker exec "$CONTAINER" sh -c "cd /app/repo && gitleaks detect --source ."
GITLEAKS_EXIT=$?
set -e
if [ "$GITLEAKS_EXIT" -eq 1 ]; then
  echo "    ✅ passou — gitleaks retornou exit code 1 (encontrou o secret)"
else
  echo "    ❌ falhou — esperava exit code 1, gitleaks retornou $GITLEAKS_EXIT"
  echo "        (exit 0 geralmente significa que o secret está numa allowlist"
  echo "        padrão do gitleaks — confira se o valor em config.py não é"
  echo "        um exemplo conhecido, tipo AKIAIOSFODNN7EXAMPLE)"
  exit 1
fi

echo ""
echo "==> Task 2 (remove-current): remover o secret do arquivo atual"
docker exec "$CONTAINER" sh -c "sed -i 's/AWS_KEY = \"AKIA[A-Z0-9]*\"/AWS_KEY = os.environ.get(\"AWS_KEY\")/' /app/repo/config.py"
docker exec "$CONTAINER" sh -c "sed -i '1i import os' /app/repo/config.py"
docker exec "$CONTAINER" git -C /app/repo commit -am "remove hardcoded secret" -q
COUNT=$(docker exec "$CONTAINER" sh -c "grep -c 'AKIA' /app/repo/config.py || true")
if [ "$COUNT" = "0" ]; then
  echo "    ✅ passou — AKIA não está mais no arquivo atual"
else
  echo "    ❌ falhou — ainda encontrou AKIA no arquivo atual"
  exit 1
fi

echo ""
echo "==> Task 3 (understand-history): o secret ainda deve aparecer no histórico"
docker exec "$CONTAINER" sh -c "git -C /app/repo log --all -p -- config.py | grep -c AKIA" > /tmp/history_count.txt || true
HIST_COUNT=$(cat /tmp/history_count.txt)
if [ "$HIST_COUNT" -gt "0" ]; then
  echo "    ✅ passou — o histórico ainda contém $HIST_COUNT ocorrência(s) de AKIA"
else
  echo "    ❌ falhou — o histórico não mostra mais o secret (não deveria acontecer)"
  exit 1
fi

echo ""
echo "==> Testando o recovery.reset_command CORRIGIDO"
docker exec "$CONTAINER" sh -c "rm -rf /app/repo && cp -r /app/repo.original /app/repo"
AFTER_RESET=$(docker exec "$CONTAINER" sh -c "grep -c AKIA /app/repo/config.py || true")
if [ "$AFTER_RESET" -gt "0" ]; then
  echo "    ✅ reset restaurou o AWS key em config.py — comando corrigido funciona"
else
  echo "    ❌ ainda falhou mesmo com o comando corrigido — investigar /app/repo.original"
  exit 1
fi

echo ""
echo "==> Limpando"
docker rm -f "$CONTAINER" >/dev/null

echo ""
echo "🎉 Tasks 1, 2 e 3 passaram. Verifique o resultado do teste de reset acima"
echo "   antes de decidir se ajusta o lab.yaml. Se tudo estiver ok, publique:"
echo "   docker tag $IMAGE ghcr.io/codisec-io/lab-gitleaks:latest"
echo "   docker push ghcr.io/codisec-io/lab-gitleaks:latest"
