# Segurança do ambiente de execução dos labs

Leia isso antes de expor a plataforma publicamente na internet.

## O risco: docker.sock montado no backend

Este projeto, no seu MVP, monta `/var/run/docker.sock` dentro do
container do backend para que ele consiga criar/destruir containers de
lab sob demanda. Isso é simples e funciona bem para:

- Uso pessoal
- Ambiente fechado (só você e conhecidos usam)
- Prova de conceito / demo

**Não é seguro** para uma plataforma pública com usuários anônimos, porque
quem conseguir executar comandos arbitrários dentro do backend (por
exemplo, explorando um bug no próprio backend, ou escapando de um
container de lab mal isolado) ganha, na prática, controle root sobre a
máquina host inteira — o Docker socket não distingue "container de lab
do usuário" de "container do sistema".

## Opções pra produção com usuários desconhecidos

Em ordem de esforço de implementação (do mais simples ao mais robusto):

1. **gVisor (runsc) como runtime de container**
   Troca o runtime padrão do Docker por um que roda um kernel de usuário
   entre o container e o kernel real do host, reduzindo bastante a
   superfície de ataque de fuga de container. Configuração relativamente
   simples: instala o runtime e adiciona `--runtime=runsc` na hora de
   subir os containers de lab (dá pra fazer isso em `docker_manager.py`
   sem tocar em mais nada).

2. **Kata Containers**
   Cada container roda dentro de uma microVM leve (baseada em QEMU/Firecracker),
   isolamento próximo de VM de verdade com overhead pequeno. Mais robusto
   que gVisor, um pouco mais trabalhoso de configurar.

3. **Um cluster Kind/K3s dedicado, como o GIRUS original faz**
   Em vez de o backend falar direto com o Docker do host, cada sessão de
   lab vira um Pod num cluster Kubernetes com NetworkPolicy restritiva,
   ResourceQuota e um runtimeClass usando gVisor/Kata por baixo. Dá
   isolamento de rede mais forte (o pod não enxerga a rede do host nem de
   outros pods) e é o caminho mais "padrão de mercado" pra esse tipo de
   plataforma.

4. **Firecracker microVMs dedicadas por sessão**
   Abordagem usada por serviços como CodeSandbox/StackBlitz/Fly.io.
   Isolamento mais forte que containers, boot rápido (~125ms), mas exige
   mais infraestrutura própria pra orquestrar (não é "docker run" direto).

## Recomendação prática

Comece com o MVP (docker.sock) rodando **atrás de autenticação** — nem
que seja um login simples por GitHub OAuth — e num servidor isolado
(não a mesma máquina onde você guarda outras coisas sensíveis). Migre
pra Kind+gVisor (opção 3) no momento em que o projeto começar a receber
tráfego de usuários que você não conhece pessoalmente.

## Outras medidas que já estão no MVP

- Limite de CPU (0.5 core) e memória (256MB) por container de lab
- TTL de 1 hora por sessão, com limpeza automática
- `network_mode="bridge"` isolado (sem acesso direto à rede do host)
- CORS restritivo (lembre de trocar `allow_origins=["*"]` pelo domínio
  real do frontend antes de ir pra produção)
