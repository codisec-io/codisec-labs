# Checklist — Colocar o Codisec no ar

Ordem pensada pra você (Fernando) testar cada etapa antes de avançar pra
próxima. Marque conforme for concluindo.

> **Fases 0 e 1 já concluídas nesta sessão** (commits em `main`, ver
> `git log`): repositório git inicializado, domínio decidido (único,
> `codisec.com.br`, com redirect de `labs.codisec.com.br` — ver
> `docs/ARCHITECTURE.md`), e todo o escopo do
> `docs/CLAUDE_CODE_PROMPT.md` implementado: `cli/`, site em Astro
> (blog com 3 posts reais + catálogo de labs), `install.sh` +
> `install.ps1`, `site/scripts/build-catalog.mjs`, os 4 workflows de GitHub
> Actions, `docs/ARCHITECTURE.md`/`DEPLOY.md`/`SECURITY.md`
> reescritos. Verificado: build do site, testes da CLI (incluindo
> integração real contra Docker) e `install.sh` (contra um fixture
> local) todos passando. **Ainda não verificado nesta sessão:**
> `install.ps1` num Windows de verdade, e `cli/.goreleaser.yml` rodando
> de ponta a ponta (sem repositório remoto/tag real ainda) — seguem
> pendentes abaixo, nas fases originais.

---

## Fase 0 — Decisões antes de começar

- [x] Estrutura de domínio: único domínio `codisec.com.br`, com
      `labs.codisec.com.br` como redirect — decidido e documentado em
      `docs/ARCHITECTURE.md`.
- [ ] Confirmar que o Docker Desktop está instalado e rodando na sua
      máquina (necessário pra `cli/`, testado nesta sessão contra o
      Docker do ambiente de dev — confirme que está igual na sua)
- [x] Remote no GitHub criado e conectado —
      `github.com/Ferhummes84/codisec-labs` (conta pessoal, não a
      organização `codisec` que `cli/go.mod`, `cli/.goreleaser.yml` e
      os `install.sh`/`install.ps1` ainda assumem). **Pendente decidir:**
      migrar pra uma org `codisec` depois, ou ajustar essas referências
      pro nome real do repo agora — enquanto não for decidido,
      `install.sh`/`install.ps1` e o release da CLI (`goreleaser`) vão
      resolver a URL errada. Não mexi nisso nesta sessão por ser fora do
      escopo pedido (correção do build da Cloudflare) — sinalizando pra
      você decidir.
- [ ] Criar conta no Cloudflare Pages (se ainda não tiver) — o domínio
      `codisec.com.br` já está no Cloudflare, então é só conectar o
      projeto (ver `docs/DEPLOY.md`)

## Fase 1 — Implementação do escopo do CLAUDE_CODE_PROMPT.md

- [x] `cli/`, site em Astro (blog + catálogo de labs), `install.sh` +
      `install.ps1`, `site/scripts/build-catalog.mjs`, GitHub Actions de
      build/deploy, `legacy/server-side-model/` com o código antigo —
      tudo gerado e commitado nesta sessão.
- [x] Revisado: nenhum endpoint HTTP novo foi criado além do site
      estático (a CLI só fala com `codisec.com.br` — leitura de
      catálogo estático — e com o Docker local do usuário; ver
      `docs/SECURITY.md`).

## Fase 2 — Construir as imagens Docker dos labs (o que falta desde o início)

Você tem 11 `lab.yaml` prontos, mas nenhuma das imagens
`ghcr.io/codisec/lab-*` existe ainda. Pra cada lab:

- [ ] Escrever o Dockerfile + código-fonte do ambiente vulnerável/simulado
      (o Flask com IDOR, o repo com secret vazado, etc — posso montar
      isso com você, lab por lab, é o próximo passo natural depois deste
      checklist)
- [ ] Testar a imagem localmente antes de publicar:
      ```bash
      docker build -t lab-teste:local .
      docker run --rm -it -p 5000:5000 lab-teste:local
      ```
- [ ] Confirmar manualmente que os comandos de `validation` de cada
      task do `lab.yaml` realmente passam contra essa imagem rodando
- [ ] Publicar no GHCR:
      ```bash
      echo $GITHUB_TOKEN | docker login ghcr.io -u codisec --password-stdin
      docker build -t ghcr.io/codisec/lab-<nome>:latest .
      docker push ghcr.io/codisec/lab-<nome>:latest
      ```
- [ ] Repetir pra pelo menos **3 labs** antes de seguir pra Fase 3 (não
      precisa publicar os 11 de uma vez — 3 já dá pra testar o fluxo
      inteiro ponta a ponta)

## Fase 3 — Você testa localmente (primeiro tester)

