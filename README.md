# 🧪 Codisec — Blog + Labs de AppSec / DevSecOps / DevOps

Site da Codisec, com duas frentes:

1. **Blog** — artigos, notícias e novidades do mundo DevOps/AppSec.
2. **Labs práticos** — laboratórios de AppSec, DevSecOps e DevOps. O
   site é o catálogo/vitrine; a execução do lab acontece **localmente**,
   na máquina do usuário, via CLI + Docker, no mesmo modelo do
   [GIRUS](https://girus.linuxtips.io) da LINUXtips. Isso significa zero
   backend exposto: nada de containers, portas ou terminal remoto
   acessíveis pela internet.

> **Nota de arquitetura:** a versão anterior deste README descrevia um
> modelo de labs com execução server-side (containers no servidor,
> terminal via WebSocket). Esse modelo foi abandonado por razão de
> segurança — ver `docs/SECURITY.md`. O código antigo já foi movido para
> `legacy/server-side-model/` (não faz parte do deploy). O escopo também
> cresceu: o projeto agora é o site completo da Codisec (blog + labs),
> não só o catálogo. Veja o prompt de implementação completo em
> `docs/CLAUDE_CODE_PROMPT.md`.

> **Design de referência:** abra `site-design/index.html` no navegador
> pra ver o sistema de design definido pra homepage (paleta, tipografia,
> componentes de blog e de lab). Toda implementação futura segue essa
> direção visual.

Objetivo: baixar a barreira de entrada pra quem quer aprender essas áreas
com recursos limitados — sem custo, sem precisar de máquina potente, sem
precisar já saber configurar Kubernetes antes de começar a aprender.

## Como funciona

1. O usuário acessa o site e escolhe um lab no catálogo (filtra por
   categoria e dificuldade).
2. Clica em "Iniciar Lab" → o backend sobe um container Docker isolado
   com o ambiente vulnerável/simulado daquele lab.
3. Um terminal real (via WebSocket) abre no navegador, conectado direto
   ao container.
4. O usuário segue os passos (Theory → Practice), tenta a exploração ou a
   configuração pedida, e clica em "Validar" — o backend roda um comando
   de checagem DENTRO do container e confirma objetivamente se a tarefa
   foi concluída (Failure → Recovery quando aplicável).
5. Ao fechar/expirar (TTL de 1h), o container é destruído — cada sessão
   começa limpa.

## Arquitetura

```
┌──────────────┐      HTTP/WS      ┌──────────────┐     Docker API     ┌─────────────────┐
│  Frontend     │ ───────────────▶ │   Backend    │ ─────────────────▶ │ Containers dos   │
│  (HTML/JS)    │ ◀─────────────── │  (FastAPI)   │ ◀───────────────── │ Labs (isolados)  │
└──────────────┘                   └──────┬───────┘                    └─────────────────┘
                                           │
                                           ▼
                                    ┌──────────────┐
                                    │  /labs/*.yaml │  ← catálogo, editável via PR
                                    └──────────────┘
```

## Rodando localmente (dev)

Pré-requisito: Docker instalado e rodando.

```bash
git clone https://github.com/codisec/codisec-labs.git
cd codisec-labs
docker compose up -d --build
```

Abra `http://localhost:8080` no navegador. O backend responde em
`http://localhost:8000`.

Pra derrubar tudo: `docker compose down`

## Labs incluídos nesta versão

| Lab | Categoria | Dificuldade | Duração |
|---|---|---|---|
| IDOR em API REST | appsec | beginner | 30m |
| SSRF em serviço de preview | appsec | intermediate | 40m |
| Segurança de IaC com tfsec | devsecops | intermediate | 45m |
| Detecção de secrets com gitleaks | devsecops | beginner | 25m |
| Fundamentos de Docker | devops | beginner | 30m |

## Contribuindo

A adição e edição de labs é feita apenas pela equipe mantenedora (não
aceitamos Pull Requests externos, por controle de qualidade e segurança
sobre o que roda dentro dos containers). Toda mudança em `/labs` passa
pela validação automática da GitHub Action
(`.github/workflows/validate-labs.yml`) antes de ir pra produção.

Quer sugerir um lab novo ou uma funcionalidade? Abra uma
[Issue com o template Feature Request](https://github.com/codisec/codisec-labs/issues/new/choose) — não precisa saber programar.

## Deploy em produção

Veja [docs/DEPLOY.md](docs/DEPLOY.md) para o passo a passo de colocar isso
no ar numa VPS barata com domínio próprio e HTTPS.

## Segurança

**Leia antes de expor publicamente:** [docs/SECURITY.md](docs/SECURITY.md)
explica os riscos do modelo de isolamento do MVP (containers com acesso
ao Docker socket do host) e os caminhos de evolução (gVisor, Kata
Containers, cluster Kind dedicado) conforme o projeto cresce.

## Licença

GPL-3.0 (mesma linha do GIRUS) — qualquer modificação distribuída precisa
continuar open-source.
