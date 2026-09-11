# 🧪 Codisec — Blog + Labs de AppSec / DevSecOps / DevOps

Site da Codisec, com duas frentes:

1. **Blog** — artigos, notícias e novidades do mundo DevOps/AppSec.
2. **Labs práticos** — laboratórios de AppSec, DevSecOps e DevOps. O
   site é o catálogo/vitrine; a execução do lab acontece **localmente**,
   na máquina do usuário, via CLI + Docker, no mesmo modelo do
   [GIRUS](https://girus.linuxtips.io) da LINUXtips. Isso significa zero
   backend exposto: nada de containers, portas ou terminal remoto
   acessíveis pela internet — ver `docs/ARCHITECTURE.md`.

Objetivo: baixar a barreira de entrada pra quem quer aprender essas áreas
com recursos limitados — sem custo, sem precisar de máquina potente, sem
precisar já saber configurar Kubernetes antes de começar a aprender.

## Como funciona

1. O usuário instala a CLI (`curl -sSL https://codisec.com.br/install.sh
   | bash`, ou `install.ps1` no Windows).
2. Acessa o site e escolhe um lab no catálogo (`/labs`, filtra por
   categoria e dificuldade).
3. Roda `codisec lab start <id>` — a CLI baixa a imagem Docker pública
   do lab e sobe um container **na própria máquina do usuário**, com o
   Docker dele.
4. Um terminal local abre (`docker exec -it`, sem WebSocket, sem porta
   exposta pro mundo), conectado ao container.
5. O usuário segue os passos (Theory → Practice), tenta a exploração ou a
   configuração pedida, e roda `codisec lab validate <id> <task-id>` —
   a CLI roda um comando de checagem DENTRO do container e confirma
   objetivamente se a tarefa foi concluída (Failure → Recovery via
   `codisec lab reset <id>` quando aplicável).
6. `codisec lab stop <id>` derruba o container — cada sessão começa
   limpa na próxima vez.

## Arquitetura

```
Navegador → codisec.com.br (Astro, Cloudflare Pages, só leitura)
                    │ copia o comando
                    ▼
        CLI local (codisec) → Docker local do usuário → container do lab
```

Nenhum ponto desse fluxo passa pelo nosso servidor além de servir
arquivos estáticos. Ver `docs/ARCHITECTURE.md` pro diagrama completo
(incluindo o fluxo de publicação: push → GitHub Actions → GHCR/Releases/
Cloudflare Pages).

## Rodando o site localmente (dev)

Pré-requisito: Node 22+ (100% Node — não precisa de Python pra
buildar/rodar o site).

```bash
git clone https://github.com/codisec-io/codisec-labs.git
cd codisec-labs/site
npm install
npm run dev
```

Abra `http://localhost:4321`. O `npm run dev`/`npm run build` já rodam
`site/scripts/build-catalog.mjs` sozinhos antes (hook
`predev`/`prebuild` em `site/package.json`) pra gerar `catalog.json` a
partir dos `labs/*/lab.yaml`.

## Rodando a CLI localmente (dev)

Pré-requisito: Go 1.23+ e Docker instalado e rodando.

```bash
cd cli
go build -o codisec .
./codisec lab list
```

Ver `cli/README.md` para mais detalhes (por que Go, estrutura interna,
como testar).

## Labs incluídos nesta versão

11 labs validados em `labs/*/lab.yaml` (appsec, devsecops, devops,
níveis iniciante/intermediário) — `codisec lab list` ou
[`/labs`](https://codisec.com.br/labs) no site mostram o catálogo
completo e atualizado. Nenhuma das imagens Docker (`ghcr.io/codisec/lab-*`)
foi publicada ainda — é o próximo passo (ver `docs/CHECKLIST.md`, Fase 2).
Uma exceção: o lab `devops-docker-fundamentos` usa `docker:24-dind`, uma
imagem pública já pullável hoje.

## Contribuindo

A adição e edição de labs é feita apenas pela equipe mantenedora (não
aceitamos Pull Requests externos, por controle de qualidade e segurança
sobre o que roda dentro dos containers). Toda mudança em `/labs` passa
pela validação automática da GitHub Action
(`.github/workflows/validate-labs.yml`) antes de ir pra produção.

Quer sugerir um lab novo ou uma funcionalidade? Abra uma
[Issue com o template Feature Request](https://github.com/codisec-io/codisec-labs/issues/new/choose) — não precisa saber programar.

## Deploy em produção

Veja [docs/DEPLOY.md](docs/DEPLOY.md) para o passo a passo: site no
Cloudflare Pages, CLI distribuída via GitHub Releases.

## Segurança

**Leia antes de expor publicamente:** [docs/SECURITY.md](docs/SECURITY.md)
cobre o modelo de ameaça atual — integridade do binário da CLI e das
imagens Docker dos labs, e por que a origem do catálogo é fixa em
código na CLI.

## Licença

GPL-3.0 (mesma linha do GIRUS) — qualquer modificação distribuída precisa
continuar open-source.
