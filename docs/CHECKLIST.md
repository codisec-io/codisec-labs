# Checklist — Colocar o Codisec no ar

Ordem pensada pra você (Fernando) testar cada etapa antes de avançar pra
próxima. Marque conforme for concluindo.

---

## Fase 0 — Decisões antes de começar

- [ ] Confirmar estrutura de domínio: tudo em `codisec.com.br` (com
      `/blog` e `/labs`) ou `labs.codisec.com.br` separado? (o
      `docs/CLAUDE_CODE_PROMPT.md` deixa essa decisão em aberto pro
      Claude Code — se você já tem preferência, resolve antes de rodar
      o prompt, economiza uma pergunta de ida-e-volta)
- [ ] Confirmar que o Docker Desktop está instalado e rodando na sua
      máquina (você vai precisar dele em quase toda fase abaixo)
- [ ] Criar a organização/conta no GitHub que vai hospedar o repo (ex:
      `github.com/codisec`) — os comandos abaixo assumem esse nome, ajuste
      se for diferente
- [ ] Criar conta no Cloudflare Pages (se ainda não tiver) — o domínio
      `codisec.com.br` já está no Cloudflare, então é só conectar o
      projeto

## Fase 1 — Rodar o prompt no Claude Code

- [ ] Descompactar `codisec-labs.zip` numa pasta local
- [ ] Abrir essa pasta no Claude Code (`claude` no terminal, dentro da pasta)
- [ ] Colar o conteúdo de `docs/CLAUDE_CODE_PROMPT.md` (a partir de
      "## Contexto") como primeira mensagem
- [ ] Acompanhar a implementação — vai gerar: `cli/`, site em Astro
      (blog + catálogo de labs), `install.sh` + `install.ps1`,
      `scripts/build_catalog.py`, GitHub Actions de build/deploy,
      `legacy/server-side-model/` com o código antigo movido pra lá
- [ ] Revisar o que foi gerado antes de aceitar — em especial, confira
      que **nenhum** endpoint HTTP novo foi criado além do site estático
      (é o requisito de segurança inegociável do prompt)

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

- [ ] Compilar a CLI localmente (o Claude Code deixa isso pronto, ex:
      `go build -o codisec ./cli` ou equivalente)
- [ ] Rodar `./codisec lab list` — confirma que lê o catálogo estático
      corretamente
- [ ] Rodar `./codisec lab start <um-dos-3-labs-publicados>`
- [ ] Confirmar que o terminal abre e conecta no container
- [ ] Seguir os passos do lab você mesmo, do jeito que um usuário
      seguiria — teoria, comando, validação
- [ ] Rodar `./codisec lab validate <task-id>` em cada tarefa e conferir
      se a mensagem de sucesso/erro faz sentido
- [ ] Rodar `./codisec lab stop <id>` e confirmar que o container some
      (`docker ps` não deve mais listar ele)
- [ ] Testar o `break_again_command` / `recovery.reset_command` de pelo
      menos 1 lab, pra confirmar que o ciclo Failure→Recovery funciona

## Fase 4 — Site estático no ar

- [ ] Rodar o build do site localmente (Astro: `npm run build` dentro
      da pasta do site) e abrir o resultado (`npm run preview`) pra
      conferir visualmente antes de publicar
- [ ] Conectar o repositório no Cloudflare Pages (painel do Cloudflare
      → Pages → "Create a project" → conectar o repo GitHub)
- [ ] Configurar o build command e output directory do Astro no
      Cloudflare Pages (geralmente `npm run build` e `dist/`)
- [ ] No DNS do Cloudflare, criar o CNAME de `labs.codisec.com.br` (ou
      `codisec.com.br`, conforme decidido na Fase 0) apontando pro
      projeto Cloudflare Pages, com proxy (nuvem laranja) ligado
- [ ] Esperar propagar e abrir o domínio real no navegador — confirmar
      que carrega com HTTPS automático

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
