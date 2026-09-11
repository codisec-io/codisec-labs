#!/bin/sh
set -e

# Sobe o daemon Docker em background — mesmo mecanismo da imagem oficial
# docker:dind, mas aqui rodamos em background pra podermos manter o
# container vivo depois com um processo próprio (pro `docker exec`
# do terminal do lab conseguir conectar).
dockerd-entrypoint.sh &

echo "Aguardando o daemon Docker ficar pronto..."
until docker info >/dev/null 2>&1; do
  sleep 1
done
echo "Docker daemon pronto."

# Mantém o container vivo indefinidamente
tail -f /dev/null
