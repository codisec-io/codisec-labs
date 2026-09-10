# Deploy em produção (VPS barata)

Guia tutorial, passo a passo, para colocar a plataforma no ar num servidor
tipo Hetzner CX22 (~€4/mês) ou DigitalOcean Droplet básico (~$6/mês) —
qualquer VPS com Ubuntu 22.04+, 2GB RAM, resolve pro tamanho inicial do
projeto.

## 1. Provisionar o servidor

1. Crie a VPS com Ubuntu 22.04 LTS.
2. Aponte um domínio (ou subdomínio, ex: `labs.seudominio.com`) para o IP
   da VPS via registro DNS tipo A.
3. Conecte via SSH: `ssh root@SEU_IP`

## 2. Instalar Docker e Docker Compose

Rode isso direto no servidor, via SSH:

```bash
curl -fsSL https://get.docker.com | sh
apt install -y docker-compose-plugin git
```

## 3. Clonar o repositório

```bash
git clone https://github.com/codisec/codisec-labs.git
cd codisec-labs
```

## 4. Ajustar configuração de produção

Edite `frontend/config.js` e troque `codisec.com.br` pelo domínio real
que você apontou no passo 1:

```bash
nano frontend/config.js
```

Edite `backend/main.py` e troque `allow_origins=["*"]` pelo domínio real
do frontend (por segurança — veja `docs/SECURITY.md`):

```bash
nano backend/main.py
```

## 5. Subir os containers

```bash
docker compose up -d --build
```

Confira se subiu certo:

```bash
docker compose ps
curl http://localhost:8000/api/labs
```

Deve retornar um JSON com a lista de labs.

## 6. Colocar HTTPS na frente (Caddy, mais simples que nginx+certbot)

```bash
apt install -y debian-keyring debian-archive-keyring apt-transport-https
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list
apt update && apt install -y caddy
```

Edite `/etc/caddy/Caddyfile`:

```
labs.seudominio.com {
    reverse_proxy /api/* localhost:8000
    reverse_proxy /ws/* localhost:8000
    reverse_proxy localhost:8080
}
```

Reinicie o Caddy: `systemctl restart caddy`. Ele já cuida do certificado
TLS automaticamente via Let's Encrypt.

## 7. Recarregar labs depois de um merge de PR (automatizar com GitHub Actions)

Adicione um segundo job na Action `validate-labs.yml` (ou crie um workflow
separado `deploy.yml`) que, depois do merge na branch `main`, faz SSH no
servidor e roda:

```bash
cd /root/codisec-labs && git pull && curl -X POST http://localhost:8000/api/admin/reload
```

Isso fecha o ciclo colaborativo: PR aprovado e mergeado → labs aparecem
no site automaticamente, sem downtime e sem precisar reiniciar o backend.

## 8. Monitoramento básico (opcional, recomendado)

```bash
docker compose logs -f backend
```

Para algo mais robusto, considere expor `/api/labs` num healthcheck
externo (ex: UptimeRobot, grátis) apontando pro seu domínio.
