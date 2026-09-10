# Prompt para Claude Code — Finalização do Codisec Labs

Copie e cole o texto abaixo (a partir de "## Contexto") direto no Claude
Code, na raiz do repositório descompactado do zip `codisec-labs.zip`.

---

## Contexto

Este repositório é um protótipo funcional de uma plataforma de labs
práticos de AppSec/DevSecOps/DevOps, mas foi construído com um modelo de
**execução server-side** (o backend em `backend/` sobe containers Docker
por sessão de usuário e expõe um terminal via WebSocket). Esse modelo
está **descontinuado por decisão de segurança** e precisa ser substituído
pelo modelo abaixo antes de qualquer deploy em produção.

## Objetivo da tarefa

O projeto cresceu de escopo: agora é o **site definitivo da Codisec**,
não só um catálogo de labs. `codisec.com.br` (e `labs.codisec.com.br`
para a parte de labs, ou tudo no mesmo domínio com `/blog` e `/labs` —
decida a estrutura de rotas, mas justifique) precisa ter:

1. **Blog** — artigos, notícias e novidades do mundo DevOps/AppSec,
   escritos pela equipe. Precisa de: listagem paginada, página de post
   individual, tags/categoria, RSS feed (bom para quem acompanha via
   feed reader), sitemap.xml e meta tags OpenGraph corretas (o link vai
   ser compartilhado no LinkedIn — a preview do card importa).
2. **Catálogo de labs com execução local** — como já definido nas seções
   abaixo deste documento (não mudou).
3. **Qualidade visual "de impressionar"** — existe um mockup de
   referência da homepage em `site-design/index.html` (abra no navegador
   pra ver). Ele define o sistema de design a seguir: paleta navy-tinta
   + âmbar + ciano, tipografia JetBrains Mono (display) + Inter (corpo),
   trilha vertical de "gutter de editor" à esquerda, blog em lista
   editorial (não cards), labs com barra de dificuldade colorida em vez
   de badge genérico, hero com terminal animado mostrando um
   `codisec lab start` de verdade. **Não invente uma direção visual
   nova** — implemente esse sistema de design de forma consistente em
   todas as páginas (blog, post individual, catálogo de labs, página de
   lab), adaptando os componentes (lista de posts, grid de labs, etc.)
   pro conteúdo de cada página.

### Stack recomendada

