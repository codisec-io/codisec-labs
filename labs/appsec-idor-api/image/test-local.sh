#!/usr/bin/env bash
# Testa a imagem localmente contra os MESMOS comandos que o lab.yaml usa
# pra validar cada task. Rode isso antes de publicar no GHCR.
#
# Uso:
#   cd labs/appsec-idor-api/image
#   chmod +x test-local.sh
#   ./test-local.sh
set -e

IMAGE="lab-flask-idor:test"
CONTAINER="lab-idor-test"

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
echo "==> Task 1 (recon): deve retornar 0 e conter 'email'"
docker exec "$CONTAINER" sh -c "curl -s http://localhost:5000/api/users/1/profile | grep -q email"
echo "    ✅ passou"

echo ""
echo "==> Task 2 (exploit): deve retornar 0 e conter 'ssn_last4'"
docker exec "$CONTAINER" sh -c "curl -s http://localhost:5000/api/users/2/profile | grep -q ssn_last4"
echo "    ✅ passou"

echo ""
echo "==> Aplicando a correção da task 3 (simula o que o usuário faria com vi)"
docker cp app.py.fixed.reference "$CONTAINER:/app/app.py"
docker exec "$CONTAINER" supervisorctl restart flaskapp
sleep 1

echo ""
echo "==> Task 3 (fix): deve retornar código HTTP 403"
CODE=$(docker exec "$CONTAINER" sh -c "curl -s -o /dev/null -w '%{http_code}' http://localhost:5000/api/users/2/profile")
if [ "$CODE" = "403" ]; then
  echo "    ✅ passou (HTTP $CODE)"
else
  echo "    ❌ falhou — esperava 403, recebeu $CODE"
  exit 1
fi

echo ""
echo "==> Testando reset (recovery.reset_command)"
docker exec "$CONTAINER" sh -c "cp /app/app.py.original /app/app.py && supervisorctl restart flaskapp"
sleep 1
CODE=$(docker exec "$CONTAINER" sh -c "curl -s -o /dev/null -w '%{http_code}' http://localhost:5000/api/users/2/profile")
if [ "$CODE" = "200" ]; then
  echo "    ✅ reset funcionou — voltou a ficar vulnerável (HTTP $CODE)"
else
  echo "    ❌ reset falhou — esperava 200 (vulnerável de novo), recebeu $CODE"
  exit 1
fi

echo ""
echo "==> Limpando"
docker rm -f "$CONTAINER" >/dev/null

echo ""
echo "🎉 Todos os testes passaram. Pronto pra publicar:"
echo "   docker tag $IMAGE ghcr.io/codisec-io/lab-flask-idor:latest"
echo "   docker push ghcr.io/codisec-io/lab-flask-idor:latest"
