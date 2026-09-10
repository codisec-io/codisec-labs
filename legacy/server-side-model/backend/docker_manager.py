"""
Toda a interação com o Docker fica isolada aqui. Cada sessão de lab vira
um container isolado, nomeado lab-<lab_id>-<session_id>, com:
  - limite de CPU/memória (pra não deixar um usuário derrubar o servidor)
  - rede isolada (network_mode="bridge", sem acesso à rede do host)
  - TTL: um scheduler em main.py mata containers vencidos

ATENÇÃO DE SEGURANÇA (leia antes de colocar em produção multi-usuário):
Este backend precisa falar com o socket do Docker (/var/run/docker.sock).
Isso dá, na prática, acesso root ao host para quem comprometer o backend.
Para uma instância pessoal/estudo isso é aceitável. Para produção pública
com muitos usuários desconhecidos, troque por uma das opções abaixo antes
de expor a internet:
  1. gVisor (runsc) ou Kata Containers como runtime, isolando o kernel
  2. Um cluster Kind/K3s dedicado por usuário, como o GIRUS original faz
  3. Firecracker microVMs (abordagem usada por serviços tipo CodeSandbox)
Veja docs/SECURITY.md.
"""
import docker
import logging
import uuid
import time
from dataclasses import dataclass, field

logger = logging.getLogger("docker_manager")
client = docker.from_env()

SESSION_TTL_SECONDS = 60 * 60  # 1 hora por sessão de lab


@dataclass
class LabSession:
    session_id: str
    lab_id: str
    container_id: str
    container_name: str
    created_at: float = field(default_factory=time.time)
    ports: dict = field(default_factory=dict)  # porta_container -> porta_host

    @property
    def expires_at(self) -> float:
        return self.created_at + SESSION_TTL_SECONDS

    @property
    def is_expired(self) -> bool:
        return time.time() > self.expires_at


# Sessões ativas em memória. Para rodar mais de uma instância do backend
# (escala horizontal), troque este dict por Redis.
_sessions: dict[str, LabSession] = {}


def start_lab_container(lab_id: str, image: str, exposed_ports: list[int]) -> LabSession:
    session_id = uuid.uuid4().hex[:12]
    container_name = f"lab-{lab_id}-{session_id}"

    port_bindings = {f"{p}/tcp": None for p in exposed_ports}  # porta aleatória no host

    container = client.containers.run(
        image,
        name=container_name,
        detach=True,
        tty=True,
        stdin_open=True,
        mem_limit="256m",
        nano_cpus=500_000_000,  # 0.5 CPU
        network_mode="bridge",
        ports=port_bindings,
        labels={"codisec-labs-lab": lab_id, "codisec-labs-session": session_id},
    )
    container.reload()

    resolved_ports = {}
    for p in exposed_ports:
        key = f"{p}/tcp"
        binding = container.attrs["NetworkSettings"]["Ports"].get(key)
        if binding:
            resolved_ports[p] = int(binding[0]["HostPort"])

    session = LabSession(
        session_id=session_id,
        lab_id=lab_id,
        container_id=container.id,
        container_name=container_name,
        ports=resolved_ports,
    )
    _sessions[session_id] = session
    logger.info(f"Sessão iniciada: {container_name} (portas: {resolved_ports})")
    return session


def get_session(session_id: str) -> LabSession | None:
    return _sessions.get(session_id)


def stop_session(session_id: str) -> bool:
    session = _sessions.pop(session_id, None)
    if not session:
        return False
    try:
        container = client.containers.get(session.container_id)
        container.remove(force=True)
    except docker.errors.NotFound:
        pass
    logger.info(f"Sessão encerrada: {session.container_name}")
    return True


def cleanup_expired_sessions():
    for session_id in [sid for sid, s in _sessions.items() if s.is_expired]:
        logger.info(f"Sessão expirada, removendo: {session_id}")
        stop_session(session_id)


def run_validation(session_id: str, command: str) -> tuple[int, str]:
    """Executa o comando de validação dentro do container e retorna (exit_code, stdout+stderr)."""
    session = get_session(session_id)
    if not session:
        raise ValueError("Sessão não encontrada ou expirada")
    container = client.containers.get(session.container_id)
    exit_code, output = container.exec_run(["sh", "-c", command], demux=False)
    text = output.decode("utf-8", errors="replace") if output else ""
    return exit_code, text


def run_reset(session_id: str, reset_command: str) -> None:
    session = get_session(session_id)
    if not session:
        raise ValueError("Sessão não encontrada ou expirada")
    container = client.containers.get(session.container_id)
    container.exec_run(["sh", "-c", reset_command])


def exec_shell_socket(session_id: str):
    """
    Abre um exec interativo (bash/sh) dentro do container e retorna o socket
    bruto, usado pela ponte de WebSocket em main.py para dar terminal real
    ao usuário no navegador.
    """
    session = get_session(session_id)
    if not session:
        raise ValueError("Sessão não encontrada ou expirada")
    container = client.containers.get(session.container_id)
    exec_id = client.api.exec_create(
        container.id,
        cmd="sh",
        stdin=True,
        tty=True,
    )["Id"]
    sock = client.api.exec_start(exec_id, tty=True, socket=True)
    return sock
