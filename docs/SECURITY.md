# Segurança

> **Modelo de ameaça anterior (histórico):** a primeira versão deste
> documento cobria o risco de `docker.sock` montado num backend público
> — porque a primeira versão da plataforma subia containers de lab
> *server-side*, por sessão de usuário anônimo. Esse modelo foi
> **abandonado** (código movido pra `legacy/server-side-model/`, ver o
> `README.md` de lá) porque ele dava, na prática, controle root da
> máquina host pra quem comprometesse o backend ou escapasse de um
> container mal isolado.
>
> No modelo atual, os containers de lab rodam na máquina do **próprio
> usuário**, via CLI local — não existe mais um backend nosso
> orquestrando containers de terceiros. O modelo de ameaça mudou de
> "isolamento multiusuário no nosso servidor" para os três pontos
> abaixo. Ver `docs/ARCHITECTURE.md` para o desenho completo do fluxo.

## 1. Integridade do binário da CLI

Um usuário roda `curl -sSL https://codisec.com.br/install.sh | bash` (ou
`install.ps1` no Windows) e isso baixa e executa um binário nosso
localmente. Se esse binário for adulterado em trânsito ou na origem, é
execução de código arbitrário na máquina do usuário.

Mitigações em vigor:

- Cada release (`cli/.goreleaser.yml`, disparado por
  `.github/workflows/release-cli.yml`) publica um `checksums.txt`
  (SHA-256) junto dos binários.
- `install.sh` e `install.ps1` **conferem o checksum antes de instalar
  ou executar qualquer coisa** — se não bater, abortam sem tocar no
  disco além da pasta temporária. Isso é código real nos dois scripts,
  não só uma recomendação de doc.
- Os binários são assinados com `cosign` em modo *keyless* (via OIDC do
  GitHub Actions) — não existe chave privada armazenada como secret que,
  se vazada, permitiria assinar um binário malicioso.
- Os instaladores resolvem a versão sempre pela API oficial de releases
  do GitHub (`api.github.com/repos/codisec/codisec-labs/releases/latest`)
  — nunca aceitam uma URL de download alternativa via flag ou variável
  de ambiente.

## 2. Integridade das imagens Docker dos labs

Cada `lab.yaml` referencia uma imagem (`ghcr.io/codisec/lab-*`) que a
CLI baixa e roda localmente. Uma imagem maliciosa referenciada ali
rodaria no Docker do usuário.

Mitigações:

- Só o CI da própria organização publica em `ghcr.io/codisec/lab-*` —
  nunca uma imagem de terceiro é referenciada sem revisão de um
  mantenedor (ver processo em `CONTRIBUTING.md`, que já não aceita PR
  externo tocando `labs/` justamente por isso).
- `catalog.json`/`labs/<id>.json` (o que a CLI de fato lê) são **gerados
  automaticamente** por `site/scripts/build-catalog.mjs` a partir dos
  `lab.yaml` — nunca editados à mão, nunca aceitam input de fora do
  repositório.
- A CLI (`internal/catalog.Client`) tem a origem do catálogo **fixa em
  código** (`https://codisec.com.br`) — não existe flag nem variável de
  ambiente documentada pra trocar isso. Isso é deliberado: uma flag
  `--catalog-url` seria uma forma fácil de induzir alguém a rodar
  `codisec lab start` apontando pra um catálogo malicioso. (O campo
  `BaseURL` do cliente existe só pra teste automatizado com
  `httptest.Server`, nunca exposto pelos comandos reais da CLI.)

## 3. `validation.command` / `reset_command` rodam shell dentro do container

Cada task de um lab tem um `validation.command` e um
`recovery.reset_command` que a CLI executa via `docker exec` dentro do
container do lab (nunca no host do usuário). Isso é seguro *desde que*
só mantenedores confiáveis escrevam `lab.yaml` — nunca vira comando a
partir de input de usuário final. `CONTRIBUTING.md` já documenta que
edição de `labs/` é fechada pra PR externo por esse motivo exato, e
`.github/workflows/validate-labs.yml` valida todo `lab.yaml` contra
`labs/schema.json` antes de qualquer merge.

