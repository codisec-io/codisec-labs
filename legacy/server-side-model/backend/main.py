"""
Backend da plataforma de labs AppSec/DevSecOps/DevOps.

Rodar localmente (sem Docker Compose), pra desenvolvimento:
    cd backend
    pip install -r requirements.txt
    uvicorn main:app --reload --host 0.0.0.0 --port 8000

Pré-requisito: Docker precisa estar rodando na máquina e o usuário que
executa o uvicorn precisa ter permissão de acessar /var/run/docker.sock
(no Linux: usuário no grupo `docker`, ou rode com sudo em dev).
"""
import asyncio
import logging
import threading
import time

from fastapi import FastAPI, HTTPException, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

import lab_loader
import docker_manager

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("main")

app = FastAPI(title="Girus AppSec Labs API")

# Em produção, troque "*" pelo domínio real do frontend
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.on_event("startup")
def on_startup():
    lab_loader.reload_labs()

    def cleanup_loop():
        while True:
            time.sleep(60)
            try:
                docker_manager.cleanup_expired_sessions()
            except Exception as e:
                logger.error(f"Erro no cleanup de sessões: {e}")

    threading.Thread(target=cleanup_loop, daemon=True).start()


# ---------- Catálogo de labs ----------

@app.get("/api/labs")
def list_labs(category: str | None = None, difficulty: str | None = None):
    labs = lab_loader.get_labs().values()
    if category:
        labs = [l for l in labs if l.category == category]
    if difficulty:
        labs = [l for l in labs if l.difficulty == difficulty]
    return [
        {
            "id": l.id,
            "title": l.title,
            "category": l.category,
            "difficulty": l.difficulty,
            "duration": l.duration,
            "description": l.description,
            "tags": l.tags,
        }
        for l in labs
    ]


@app.get("/api/labs/{lab_id}")
def get_lab(lab_id: str):
    lab = lab_loader.get_lab(lab_id)
    if not lab:
        raise HTTPException(404, "Lab não encontrado")
    return lab.model_dump()


@app.post("/api/admin/reload")
def reload_labs():
    """Chame depois de um merge de PR que adiciona/edita labs, para
    recarregar sem reiniciar o processo."""
    lab_loader.reload_labs()
    return {"ok": True, "labs": list(lab_loader.get_labs().keys())}


# ---------- Sessões de lab (containers) ----------

@app.post("/api/labs/{lab_id}/start")
def start_lab(lab_id: str):
    lab = lab_loader.get_lab(lab_id)
    if not lab:
        raise HTTPException(404, "Lab não encontrado")
    session = docker_manager.start_lab_container(lab.id, lab.image, lab.exposed_ports)
    return {
        "session_id": session.session_id,
        "expires_at": session.expires_at,
        "ports": session.ports,
    }


@app.post("/api/sessions/{session_id}/stop")
def stop_lab(session_id: str):
    ok = docker_manager.stop_session(session_id)
    if not ok:
        raise HTTPException(404, "Sessão não encontrada")
    return {"ok": True}


class ValidateRequest(BaseModel):
    pass


@app.post("/api/sessions/{session_id}/validate/{task_id}")
def validate_task(session_id: str, task_id: str):
    session = docker_manager.get_session(session_id)
    if not session:
        raise HTTPException(404, "Sessão não encontrada ou expirada")
    lab = lab_loader.get_lab(session.lab_id)
    task = next((t for t in lab.tasks if t.id == task_id), None)
    if not task:
        raise HTTPException(404, "Tarefa não encontrada")

    exit_code, output = docker_manager.run_validation(session_id, task.validation.command)

    passed = True
    if task.validation.expected_exit_code is not None:
        passed = passed and (exit_code == task.validation.expected_exit_code)
    if task.validation.expected_output_contains:
        passed = passed and (task.validation.expected_output_contains in output)

    return {
        "passed": passed,
        "message": task.validation.success_message if passed else task.validation.error_message,
        "raw_output": output[-2000:],  # limita tamanho pra não estourar a resposta
    }


@app.post("/api/sessions/{session_id}/reset")
def reset_lab(session_id: str):
    session = docker_manager.get_session(session_id)
    if not session:
        raise HTTPException(404, "Sessão não encontrada ou expirada")
    lab = lab_loader.get_lab(session.lab_id)
    docker_manager.run_reset(session_id, lab.recovery.reset_command)
    return {"ok": True}


# ---------- Terminal interativo via WebSocket ----------

@app.websocket("/ws/terminal/{session_id}")
async def terminal_ws(websocket: WebSocket, session_id: str):
    await websocket.accept()
    try:
        sock = docker_manager.exec_shell_socket(session_id)
    except ValueError as e:
        await websocket.send_text(f"\r\n[erro] {e}\r\n")
        await websocket.close()
        return

    raw_sock = sock._sock  # socket real por baixo do wrapper do docker-py
    loop = asyncio.get_event_loop()

    async def read_from_container():
        while True:
            try:
                data = await loop.run_in_executor(None, raw_sock.recv, 4096)
            except Exception:
                break
            if not data:
                break
            await websocket.send_bytes(data)

    reader_task = asyncio.create_task(read_from_container())
    try:
        while True:
            data = await websocket.receive_text()
            raw_sock.send(data.encode())
    except WebSocketDisconnect:
        pass
    finally:
        reader_task.cancel()
        try:
            raw_sock.close()
        except Exception:
            pass
