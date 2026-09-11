#!/usr/bin/env bash
# Testa a imagem localmente contra os MESMOS comandos que o lab.yaml usa.
#
# IMPORTANTE: este lab usa `semgrep --config=auto`, que busca regras no
# registry da Semgrep pela internet em tempo de execução (não só no
# build da imagem). O container de teste precisa ter acesso à internet.
#
# Uso:
#   cd labs/devsecops-sast-semgrep/image
#   chmod +x test-local.sh
#   ./test-local.sh
set -e

IMAGE="lab-semgrep-python:test"
CONTAINER="lab-semgrep-test"

echo "==> Limpando execuções anteriores (se houver)"
docker rm -f "$CONTAINER" >/dev/null 2>&1 || true

echo "==> Build da imagem (inclui instalar o semgrep, pode demorar um pouco)"
docker build -t "$IMAGE" .

echo "==> Subindo container"
docker run -d --name "$CONTAINER" "$IMAGE"
sleep 1

echo ""
echo "==> Task 1 (scan): semgrep deve encontrar o achado de SQL"
docker exec "$CONTAINER" sh -c "cd /app/repo && semgrep --config=auto . 2>&1" | tee /tmp/semgrep_out.txt
if grep -qi "sql" /tmp/semgrep_out.txt; then
  echo "    ✅ passou — achado relacionado a SQL encontrado"
else
  echo "    ❌ falhou — nenhum achado de SQL na saída do semgrep"
  exit 1
fi

echo ""
echo "==> Task 2 (fix-sqli): corrigir com query parametrizada"
docker exec "$CONTAINER" sh -c "cat > /app/repo/db.py << 'PYEOF'
import sqlite3


def get_connection():
    conn = sqlite3.connect(':memory:')
    conn.execute('CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT)')
    conn.execute(\"INSERT INTO users (name) VALUES ('alice'), ('bob')\")
    return conn


def find_user_by_name(name):
    conn = get_connection()
    cursor = conn.execute('SELECT * FROM users WHERE name = ?', (name,))
    return cursor.fetchall()
PYEOF"
SQL_COUNT=$(docker exec "$CONTAINER" sh -c "cd /app/repo && semgrep --config=auto . 2>&1 | grep -ci 'sql'" || true)
if [ "$SQL_COUNT" = "0" ]; then
  echo "    ✅ passou — achado de SQL não aparece mais"
else
  echo "    ❌ falhou — ainda há $SQL_COUNT ocorrência(s) de 'sql' na saída"
  exit 1
fi

echo ""
echo "==> Task 3 (fix-eval): corrigir com ast.literal_eval"
docker exec "$CONTAINER" sh -c "cat > /app/repo/calc.py << 'PYEOF'
import ast


def calcular(expressao):
    resultado = ast.literal_eval(expressao)
    return resultado
PYEOF"
EVAL_COUNT=$(docker exec "$CONTAINER" sh -c "cd /app/repo && semgrep --config=auto . 2>&1 | grep -ci 'eval'" || true)
if [ "$EVAL_COUNT" = "0" ]; then
  echo "    ✅ passou — achado de eval() não aparece mais"
else
  echo "    ❌ falhou — ainda há $EVAL_COUNT ocorrência(s) de 'eval' na saída"
  exit 1
fi

echo ""
echo "==> Testando reset (recovery.reset_command)"
docker exec "$CONTAINER" sh -c "cp -r /app/repo.original/* /app/repo/"
SQL_COUNT_AFTER=$(docker exec "$CONTAINER" sh -c "cd /app/repo && semgrep --config=auto . 2>&1 | grep -ci 'sql'" || true)
if [ "$SQL_COUNT_AFTER" -gt "0" ]; then
  echo "    ✅ reset funcionou — achado de SQL voltou a aparecer"
else
  echo "    ❌ reset falhou — achado de SQL não voltou depois do reset"
  exit 1
fi

echo ""
echo "==> Limpando"
docker rm -f "$CONTAINER" >/dev/null

echo ""
echo "🎉 Todos os testes passaram. Pronto pra publicar:"
echo "   docker tag $IMAGE ghcr.io/codisec-io/lab-semgrep-python:latest"
echo "   docker push ghcr.io/codisec-io/lab-semgrep-python:latest"