## 4. Labs que exigem modo privilegiado

A maioria dos labs roda com as permissões padrão de um container Docker
comum — sem acesso especial ao host. Mas alguns temas (fundamentos de
Docker, por exemplo) só fazem sentido se o próprio lab tiver um Docker
de verdade pra você praticar dentro dele. Isso exige rodar o container
do lab em modo **privilegiado** (`--privileged`), o que dá a esse
container acesso equivalente a root na máquina do usuário.

**Por que `--privileged` com Docker-in-Docker isolado, não montar
`/var/run/docker.sock` do host:** eram as duas opções óbvias. Montar o
socket do host é mais simples de implementar, mas faz o container do
lab controlar o Docker **do próprio host do usuário** — qualquer
`docker run`/`docker build` dentro do lab cria containers e imagens que
aparecem no `docker ps`/`docker images` do host, e sobrevivem ao
`codisec lab stop` (que só remove o container do lab, não sabe nada
sobre containers "filhos" criados via socket compartilhado). Isso quebra
a garantia de "cada sessão de lab começa e termina limpa" que o resto do
projeto assume. Testado na prática: com `--privileged` e
Docker-in-Docker de verdade (imagem `docker:24-dind`), uma imagem
construída dentro do lab (`meu-app:1.0`) **nunca aparece** no
`docker images` do host, e some sozinha quando `codisec lab stop`
remove o container — o daemon aninhado e todo o estado dele vivem só
ali dentro. O custo é armazenamento/cgroups aninhados, mas pro que esse
lab ensina (build, run, volumes) isso não é perceptível.

**Como funciona na prática:**

- `labs/schema.json` tem o campo opcional `requires_privileged`
  (default `false`). Só `labs/devops-docker-fundamentos/lab.yaml`
  declara `requires_privileged: true` hoje — nenhum outro lab precisa
  disso, e não deve ganhar esse campo "de graça" só porque é possível;
  cada caso novo merece a mesma análise acima antes de marcar `true`.
- `site/scripts/build-catalog.mjs` propaga esse campo pro `catalog.json`
  e pro `labs/<id>.json` — é assim que tanto a CLI quanto o site sabem
  disso sem reimplementar a leitura do `lab.yaml`.
- A CLI (`cmd/start.go`) **nunca** sobe um container privilegiado em
  silêncio: se `requires_privileged` for `true`, ela mostra um aviso
  explícito e pede confirmação (`Continuar? [y/N]`) antes de criar o
  container. `--yes`/`-y` pula a confirmação pra uso não-interativo
  (scripts, CI), mas o padrão sem essa flag é sempre perguntar.
- O site (`/labs/<id>`) mostra o mesmo aviso visualmente *antes* do
  usuário sequer instalar a CLI ou rodar o comando — a decisão de
  confiar ou não num lab assim começa na hora de escolher rodá-lo, não
  só na hora de confirmar no terminal.

## 5. Superfície pública

Recapitulando o que já está em `docs/ARCHITECTURE.md`: o único artefato
nosso acessível pela internet é o site estático, o catálogo, os
instaladores e as imagens públicas no GHCR (leitura). Nenhum endpoint
HTTP novo foi criado além disso — é o requisito inegociável do projeto,
e vale conferir manualmente antes de cada release relevante (ver
`docs/CHECKLIST.md`, Fase 7).

Se no futuro for necessária telemetria (quantas pessoas iniciaram um
lab, por exemplo), ela precisa ser um serviço isolado e mínimo — nunca
algo que aceite comandos ou tenha acesso a infraestrutura de execução,
e nunca no mesmo host do site (subdomínio separado, ex:
`events.codisec.com.br`).
