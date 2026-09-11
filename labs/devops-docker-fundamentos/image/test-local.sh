#!/usr/bin/env bash
# Testa a imagem localmente contra os MESMOS comandos que o lab.yaml usa
# pra validar cada task. Precisa rodar com --privileged porque este lab
# usa Docker-in-Docker de verdade (requires_privileged: true no lab.yaml).
#
# Uso:
#   cd labs/devops-docker-fundamentos/image
#   chmod +x test-local.sh
#   ./test-local.sh
set -e

IMAGE="lab-docker-fundamentos:test"
CONTAINER="lab-dind-test"

echo "==> Limpando execuções anteriores (se houver)"
docker rm -f "$CONTAINER" >/dev/null 2>&1 || true

echo "==> Build da imagem (isso baixa a base docker:24-dind, pode demorar na primeira vez)"
docker build -t "$IMAGE" .

echo "==> Subindo container PRIVILEGIADO (necessário pra dind funcionar)"
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
echo "==> Task 1 (build): docker build -t meu-app:1.0 dentro do lab"
docker exec -w /app/exemplo "$CONTAINER" docker build -t meu-app:1.0 .
RESULT=$(docker exec "$CONTAINER" docker images meu-app:1.0 --format '{{.Repository}}')
if [ "$RESULT" = "meu-app" ]; then
  echo "    ✅ passou"
else
  echo "    ❌ falhou — esperava 'meu-app', recebeu '$RESULT'"
  exit 1
fi

echo ""
echo "==> Task 2 (run): container isolado dentro do dind"
docker exec "$CONTAINER" docker run --name teste1 -d meu-app:1.0
docker exec "$CONTAINER" docker exec teste1 sh -c 'echo oi > /tmp/arquivo.txt'
RESULT=$(docker exec "$CONTAINER" docker exec teste1 cat /tmp/arquivo.txt)
if [ "$RESULT" = "oi" ]; then
  echo "    ✅ passou"
else
  echo "    ❌ falhou — esperava 'oi', recebeu '$RESULT'"
  exit 1
fi

echo ""
echo "==> Task 3 (volumes): persistência entre containers"
docker exec "$CONTAINER" docker rm -f teste1
docker exec "$CONTAINER" docker volume create dados-persistentes
docker exec "$CONTAINER" docker run --name teste2 -v dados-persistentes:/dados -d meu-app:1.0
docker exec "$CONTAINER" docker exec teste2 sh -c 'echo persisto > /dados/arquivo.txt'
docker exec "$CONTAINER" docker rm -f teste2
docker exec "$CONTAINER" docker run --name teste3 -v dados-persistentes:/dados -d meu-app:1.0
RESULT=$(docker exec "$CONTAINER" docker exec teste3 cat /dados/arquivo.txt)
if [ "$RESULT" = "persisto" ]; then
  echo "    ✅ passou — o dado sobreviveu à remoção do container teste2"
else
  echo "    ❌ falhou — esperava 'persisto', recebeu '$RESULT'"
  exit 1
fi

echo ""
echo "==> Testando reset (recovery.reset_command)"
docker exec "$CONTAINER" sh -c "docker rm -f teste1 teste2 teste3 2>/dev/null; docker volume rm dados-persistentes 2>/dev/null; true"
echo "    ✅ reset executado sem erro"

echo ""
echo "==> Limpando (removendo o container de teste, --privileged incluso)"
docker rm -f "$CONTAINER" >/dev/null

echo ""
echo "🎉 Todos os testes passaram. Pronto pra publicar:"
echo "   docker tag $IMAGE ghcr.io/codisec-io/lab-docker-fundamentos:latest"
echo "   docker push ghcr.io/codisec-io/lab-docker-fundamentos:latest"
echo ""
echo "⚠️  Lembrete: confirme que labs/devops-docker-fundamentos/lab.yaml"
echo "   tem 'requires_privileged: true' declarado, e que a CLI avisa/pede"
echo "   confirmação antes de rodar este lab especificamente."
