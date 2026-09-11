#!/bin/sh
set -e

# Sobe o daemon Docker em background (mesmo padrão usado no lab
# devops-docker-fundamentos).
dockerd-entrypoint.sh &

echo "Aguardando o daemon Docker ficar pronto..."
until docker info >/dev/null 2>&1; do
  sleep 1
done
echo "Docker daemon pronto."

# Constrói a imagem antiga vulnerável automaticamente no boot, sempre a
# partir do Dockerfile.original (imutável) — nunca do /app/Dockerfile
# editável, pra não depender de o usuário ainda não ter mexido nele.
if ! docker image inspect app-vulneravel:old >/dev/null 2>&1; then
  echo "Construindo app-vulneravel:old (uma vez por sessão)..."
  docker build -f /app/Dockerfile.original -t app-vulneravel:old /app
  echo "app-vulneravel:old pronta."
fi

# Mantém o container vivo pro terminal do lab conectar
tail -f /dev/null
