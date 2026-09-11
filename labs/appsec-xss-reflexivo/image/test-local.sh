#!/usr/bin/env bash
# Testa a imagem localmente contra os MESMOS comandos que o lab.yaml usa.
#
# Uso:
#   cd labs/appsec-xss-reflexivo/image
#   chmod +x test-local.sh
#   ./test-local.sh
set -e

IMAGE="lab-flask-xss:test"
CONTAINER="lab-xss-test"

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
echo "==> Task 1 (recon): termo refletido na resposta"
docker exec "$CONTAINER" sh -c "curl -s 'http://localhost:5000/search?q=teste' | grep -q teste"
echo "    ✅ passou"

echo ""
echo "==> Task 2 (exploit): tag <script> deve aparecer intacta (não escapada)"
docker exec "$CONTAINER" sh -c "curl -s 'http://localhost:5000/search?q=%3Cscript%3Ealert(1)%3C/script%3E' | grep -q '<script>alert(1)</script>'"
echo "    ✅ passou"

echo ""
echo "==> Aplicando a correção da task 3 (simula o que o usuário faria com vi)"
docker cp app.py.fixed.reference "$CONTAINER:/app/app.py"
docker exec "$CONTAINER" supervisorctl restart flaskapp
sleep 1

echo ""
echo "==> Task 3 (fix): tag deve aparecer escapada (&lt;script&gt;)"
docker exec "$CONTAINER" sh -c "curl -s 'http://localhost:5000/search?q=%3Cscript%3Ealert(1)%3C/script%3E' | grep -q '&lt;script&gt;'"
echo "    ✅ passou"

echo ""
echo "==> Testando reset (recovery.reset_command)"
docker exec "$CONTAINER" sh -c "cp /app/app.py.original /app/app.py && supervisorctl restart flaskapp"
sleep 1
RESULT=$(docker exec "$CONTAINER" sh -c "curl -s 'http://localhost:5000/search?q=%3Cscript%3Ealert(1)%3C/script%3E'")
if echo "$RESULT" | grep -q '<script>alert(1)</script>'; then
  echo "    ✅ reset funcionou — voltou a ficar vulnerável"
else
  echo "    ❌ reset falhou — ainda está escapando depois do reset"
  exit 1
fi

echo ""
echo "==> Limpando"
docker rm -f "$CONTAINER" >/dev/null

echo ""
echo "🎉 Todos os testes passaram. Pronto pra publicar:"
echo "   docker tag $IMAGE ghcr.io/codisec-io/lab-flask-xss:latest"
echo "   docker push ghcr.io/codisec-io/lab-flask-xss:latest"
