# Arquitetura

Este documento existe pra deixar explícito, num só lugar, o requisito de
segurança inegociável do projeto (ver `docs/CLAUDE_CODE_PROMPT.md`):
**nenhuma porta, rota, API ou processo do nosso lado fica acessível pela
internet além do próprio site estático.** Tudo que executa código —
containers de lab — roda na máquina do usuário, nunca na nossa infra.

## Fluxo de leitura (o que um usuário faz)

```
┌──────────┐   HTTPS (GET)   ┌───────────────────┐
│ Navegador │ ──────────────▶ │  codisec.com.br    │   site estático
│           │ ◀────────────── │  (Cloudflare Pages) │   (Astro), só leitura
└──────────┘                  └───────────────────┘
                                        │
                                        │ copia o comando
                                        ▼
┌──────────────────────────────────────────────────────────┐
│  Máquina do usuário                                        │
│                                                              │
│   codisec (CLI local)                                       │
│      │                                                       │
│      │ GET https://codisec.com.br/catalog.json               │
│      │ GET https://codisec.com.br/labs/<id>.json              │  única
│      ▼                                                       │  origem
│   fala com o Docker LOCAL do usuário (socket local)           │  fixa em
│      │                                                       │  código —
│      ▼                                                       │  sem flag
│   docker pull ghcr.io/codisec/lab-<nome>  (imagem pública)     │  nem env
│      │                                                       │  var pra
│      ▼                                                       │  trocar
│   container do lab roda 100% local                            │
│   (docker exec -it — terminal local, sem WebSocket,            │
│    sem porta exposta pro mundo)                                │
└──────────────────────────────────────────────────────────┘
```

Em nenhum ponto desse fluxo o nosso servidor executa código do usuário,
recebe upload, ou expõe um endpoint que aceite comando. O único artefato
nosso acessível pela internet é: o site estático (HTML/CSS/JS), o
catálogo (`catalog.json`, `labs/<id>.json`), os instaladores
(`install.sh`, `install.ps1`) e as imagens Docker públicas no GHCR
(leitura, não execução — puxar uma imagem não dá acesso a nada nosso).

## Fluxo de escrita (o que um mantenedor faz)

```
mantenedor
   │  git push main (branch protegida — sem PR externo, ver CONTRIBUTING.md)
   ▼
┌───────────────────────────────────────────────────────────┐
│  GitHub Actions                                              │
│                                                                │
│  push em labs/**           → validate-labs.yml                │
│                                (valida todo lab.yaml contra     │
│                                 labs/schema.json)               │
│                                                                │
│  push em site/**, labs/**  → deploy-site.yml                   │
│                                (gera catalog.json via            │
│                                 scripts/build_catalog.py,         │
│                                 builda o Astro, publica no        │
│                                 Cloudflare Pages)                  │
│                                                                │
│  tag v*.*.*                → release-cli.yml                    │
│                                (goreleaser: builda os 5 binários  │
│                                 da CLI, assina com cosign,         │
│                                 publica em GitHub Releases)         │
└───────────────────────────────────────────────────────────┘
```

Imagens Docker dos labs (`ghcr.io/codisec/lab-*`) são publicadas
separadamente, por CI próprio de cada lab (fora de escopo deste
documento — ver `docs/CHECKLIST.md` Fase 2). O ponto de segurança
relevante aqui: só o nosso CI publica nessas tags, nunca uma imagem de
terceiro é referenciada num `lab.yaml` sem revisão de um mantenedor.

## Por que cada peça está onde está

| Peça | Onde roda | Por quê |
|---|---|---|
| Site (blog + catálogo) | Cloudflare Pages | Estático, HTTPS/CDN automático, sem servidor pra manter |
| `catalog.json` / `labs/<id>.json` | Gerado no build, servido como estático | Fonte única: `labs/*/lab.yaml`; nunca editado à mão |
| Terminal do lab | `docker exec -it` local | Sem WebSocket, sem porta exposta — é o motivo do projeto ter abandonado o modelo antigo (ver `legacy/server-side-model/README.md`) |
| Container do lab | Docker do usuário | Zero custo de infra nosso, zero superfície de ataque multiusuário |
| CLI | Binário local, instalado via `install.sh`/`install.ps1` | Só ela sabe falar com o Docker local; o site nunca tenta |

## Domínio único

`codisec.com.br` serve tudo (`/`, `/blog`, `/labs`, `/install.sh`,
`/catalog.json` etc.) num só projeto Astro/Cloudflare Pages.
`labs.codisec.com.br`, mencionado no prompt original, vira um *Bulk
Redirect* de zona no Cloudflare (301, preserva o path) pro domínio
principal — evita duplicar build/deploy e conteúdo duplicado pra SEO,
e ainda assim `curl -sSL https://labs.codisec.com.br/install.sh | bash`
continua funcionando (`curl -L`/`iwr` seguem redirect). Ver
`docs/DEPLOY.md` para a configuração exata.