- **Astro** (https://astro.build) — ideal aqui: gera site 100% estático
  por padrão (bate com o requisito de segurança "zero backend exposto"),
  tem Content Collections nativo pra blog em Markdown/MDX com
  frontmatter tipado, e permite "islands" (componentes interativos
  isolados, ex: filtro de labs por categoria) sem virar uma SPA pesada.
- Conteúdo do blog em Markdown (`src/content/blog/*.md`), com frontmatter
  `title`, `date`, `tags`, `excerpt`, `author`.
- Catálogo de labs continua vindo de `labs/*/lab.yaml` — crie uma
  integração no build do Astro (ou o `scripts/build_catalog.py` já
  citado) que gera as páginas de lab a partir desses arquivos.
- Tailwind CSS é opcional — pode implementar o sistema de design com CSS
  puro/custom properties (como no mockup de referência) ou Tailwind com
  tokens customizados, sua escolha, mas **não use classes utilitárias
  genéricas de forma que o resultado pareça um template Tailwind
  padrão** — o CSS do mockup de referência já define a paleta e os
  componentes, replique a mesma personalidade visual.
- Deploy continua em Cloudflare Pages (build estático do Astro).



### Detalhamento do modelo de labs (não muda em relação à decisão anterior)

- **`labs.codisec.com.br`** (ou a rota `/labs` no domínio principal) é
  **100% estático** (sem backend próprio, sem servidor de aplicação, sem
  porta exposta além de HTTPS público padrão). Serve como
  catálogo/vitrine: lista os labs disponíveis, mostra
  descrição/dificuldade/duração, e para cada lab mostra o comando exato
  que o usuário roda **na própria máquina** para executá-lo.
- Uma **CLI** (o usuário instala localmente, ex: `curl -sSL
  https://labs.codisec.com.br/install.sh | bash`, no mesmo espírito do
  instalador do GIRUS) que:
  - Lê um catálogo estático (`catalog.json` ou `index.yaml`, hospedado
    como arquivo estático junto do site ou em GitHub raw) — leitura
    pública, sem autenticação, sem lógica de servidor por trás.
  - Baixa a definição do lab (`lab.yaml`) e a imagem Docker
    correspondente (publicada no GHCR, pública).
  - Sobe o container **localmente**, na máquina do próprio usuário,
    usando o Docker dele.
  - Abre um terminal **local** (`docker exec -it`, sem WebSocket, sem
    rede exposta) conectando o usuário ao container.
  - Roda a validação de cada tarefa **localmente** (mesmo mecanismo de
    `validation.command` que já existe em `labs/*/lab.yaml` — o schema
    de lab não muda, só quem executa o comando).
  - Remove o container ao final (`codisec lab stop <id>`).

## Requisito de segurança inegociável

**Nenhuma porta, rota, API ou processo do nosso lado deve ficar acessível
pela internet além do próprio site estático.** Isso significa,
explicitamente:

- ❌ Nada de `docker.sock` montado em qualquer coisa acessível via HTTP.
- ❌ Nada de WebSocket de terminal exposto publicamente.
- ❌ Nada de endpoint que execute comandos arbitrários no nosso servidor.
- ❌ Nada de porta de container aberta pro mundo — o container roda na
  máquina do usuário, não na nossa infra.
- ✅ O único artefato nosso acessível pela internet é: o site estático
  (HTML/CSS/JS) + os arquivos estáticos do catálogo (`catalog.json`,
  `lab.yaml` de cada lab) + as imagens Docker públicas no GHCR (que são
  imagens de leitura, não execução — não dão acesso a nada nosso).
- ✅ Se, no futuro, quisermos telemetria (quantas pessoas iniciaram um
  lab), isso deve ser um evento simples enviado de forma assíncrona e
  anônima para um endpoint read-only/append-only bem trancado (ex:
  Cloudflare Worker + KV, ou nem isso no MVP) — nunca algo que aceite
  comandos ou tenha acesso a infraestrutura de execução.

## O que fazer com o código existente

1. **`backend/`, `frontend/`, `docker-compose.yml`**: já foram movidos
   para `legacy/server-side-model/` (com `README.md` explicando a
   descontinuação por segurança). Não deletar ainda, não deve rodar em
   produção — mas pode consultar como referência.
2. **`legacy/server-side-model/frontend/`**: reaproveite o CSS
   (`style.css`) e a estrutura visual dali como ponto de partida, mas
   reescreva a lógica JS na nova estrutura do site (Astro):
   - Listagem de labs: continua mostrando os mesmos dados, mas agora
     vêm de um `catalog.json` estático (gerar a partir de
     `labs/*/lab.yaml` via script, não de uma API).
   - `lab.html` + `lab.js`: **remova** a lógica de "Iniciar Lab"
     server-side, WebSocket e terminal embutido. No lugar, mostre:
     - A descrição, teoria e passos de cada tarefa (isso não muda).
     - Um bloco de comando `codisec lab start <lab-id>` com botão
       "Copiar comando".
     - Instruções de instalação da CLI caso o usuário ainda não tenha
       (link pro `install.sh`).
3. **`labs/*/lab.yaml`, `labs/schema.json`**: o schema de lab **não
   muda** — continua com `tasks[].validation.command` etc. O que muda é
   só quem executa esse comando (a CLI local, não um backend remoto).
4. **`scripts/validate_lab_schema.py`**: mantenha, é usado tanto para
   validar quanto (adicione isso) para **gerar o `catalog.json`** a
   partir dos `lab.yaml` — crie uma nova função/script
   `scripts/build_catalog.py` que lê todos os labs válidos e escreve um
   `catalog.json` na pasta do site estático.
5. **CLI nova** (pasta `cli/`): construa em Go (mesma stack do GIRUS,
   facilita comparação/manutenção) ou Python com PyInstaller, sua
   escolha — mas justifique a escolha em `cli/README.md`. Comandos
   mínimos:
   ```
   codisec lab list
   codisec lab info <id>
   codisec lab start <id>
   codisec lab validate <id> <task-id>
   codisec lab stop <id>
   codisec lab reset <id>
   ```
6. **Instaladores da CLI**, hospedados como arquivos estáticos no site:
   - `install.sh` em `labs.codisec.com.br/install.sh` — para Linux e
     macOS: `curl -sSL https://labs.codisec.com.br/install.sh | bash`.
     Detecta OS/arch, baixa o binário certo de uma GitHub Release, coloca
     no PATH.
   - `install.ps1` em `labs.codisec.com.br/install.ps1` — para Windows
     **nativo** (PowerShell), sem exigir WSL:
     `iwr https://labs.codisec.com.br/install.ps1 -useb | iex`. Baixa o
     binário `windows/amd64` da mesma GitHub Release e adiciona ao PATH
     do usuário. É essencial ter esse instalador nativo — sem ele, o
     usuário Windows precisaria descobrir sozinho que tem que usar WSL2
     ou Git Bash, o que aumenta a barreira de entrada (contradiz o
     objetivo do projeto).
   - Em ambos os casos, **pré-requisito documentado com destaque na
     homepage e na página de cada lab**: Docker Desktop instalado e
     rodando (no Windows, o Docker Desktop já cuida do backend WSL2
     internamente — o usuário não precisa configurar nada manualmente,
     só instalar o Docker Desktop normal e abrir ele antes de rodar
     `codisec lab start`).
7. **`docs/DEPLOY.md`**: reescreva do zero. Não existe mais VPS com
   Docker Compose rodando backend — existe apenas:
   - Build do site estático (pode ser puro HTML/JS, sem build step, ou
     um gerador simples se preferir).
   - Deploy em **Cloudflare Pages** (repositório conectado, deploy
     automático a cada push na branch `main`).
   - Publicação de binários da CLI via **GitHub Releases** (com
     GitHub Actions fazendo o build multi-plataforma: linux/amd64,
     linux/arm64, darwin/amd64, darwin/arm64, windows/amd64).
8. **`docs/SECURITY.md`**: reescreva a seção de riscos — a ameaça agora
   é diferente (integridade da CLI e das imagens, não isolamento de
   container multiusuário no nosso servidor). Cubra:
   - Assinatura/checksum dos binários da CLI (`sha256sum` publicado
     junto com a release, e idealmente `cosign` para assinatura).
   - Garantia de que as imagens Docker dos labs são geradas por CI
     nosso (não aceitar imagem de terceiro sem revisão).
   - Path traversal / injeção no `lab.yaml` (o `validation.command` e
     `reset_command` rodam comandos shell — documente que só
     mantenedores editam `lab.yaml`, nunca input de usuário final vira
     comando).

## DNS / Cloudflare

O domínio `codisec.com.br` já está no Cloudflare. Configure:

- `labs.codisec.com.br` → registro CNAME apontando pro projeto no
  Cloudflare Pages (ex: `codisec-labs.pages.dev`), proxy habilitado
  (nuvem laranja) — isso já dá HTTPS automático e proteção DDoS de
  graça, sem precisar de Caddy/nginx/VPS nenhuma.
- Não crie nenhum registro A/AAAA apontando pra uma VPS a menos que
  decidamos manter alguma peça server-side no futuro (hoje não é o
  caso).
- Se no futuro adicionarmos telemetria via Cloudflare Worker, ele fica
  em outro subdomínio (ex: `events.codisec.com.br`), nunca no mesmo
  host do site — mantenha isso como subdomínio separado por padrão de
  menor superfície de exposição.

## Entregáveis esperados desta tarefa

1. `cli/` com a CLI funcional e testada localmente (`codisec lab start
   devops-docker-fundamentos` funcionando ponta a ponta na sua máquina).
2. `frontend/` (ou pasta renomeada `site/`, se migrar pra Astro) revisado
   com o sistema de design de `site-design/index.html` aplicado, sem
   nenhuma chamada de rede além de buscar `catalog.json` e arquivos
   estáticos.
2b. Blog funcional: pelo menos 3 posts reais publicados (pode reaproveitar
   os temas usados como placeholder no mockup — IDOR, comparação de
   scanners de IaC, gitleaks no CI — mas escritos de verdade, não
   lorem ipsum), RSS feed, sitemap.xml, e OpenGraph tags corretas
   (título, descrição, imagem) pra ficarem bonitos quando compartilhados
   no LinkedIn.
3. `scripts/build_catalog.py` gerando `catalog.json` a partir dos
   `labs/*/lab.yaml`.
4. `install.sh` (Linux/macOS) **e** `install.ps1` (Windows nativo)
   funcionais, testados de verdade em pelo menos um ambiente Windows —
   não assuma que funciona só porque compilou.
5. `.github/workflows/` atualizado: um workflow builda e publica a CLI
   (GitHub Releases) e outro builda o `catalog.json` e faz deploy do
   site estático no Cloudflare Pages a cada push em `main` (branch
   protegida, só mantenedores têm push — sem PR externo, conforme já
   decidido).
6. `docs/DEPLOY.md` e `docs/SECURITY.md` reescritos conforme acima.
7. `legacy/server-side-model/` com o código antigo movido pra lá e um
   aviso claro de "não usar em produção".
8. Um `docs/ARCHITECTURE.md` novo, com um diagrama (pode ser ASCII)
   mostrando o fluxo: usuário → site estático (só leitura) → CLI local
   → Docker local do usuário. Deixe explícito, nesse diagrama, que em
   nenhum ponto o servidor nosso executa código do usuário.

## Fora de escopo (não faça isso)

- Não implemente autenticação de usuário — o site é só leitura pública,
  não precisa de login pra ver o catálogo.
- Não recrie o backend FastAPI/WebSocket de forma alguma, nem "só para
  telemetria" — se telemetria for necessária, decida isso separadamente,
  depois, como um serviço isolado e mínimo.
- Não publique nenhum lab com imagem Docker ainda não construída de
  verdade (os 5 `lab.yaml` atuais referenciam `ghcr.io/codisec/lab-*`
  que ainda não existem — sinalize isso, não invente conteúdo, apenas
  deixe a estrutura pronta para quando as imagens forem publicadas).
