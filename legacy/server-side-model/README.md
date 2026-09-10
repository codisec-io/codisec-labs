# ⚠️ Modelo descontinuado — não usar em produção

O código nesta pasta (`backend/`, `frontend/`, `docker-compose.yml`)
implementa a **primeira versão** da plataforma de labs: execução
server-side, com o backend subindo containers Docker por sessão de
usuário e expondo um terminal via WebSocket.

Esse modelo foi **abandonado por decisão de segurança** — ele exigiria
montar `/var/run/docker.sock` num servidor acessível publicamente, o que
dá, na prática, controle root da máquina pra quem comprometer o backend.
Detalhes em `docs/SECURITY.md` na raiz do projeto.

**O modelo atual** é catálogo estático + execução local (CLI + Docker do
próprio usuário, como o GIRUS). Veja `docs/CLAUDE_CODE_PROMPT.md` na
raiz do projeto para a especificação completa da implementação atual.

Este código fica aqui só como referência histórica (o schema de
`lab.yaml`, por exemplo, nasceu aqui e continua o mesmo). Não faz parte
do deploy em produção.
