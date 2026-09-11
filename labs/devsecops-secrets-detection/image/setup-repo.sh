#!/bin/sh
# Roda uma única vez, DURANTE o build da imagem (não em runtime). Cria o
# repositório Git de exemplo com um AWS key e uma senha de banco de dados
# commitados no histórico — exatamente o cenário que o lab.yaml descreve.
set -e

mkdir -p /app/repo
cd /app/repo

git init -q
git config user.email "lab@codisec.com.br"
git config user.name "Codisec Lab"

cat > config.py << 'EOF'
# Configuração da aplicação (exemplo didático — NUNCA faça isso de verdade)
AWS_KEY = "AKIAVR7QZX9LMEBT2K4P"
DB_PASSWORD = "SuperSecreta123!"
DEBUG = True
EOF

cat > README.md << 'EOF'
# App de Exemplo

Repositório de exemplo usado no lab de detecção de secrets do Codisec.
EOF

git add .
git commit -q -m "commit inicial da configuração"

echo "Repositório criado em /app/repo com secret commitado."

# Backup completo (incluindo .git) do estado inicial, pra recovery.
cp -r /app/repo /app/repo.original
echo "Backup criado em /app/repo.original."
