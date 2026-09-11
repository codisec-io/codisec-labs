#!/usr/bin/env bash
# Testa a imagem localmente contra os MESMOS comandos que o lab.yaml usa.
#
# Uso:
#   cd labs/appsec-jwt-alg-none/image
#   chmod +x test-local.sh
#   ./test-local.sh
set -e

IMAGE="lab-jwt-alg-none:test"
CONTAINER="lab-jwt-test"

echo "==> Limpando execuções anteriores (se houver)"
docker rm -f "$CONTAINER" >/dev/null 2>&1 || true

echo "==> Build da imagem"
docker build -t "$IMAGE" .

echo "==> Subindo container (porta 5000 mapeada)"
docker run -d --name "$CONTAINER" -p 5000:5000 "$IMAGE"

echo "==> Aguardando o Flask subir..."
for i in $(seq 1 15); do
  if curl -s -o /dev/null http://localhost:5000/healthz; then
    echo "    Flask respondendo."
    break
  fi
  sleep 1
done

echo ""
echo "==> Task 1 (recon): login deve gerar um token válido"
docker exec "$CONTAINER" sh -c "curl -s -X POST http://localhost:5000/login -d 'user=alice' > /app/token.txt"
docker exec "$CONTAINER" sh -c "test -s /app/token.txt && grep -q '\.' /app/token.txt"
echo "    ✅ passou"

echo ""
echo "==> Task 2 (exploit): token forjado com alg=none deve dar acesso de admin"
FORGED=$(docker exec "$CONTAINER" python3 /app/forge_token.py)
RESULT=$(docker exec "$CONTAINER" sh -c "curl -s http://localhost:5000/admin -H 'Authorization: Bearer $FORGED'")
if echo "$RESULT" | grep -q "painel-admin"; then
  echo "    ✅ passou — acesso de admin obtido com token sem assinatura"
else
  echo "    ❌ falhou — esperava 'painel-admin' na resposta, recebeu: $RESULT"
  exit 1
fi

echo ""
echo "==> Aplicando a correção da task 3 (simula o que o usuário faria com vi)"
docker cp app.py.fixed.reference "$CONTAINER:/app/app.py"
docker exec "$CONTAINER" supervisorctl restart flaskapp
sleep 1

echo ""
echo "==> Task 3 (fix): o mesmo token forjado agora deve dar 401"
FORGED=$(docker exec "$CONTAINER" python3 /app/forge_token.py)
CODE=$(docker exec "$CONTAINER" sh -c "curl -s -o /dev/null -w '%{http_code}' http://localhost:5000/admin -H 'Authorization: Bearer $FORGED'")
if [ "$CODE" = "401" ]; then
  echo "    ✅ passou (HTTP $CODE)"
else
  echo "    ❌ falhou — esperava 401, recebeu $CODE"
  exit 1
fi

echo ""
echo "==> Testando reset (recovery.reset_command)"
docker exec "$CONTAINER" sh -c "cp /app/app.py.original /app/app.py && supervisorctl restart flaskapp"
sleep 1
FORGED=$(docker exec "$CONTAINER" python3 /app/forge_token.py)
CODE=$(docker exec "$CONTAINER" sh -c "curl -s -o /dev/null -w '%{http_code}' http://localhost:5000/admin -H 'Authorization: Bearer $FORGED'")
if [ "$CODE" = "200" ]; then
  echo "    ✅ reset funcionou — voltou a aceitar alg=none (HTTP $CODE)"
else
  echo "    ❌ reset falhou — esperava 200 (vulnerável de novo), recebeu $CODE"
  exit 1
fi

echo ""
echo "==> Limpando"
docker rm -f "$CONTAINER" >/dev/null

echo ""
echo "🎉 Todos os testes passaram. Pronto pra publicar:"
echo "   docker tag $IMAGE ghcr.io/codisec-io/lab-jwt-alg-none:latest"
echo "   docker push ghcr.io/codisec-io/lab-jwt-alg-none:latest"
