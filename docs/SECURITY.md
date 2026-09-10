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
  automaticamente** por `scripts/build_catalog.py` a partir dos
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

## 4. Superfície pública

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
