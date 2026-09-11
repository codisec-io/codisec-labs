#!/usr/bin/env bash
# Testa a imagem localmente contra os MESMOS comandos que o lab.yaml usa.
# Precisa de --cap-add=NET_ADMIN (não de --privileged completo) pra
# adicionar o IP de metadados na interface loopback.
#
# Uso:
#   cd labs/appsec-ssrf-basics/image
#   chmod +x test-local.sh entrypoint.sh
#   ./test-local.sh
set -e

IMAGE="lab-ssrf-preview:test"
CONTAINER="lab-ssrf-test"

echo "==> Limpando execuções anteriores (se houver)"
docker rm -f "$CONTAINER" >/dev/null 2>&1 || true

echo "==> Build da imagem"
docker build -t "$IMAGE" .

echo "==> Subindo container com --cap-add=NET_ADMIN (não é --privileged completo)"
docker run -d --cap-add=NET_ADMIN --name "$CONTAINER" -p 5000:5000 "$IMAGE"

echo "==> Aguardando os serviços subirem..."
for i in $(seq 1 15); do
  if curl -s -o /dev/null http://localhost:5000/healthz; then
    echo "    Preview service respondendo."
    break
  fi
  sleep 1
done
sleep 2  # tempo extra pro metadata service subir depois do `ip addr add`

echo ""
echo "==> Task 1 (recon): preview de URL legítima deve funcionar"
docker exec "$CONTAINER" sh -c "curl -s -X POST http://localhost:5000/preview -H 'Content-Type: application/json' -d '{\"url\":\"http://example.com\"}'" | tee /tmp/ssrf_out1.txt
if grep -qi title /tmp/ssrf_out1.txt; then
  echo "    ✅ passou"
else
  echo "    ❌ falhou — resposta não contém 'title'"
  exit 1
fi

echo ""
echo "==> Task 2 (exploit): SSRF contra o serviço de metadados interno"
docker exec "$CONTAINER" sh -c "curl -s -X POST http://localhost:5000/preview -H 'Content-Type: application/json' -d '{\"url\":\"http://169.254.169.254:8080/latest/meta-data/iam-credentials\"}'" | tee /tmp/ssrf_out2.txt
if grep -q FAKE_SECRET /tmp/ssrf_out2.txt; then
  echo "    ✅ passou — vazou a credencial simulada via SSRF"
else
  echo "    ❌ falhou — não encontrou FAKE_SECRET na resposta"
  echo "        (se a resposta veio vazia/erro, o serviço de metadados"
  echo "        pode não ter subido — confira se o --cap-add=NET_ADMIN"
  echo "        foi aplicado e se 'ip addr add' rodou sem erro)"
  exit 1
fi

echo ""
echo "==> Aplicando a correção da task 3 (simula o que o usuário faria com vi)"
docker cp app.py.fixed.reference "$CONTAINER:/app/app.py"
docker exec "$CONTAINER" supervisorctl restart flaskapp
sleep 1

echo ""
echo "==> Task 3 (fix): a mesma URL de metadados agora deve dar 403"
CODE=$(docker exec "$CONTAINER" sh -c "curl -s -o /dev/null -w '%{http_code}' -X POST http://localhost:5000/preview -H 'Content-Type: application/json' -d '{\"url\":\"http://169.254.169.254:8080/latest/meta-data/iam-credentials\"}'")
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
CODE=$(docker exec "$CONTAINER" sh -c "curl -s -o /dev/null -w '%{http_code}' -X POST http://localhost:5000/preview -H 'Content-Type: application/json' -d '{\"url\":\"http://169.254.169.254:8080/latest/meta-data/iam-credentials\"}'")
if [ "$CODE" = "200" ]; then
  echo "    ✅ reset funcionou — voltou a ficar vulnerável (HTTP $CODE)"
else
  echo "    ❌ reset falhou — esperava 200, recebeu $CODE"
  exit 1
fi

echo ""
echo "==> Limpando"
docker rm -f "$CONTAINER" >/dev/null

echo ""
echo "🎉 Todos os testes passaram. Pronto pra publicar:"
echo "   docker tag $IMAGE ghcr.io/codisec-io/lab-ssrf-preview:latest"
echo "   docker push ghcr.io/codisec-io/lab-ssrf-preview:latest"
echo ""
echo "⚠️  Lembrete: este lab precisa de CAP_NET_ADMIN em runtime — não"
echo "   é privilégio total. Decida com o time se isso vira um campo"
echo "   novo no schema (required_capabilities) ou se usa"
echo "   requires_privileged: true por enquanto como solução temporária."