- [x] Compilar a CLI localmente (`cd cli && go build -o codisec .`) —
      já feito e testado nesta sessão, incluindo um ciclo completo
      start→validate→stop contra Docker real (ver commit "CLI codisec
      em Go"), mas contra um catálogo local temporário, não o de
      produção (que ainda não existe — ver Fase 4). Vale repetir
      contra os labs reais assim que publicados (Fase 2).
- [ ] Rodar `./codisec lab list` contra o catálogo publicado de verdade
      em `codisec.com.br` — confirma que lê certo em produção
- [ ] Rodar `./codisec lab start <um-dos-3-labs-publicados>`
- [ ] Confirmar que o terminal abre e conecta no container
- [ ] Seguir os passos do lab você mesmo, do jeito que um usuário
      seguiria — teoria, comando, validação
- [ ] Rodar `./codisec lab validate <id> <task-id>` em cada tarefa e
      conferir se a mensagem de sucesso/erro faz sentido
- [ ] Rodar `./codisec lab stop <id>` e confirmar que o container some
      (`docker ps` não deve mais listar ele)
- [ ] Testar o `break_again_command` / `recovery.reset_command`
      (`codisec lab reset <id>`) de pelo menos 1 lab, pra confirmar que
      o ciclo Failure→Recovery funciona

## Fase 4 — Site estático no ar

- [ ] Rodar o build do site localmente (Astro: `npm run build` dentro
      da pasta do site) e abrir o resultado (`npm run preview`) pra
      conferir visualmente antes de publicar
- [ ] Conectar o repositório no Cloudflare Pages (painel do Cloudflare
      → Pages → "Create a project" → conectar o repo GitHub)
- [ ] Configurar o build command e output directory do Astro no
      Cloudflare Pages (geralmente `npm run build` e `dist/`)
- [ ] No DNS do Cloudflare, apontar `codisec.com.br` (Custom domain do
      projeto Cloudflare Pages) com proxy (nuvem laranja) ligado
- [ ] Criar a Redirect Rule de `labs.codisec.com.br/*` →
      `https://codisec.com.br/$1` (ver `docs/DEPLOY.md`, seção 1)
- [ ] Esperar propagar e abrir o domínio real no navegador — confirmar
      que carrega com HTTPS automático, e que
      `labs.codisec.com.br/install.sh` redireciona certo

## Fase 5 — Publicar a CLI de verdade (GitHub Releases)

- [ ] Confirmar que o GitHub Action de build multi-plataforma
      (linux/amd64, linux/arm64, darwin/amd64, darwin/arm64,
      windows/amd64) roda sem erro
- [ ] Criar uma tag/release (ex: `v0.1.0`) e conferir que os binários
      aparecem em GitHub Releases
- [ ] Subir `install.sh` e `install.ps1` pro site estático
- [ ] Testar a instalação do zero, numa máquina limpa se possível (ou
      pelo menos num diretório novo, removendo a CLI compilada
      manualmente antes):
      ```bash
      curl -sSL https://labs.codisec.com.br/install.sh | bash
      codisec lab list
      ```

## Fase 6 — Teste end-to-end em produção (você de novo, agora "de fora")

- [ ] Fechar o terminal onde você estava desenvolvendo, abrir um
      terminal novo "como se fosse a primeira vez"
- [ ] Repetir o fluxo completo da Fase 3, mas usando a CLI instalada
      via `install.sh`/`install.ps1` (não a compilada localmente) e o
      site em produção (não localhost)
- [ ] Testar pelo menos 1 lab de cada categoria (appsec, devsecops,
      devops) publicada
- [ ] Testar em outro dispositivo se possível (ex: seu Windows 11, já
      que você mencionou ser esse o seu OS principal)

## Fase 7 — Antes de compartilhar no LinkedIn

- [ ] Conferir OpenGraph: colar o link do site num validador tipo
      https://www.opengraph.xyz/ pra ver como o card vai aparecer
- [ ] Escrever/revisar os 3 primeiros posts do blog (ainda pendente —
      os títulos usados no mockup são só placeholder)
- [ ] Decidir e aplicar alguma proteção básica contra abuso (rate limit
      por IP na distribuição da CLI, ou pelo menos monitorar o
      GitHub Releases download count nos primeiros dias) — não é
      bloqueante, mas evita surpresa se o post viralizar
- [ ] Revisar `docs/SECURITY.md` uma última vez e confirmar que nada
      além do site estático está exposto publicamente
- [ ] Escrever o texto do post do LinkedIn (explicando o projeto, o
      "porquê", e o link) — feliz em ajudar a redigir isso quando
      chegar a hora

---

**Ordem recomendada de execução:** Fase 0 → 1 → 2 (3 labs) → 3 → 4 → 5 →
6 → (Fases 2 de novo, pros outros 8 labs, em paralelo com uso normal) →
7. Não espere ter os 11 labs prontos pra começar a testar — 3 já validam
o fluxo inteiro.
