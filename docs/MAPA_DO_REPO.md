# Mapa do repositório

Visão rápida do que é cada coisa.

## Site (Astro) e catálogo de labs

| Pasta/arquivo | O que é |
|---|---|
| `site/` | Site em Astro — home, `/blog` (posts em Markdown), `/labs` (catálogo com filtro), `/labs/<id>` (detalhe de cada lab), `/install.sh`, `/install.ps1`, `/rss.xml`. Deploy no Cloudflare Pages. |
| `site/src/content/blog/*.md` | Posts do blog, frontmatter tipado (title, date, tags, excerpt, author). |
| `site/src/content.config.ts` | Define as duas Content Collections: `blog` (Markdown local) e `labs` (lê `labs/*/lab.yaml` direto da raiz do repo via Content Layer `glob()` — não duplica os arquivos dentro de `site/`). |
| `labs/*/lab.yaml` | 11 labs — 4 appsec, 4 devsecops, 3 devops. Fonte da verdade de todo o catálogo. |
| `labs/schema.json` | Contrato formal que todo `lab.yaml` precisa seguir. |
| `scripts/validate_lab_schema.py` | Valida todos os `lab.yaml` contra o schema: `python3 scripts/validate_lab_schema.py` (`pip install -r scripts/requirements.txt` antes). Usado pelo gate de CI em `.github/workflows/validate-labs.yml` — único lugar que ainda usa Python no repo. |
| `scripts/_lab_common.py` | Lógica de parse+validação usada por `validate_lab_schema.py`. |
| `site/scripts/build-catalog.mjs` | Gera `site/public/catalog.json` e `site/public/labs/<id>.json` a partir dos `lab.yaml` válidos (Node — `js-yaml` + `ajv`) — consumido pelo site (filtro client-side) e pela CLI. Roda automaticamente antes de `npm run dev`/`build` (ver `site/package.json`). Substitui a versão antiga em Python, que quebrava o deploy na Cloudflare Pages por depender de `pip install` num ambiente sem Python configurado. |

**Pendente:** nenhuma das imagens Docker (`ghcr.io/codisec/lab-*`)
referenciadas nos `lab.yaml` foi construída ainda, exceto
`devops-docker-fundamentos` (usa `docker:24-dind`, pública). É o
próximo passo — Fase 2 do `docs/CHECKLIST.md`.

## CLI

| Pasta/arquivo | O que é |
|---|---|
| `cli/` | CLI em Go (`codisec lab list/info/start/validate/stop/reset`) — roda os labs localmente no Docker do usuário. Ver `cli/README.md` pra justificativa da escolha de linguagem e detalhes internos. |
| `cli/.goreleaser.yml` | Build multi-plataforma (5 binários) + checksums + assinatura cosign, disparado por tag via `.github/workflows/release-cli.yml`. |

## Documentação

| Arquivo | O que é |
|---|---|
| `docs/ARCHITECTURE.md` | Diagrama do fluxo completo: usuário → site estático → CLI local → Docker local; e o fluxo de publicação (push → Actions → GHCR/Releases/Pages). |
| `docs/DEPLOY.md` | Passo a passo de deploy: Cloudflare Pages pro site, GitHub Releases pra CLI. |
| `docs/SECURITY.md` | Modelo de ameaça atual: integridade do binário da CLI e das imagens Docker, origem do catálogo fixa em código. |
| `docs/CHECKLIST.md` | Checklist de colocar tudo no ar pela primeira vez. |
| `docs/CLAUDE_CODE_PROMPT.md` | A especificação original que guiou a implementação — histórico, não precisa ler de novo pra usar o projeto. |
| `README.md` | Visão geral do projeto. |
| `CONTRIBUTING.md` | Processo interno de adicionar/editar lab (fechado — sem PR externo). |

## Colaboração / CI

| Arquivo | O que é |
|---|---|
| `.github/workflows/validate-labs.yml` | Valida todo `lab.yaml` automaticamente a cada push/PR tocando `labs/**`. |
| `.github/workflows/ci-cli.yml` | `go vet`/`build`/`test` (com testes de integração reais contra Docker) a cada push/PR tocando `cli/**`. |
| `.github/workflows/release-cli.yml` | Builda e publica a CLI em GitHub Releases numa tag `v*.*.*`. |
| `.github/workflows/deploy-site.yml` | Builda o catálogo + o site e publica no Cloudflare Pages a cada push em `main`. |
| `.github/ISSUE_TEMPLATE/` | Templates de Feature Request e Bug pra quem quiser sugerir algo. |

## Código legado (não usar em produção)

| Pasta | O que é |
|---|---|
| `legacy/server-side-model/` | Primeira versão (backend FastAPI + containers server-side). Descontinuada por segurança — ver `legacy/server-side-model/README.md`. Fica só como referência histórica do schema original de lab. |

## Design de referência

| Arquivo | O que é |
|---|---|
| `site-design/index.html` | Mockup standalone que define o sistema de design (paleta navy/âmbar/ciano, tipografia, componentes) — já implementado em `site/src/styles/` e nos componentes Astro. Fica como referência visual permanente. |
