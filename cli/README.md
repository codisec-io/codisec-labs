# codisec — CLI

CLI que roda os labs de AppSec/DevSecOps/DevOps da Codisec **localmente**,
no Docker do próprio usuário — o mesmo espírito do
[GIRUS](https://girus.linuxtips.io). Ela fala só com `labs.codisec.com.br`
(catálogo estático, leitura pública) e com o Docker local da máquina;
nunca com nenhum backend nosso. Ver `docs/ARCHITECTURE.md` na raiz do
repo para o desenho completo.

## Por que Go, não Python+PyInstaller

1. **Cross-compilação nativa.** `GOOS=windows GOARCH=amd64 go build` gera
   os 5 binários-alvo (linux/amd64, linux/arm64, darwin/amd64,
   darwin/arm64, windows/amd64) a partir de um único runner Ubuntu no
   GitHub Actions. PyInstaller não faz cross-compilação — precisaria de
   um runner por sistema operacional, workflow mais caro e mais lento.
2. **SDK oficial do Docker em Go** (`github.com/docker/docker/client`,
   o mesmo usado pelo `docker` CLI de verdade) dá acesso direto à Docker
   Engine API: pull com progresso, `ContainerCreate` com
   `PortBindings`, `ContainerExecAttach` com TTY real pra terminal
   interativo — sem precisar fazer *shell-out* pro binário `docker` (que
   o usuário talvez nem tenha no PATH, só o Docker Desktop).
3. **Binário único estático**, sem runtime a instalar — combina com o
   modelo de `install.sh`/`install.ps1` baixando um único arquivo.
4. Alinhamento com o GIRUS, citado como referência de arquitetura no
   projeto original — facilita comparação e manutenção futura.

## Comandos

```
codisec lab list                    # lista todos os labs do catálogo
codisec lab info <id>                # descrição + tasks de um lab
codisec lab start <id>               # sobe o container e abre um terminal nele
codisec lab validate <id> <task-id>  # roda a validação de uma task
codisec lab stop <id>                # derruba e remove o container
codisec lab reset <id>               # restaura o lab pro estado inicial
```

`start`, `validate`, `stop` e `reset` exigem Docker instalado e rodando
na máquina (Docker Desktop, no Windows/macOS).

## Estrutura

```
cli/
  main.go
  cmd/                 comandos cobra (list, info, start, validate, stop, reset)
  internal/catalog/     busca catalog.json e labs/<id>.json em labs.codisec.com.br
  internal/labspec/     structs que espelham labs/schema.json
  internal/dockerrun/   toda a interação com o Docker local
```

### Por que a origem do catálogo é fixa em código

`internal/catalog.Client` sempre aponta pra `https://labs.codisec.com.br` —
de propósito, não existe flag nem variável de ambiente pra trocar isso.
Se existisse, alguém poderia induzir um usuário a rodar `codisec lab
start --catalog-url=...` (ou setar uma env var) apontando pra um
catálogo malicioso, que poderia mandar a CLI baixar/rodar qualquer
imagem Docker. Ver `docs/SECURITY.md`.

Isso não impede testar: `catalog.Client` tem um campo `BaseURL`
exportado que os testes preenchem com um `httptest.Server` local — só
os comandos em `cmd/*.go` (o que o binário final expõe) usam
`catalog.NewClient()`, que sempre aponta pra produção.

## Testando localmente

```bash
go build -o codisec .
go test ./...                          # inclui testes de integração reais
                                        # contra o Docker local (pulados
                                        # automaticamente se não houver
                                        # Docker disponível)
```

Não tem como testar `list`/`info`/`start`/`validate`/`reset` contra o
catálogo de produção antes do site estar publicado em `labs.codisec.com.br`
(ver `docs/CHECKLIST.md`) — durante o desenvolvimento, sirva
`site/public/` localmente (`python3 -m http.server` dentro da pasta) e
aponte manualmente `ProductionBaseURL` pra lá, só localmente, nunca
commitado.

## Release

Ver `.goreleaser.yml` — build multi-plataforma disparado por tag
(`v*.*.*`) via `.github/workflows/release-cli.yml`.
