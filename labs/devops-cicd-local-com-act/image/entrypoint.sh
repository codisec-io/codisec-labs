#!/bin/sh
set -e

dockerd-entrypoint.sh &

echo "Aguardando o daemon Docker ficar pronto..."
until docker info >/dev/null 2>&1; do
  sleep 1
done
echo "Docker daemon pronto."

tail -f /dev/null
