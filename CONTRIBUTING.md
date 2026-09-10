# Como contribuir

Este projeto **não aceita Pull Requests externos**. A adição e edição de
labs é feita apenas pela equipe mantenedora, seguindo o processo abaixo —
isso mantém controle de qualidade e segurança sobre o que roda dentro dos
containers (cada lab executa código real; um PR malicioso poderia embutir
uma imagem Docker comprometida).

Se você quer sugerir um lab novo, uma melhoria ou reportar um problema,
**abra uma Issue** usando os templates em `.github/ISSUE_TEMPLATE/`:

- **Sugestão de lab / feature** → template "Feature Request"
- **Algo não funcionou** → template "Bug"

Não precisa saber programar pra abrir uma Issue — descrever a ideia ou o
problema já ajuda bastante. A equipe avalia, prioriza e, se aprovar,
implementa e publica.

---

## Processo interno (mantenedores)

### Adicionar um lab novo

1. Crie uma pasta em `labs/<categoria>-<nome-curto>`, exemplo:
   `labs/appsec-sql-injection-login`.
2. Dentro dela, crie um arquivo `lab.yaml` seguindo o formato descrito em
   `labs/schema.json`. O jeito mais rápido é copiar um lab existente
   parecido (ex: `labs/appsec-idor-api/lab.yaml`) e adaptar.
3. Campos obrigatórios: `id` (igual ao nome da pasta), `title`,
   `category` (`appsec`, `devsecops` ou `devops`), `difficulty`
   (`beginner`, `intermediate` ou `advanced`), `duration`, `description`,
   `image` (imagem Docker publicada em algum registry — GHCR é grátis,
   veja abaixo), `tasks` (mínimo 1) e `recovery.reset_command`.
4. Cada `task` precisa ter uma `validation.command` que rode DENTRO do
   container do lab e confirme, de forma objetiva, que a tarefa foi
   concluída — não confie em "o usuário disse que terminou".
5. Valide localmente antes de commitar:
   ```bash
   pip install -r scripts/requirements.txt
   python3 scripts/validate_lab_schema.py
   ```
6. Abra um PR **na branch interna** (ou commit direto em `main` se for só
   você mexendo por enquanto). A Action `validate-labs.yml` roda de
   qualquer forma, como uma segunda camada de checagem antes do deploy.
7. Depois do merge/push, chame `POST /api/admin/reload` no backend em
   produção (ou deixe o deploy automático fazer isso — veja
   `docs/DEPLOY.md`) para o novo lab aparecer no catálogo sem reiniciar.

### Publicar a imagem Docker do lab

```bash
docker build -t ghcr.io/codisec/lab-nome-do-lab:latest .
echo $GITHUB_TOKEN | docker login ghcr.io -u codisec --password-stdin
docker push ghcr.io/codisec/lab-nome-do-lab:latest
```

Depois, referencie essa imagem no campo `image` do `lab.yaml`.

### Editar um lab existente

Mesma lógica: edite o `lab.yaml` (ou o Dockerfile da imagem, se
aplicável), rode a validação local, faça commit/push e recarregue o
catálogo em produção.

---

## Código de conduta

Seja respeitoso ao abrir uma Issue. O objetivo do projeto é baixar a
barreira de entrada pra quem quer aprender AppSec/DevSecOps/DevOps com
recursos limitados — perguntas "básicas" são bem-vindas.
