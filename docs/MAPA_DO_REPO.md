# Mapa do repositório

Visão rápida do que é cada coisa, na ordem em que você provavelmente vai
usar (comece pelo `docs/CHECKLIST.md`).

## Comece aqui

| Arquivo | O que é |
|---|---|
| `docs/CHECKLIST.md` | Checklist passo a passo pra colocar o projeto no ar (você é o primeiro testador) |
| `docs/CLAUDE_CODE_PROMPT.md` | Cole isso no Claude Code — é a especificação completa do que falta construir (CLI, site Astro, blog, instaladores) |
| `site-design/index.html` | Abra no navegador — é o design de referência da homepage. Toda implementação futura segue essa direção visual |

## Labs (o conteúdo em si)

| Pasta | O que é |
|---|---|
| `labs/*/lab.yaml` | 11 labs prontos e validados — 4 appsec, 4 devsecops, 3 devops, níveis iniciante e intermediário |
| `labs/schema.json` | Contrato formal que todo `lab.yaml` precisa seguir |
| `scripts/validate_lab_schema.py` | Roda a validação localmente: `python3 scripts/validate_lab_schema.py` |

**Pendente:** nenhuma das 11 imagens Docker (`ghcr.io/codisec/lab-*`)
referenciadas nos `lab.yaml` foi construída ainda — é o próximo passo
depois do site/CLI estarem no ar (Fase 2 do checklist).

## Documentação

| Arquivo | O que é |
|---|---|
| `docs/DEPLOY.md` | Passo a passo de deploy (ainda reflete o modelo antigo — o Claude Code vai reescrever conforme o prompt) |
| `docs/SECURITY.md` | Modelo de ameaça e por que a execução é local, não server-side |
| `README.md` | Visão geral do projeto |
| `CONTRIBUTING.md` | Processo interno de adicionar/editar lab (fechado — sem PR externo) |

## Colaboração / CI

| Arquivo | O que é |
|---|---|
| `.github/workflows/validate-labs.yml` | Valida todo `lab.yaml` automaticamente a cada push |
| `.github/ISSUE_TEMPLATE/` | Templates de Feature Request e Bug pra quem quiser sugerir algo |

## Código legado (não usar em produção)

| Pasta | O que é |
|---|---|
| `legacy/server-side-model/` | Primeira versão (backend FastAPI + containers server-side). Descontinuada por segurança — ver `legacy/server-side-model/README.md`. Fica só como referência histórica do schema |

## O que NÃO existe ainda (fica pro Claude Code construir, via o prompt)

- `cli/` — a CLI (`codisec lab start/list/validate/stop`)
- Site em Astro (blog + catálogo de labs renderizado a partir de `catalog.json`)
- `install.sh` / `install.ps1`
- `scripts/build_catalog.py`
- GitHub Actions de build da CLI e deploy no Cloudflare Pages
