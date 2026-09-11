#!/usr/bin/env bash
# Testa a imagem localmente contra os MESMOS comandos que o lab.yaml usa.
#
# Uso:
#   cd labs/devops-ansible-fundamentos/image
#   chmod +x test-local.sh
#   ./test-local.sh
set -e

IMAGE="lab-ansible-fundamentos:test"
CONTAINER="lab-ansible-test"

echo "==> Limpando execuções anteriores (se houver)"
docker rm -f "$CONTAINER" >/dev/null 2>&1 || true

echo "==> Build da imagem"
docker build -t "$IMAGE" .

echo "==> Subindo container"
docker run -d --name "$CONTAINER" "$IMAGE"
sleep 1

echo ""
echo "==> Task 1 (inventory): ping deve retornar SUCCESS"
docker exec "$CONTAINER" sh -c "ansible all -i /app/inventory.ini -m ping" | tee /tmp/ansible_ping.txt
if grep -q SUCCESS /tmp/ansible_ping.txt; then
  echo "    ✅ passou"
else
  echo "    ❌ falhou — não encontrou SUCCESS na saída"
  exit 1
fi

echo ""
echo "==> Task 2 (first-playbook): criar e rodar o playbook"
docker exec "$CONTAINER" sh -c "cat > /app/playbook.yml << 'EOF'
---
- hosts: all
  tasks:
    - name: Instala htop
      ansible.builtin.package:
        name: htop
        state: present
EOF"
docker exec "$CONTAINER" ansible-playbook -i /app/inventory.ini /app/playbook.yml
docker exec "$CONTAINER" which htop
echo "    ✅ passou — htop instalado"

echo ""
echo "==> Task 3 (idempotency): rodar de novo, esperar changed=0"
docker exec "$CONTAINER" sh -c "ansible-playbook -i /app/inventory.ini /app/playbook.yml" | tee /tmp/ansible_run2.txt
if grep -qE 'changed=0' /tmp/ansible_run2.txt; then
  echo "    ✅ passou — segunda execução não mudou nada"
else
  echo "    ❌ falhou — esperava 'changed=0' na saída"
  exit 1
fi

echo ""
echo "==> Testando reset (recovery.reset_command)"
docker exec "$CONTAINER" sh -c "apt-get remove -y htop 2>/dev/null; rm -f /app/playbook.yml; true"
if docker exec "$CONTAINER" sh -c "which htop" >/dev/null 2>&1; then
  echo "    ❌ reset falhou — htop ainda está instalado"
  exit 1
fi
if docker exec "$CONTAINER" sh -c "test -f /app/playbook.yml"; then
  echo "    ❌ reset falhou — playbook.yml ainda existe"
  exit 1
fi
echo "    ✅ reset funcionou — htop removido e playbook.yml apagado"

echo ""
echo "==> Limpando"
docker rm -f "$CONTAINER" >/dev/null

echo ""
echo "🎉 Todos os testes passaram. Pronto pra publicar:"
echo "   docker tag $IMAGE ghcr.io/codisec-io/lab-ansible-fundamentos:latest"
echo "   docker push ghcr.io/codisec-io/lab-ansible-fundamentos:latest"
