# Deploy em produção

> **Se você chegou aqui procurando o guia antigo de VPS + Docker
> Compose:** esse modelo foi descontinuado por decisão de segurança —
> ver `docs/SECURITY.md` e `legacy/server-side-model/README.md`. Hoje
> não existe backend nosso pra fazer deploy — só site estático (Astro,
> no Cloudflare Pages) e uma CLI distribuída via GitHub Releases. Ver
> `docs/ARCHITECTURE.md` para o desenho completo.

## 1. Site estático no Cloudflare Pages

O domínio `codisec.com.br` já está no Cloudflare.

1. Painel do Cloudflare → **Pages** → **Create a project** → conectar
   o repositório GitHub (`codisec/codisec-labs`).
2. Configuração de build:
   - **Build command:**
     ```bash
     npm --prefix site ci && npm --prefix site run build
     ```
     (100% Node — `npm run build` já gera o `catalog.json` sozinho via
     `site/scripts/build-catalog.mjs`, hook `prebuild` em
     `site/package.json`. Não precisa de Python/pip no ambiente de
     build; uma versão anterior deste comando dependia de `pip install
     pyyaml jsonschema`, que quebrava porque o ambiente de build da
     Cloudflare não tem Python configurado por padrão.)
   - **Build output directory:** `site/dist`
   - **Root directory:** `/` (raiz do repo — o comando de build já entra
     em `site/` sozinho)
3. Adicionar o domínio customizado `codisec.com.br` ao projeto (painel
   do projeto → Custom domains).
4. Todo push em `main` que toque `site/**` ou `labs/**` dispara um novo
   deploy automaticamente.

**Alternativa com GitHub Actions:** `.github/workflows/deploy-site.yml`
já existe pronto, fazendo o mesmo build e publicando via
`cloudflare/pages-action`. Usar essa opção em vez da integração nativa
do painel dá mais controle/log, mas exige configurar dois secrets no
repositório: `CLOUDFLARE_API_TOKEN` (token com permissão de Pages:Edit)
e `CLOUDFLARE_ACCOUNT_ID`. Escolha uma das duas — não configure as duas
ao mesmo tempo (deploy duplicado).

### Redirect de `labs.codisec.com.br`

No DNS do Cloudflare, painel → **Rules → Redirect Rules** (ou **Bulk
Redirects**), criar um redirect 301 preservando o path:

```
labs.codisec.com.br/*  →  https://codisec.com.br/$1
```

Isso mantém `curl -sSL https://labs.codisec.com.br/install.sh | bash`
funcionando (curl segue redirect) sem precisar de um segundo projeto
Cloudflare Pages. Ver `docs/ARCHITECTURE.md` pra o porquê dessa decisão.

## 2. Release da CLI (GitHub Releases)

A CLI (`cli/`) é distribuída como binário via GitHub Releases, buildada
pelo GoReleaser (`cli/.goreleaser.yml`).

1. Garanta que `cli/` builda e testa limpo:
   ```bash
   cd cli && go build ./... && go test ./...
   ```
2. **Antes da primeira release de verdade**, valide o `.goreleaser.yml`
   localmente (ele ainda não foi rodado de ponta a ponta):
   ```bash
   cd cli && goreleaser release --snapshot --clean
   ```
3. Crie e envie uma tag semântica:
   ```bash
   git tag v0.1.0
   git push origin v0.1.0
   ```
4. `.github/workflows/release-cli.yml` dispara sozinho: builda os 5
   binários (linux/amd64, linux/arm64, darwin/amd64, darwin/arm64,
   windows/amd64), gera `checksums.txt`, assina com `cosign` (keyless,
   via OIDC do GitHub Actions — não precisa gerenciar chave privada) e
   publica tudo em GitHub Releases.
5. Confirme em `github.com/codisec/codisec-labs/releases` que os
   arquivos `codisec_<os>_<arch>.tar.gz`/`.zip` e `checksums.txt`
   apareceram.

`site/public/install.sh` e `install.ps1` resolvem sempre a **última**
release via `api.github.com/repos/codisec/codisec-labs/releases/latest`
— não precisa atualizar nada no site quando uma nova versão da CLI sai.

## 3. Checklist pós-deploy

- [ ] `https://codisec.com.br` abre com HTTPS válido
- [ ] `https://codisec.com.br/catalog.json` retorna os 11 labs
- [ ] `https://codisec.com.br/labs/<id>` abre pra qualquer lab do catálogo
- [ ] `curl -sSL https://codisec.com.br/install.sh | bash` instala a CLI
      numa máquina limpa e `codisec lab list` funciona
- [ ] `https://labs.codisec.com.br` redireciona pra `codisec.com.br`

Ver `docs/CHECKLIST.md` para o roteiro completo, passo a passo, de
colocar tudo no ar pela primeira vez.
