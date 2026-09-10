"""
Schema de validação dos labs. Todo lab.yaml em /labs/<lab-id>/lab.yaml
deve seguir esta estrutura. Usado tanto pelo backend em runtime quanto
pelo GitHub Action que valida Pull Requests.
"""
from pydantic import BaseModel, Field, field_validator
from typing import Optional, Literal


class TaskValidation(BaseModel):
    # Comando executado DENTRO do container do lab para checar se a tarefa
    # foi concluída. Use expected_exit_code OU expected_output_contains.
    command: str
    expected_exit_code: Optional[int] = 0
    expected_output_contains: Optional[str] = None
    success_message: str
    error_message: str


class Task(BaseModel):
    id: str
    title: str
    # Explicação teórica (markdown simples). Mantém o ciclo
    # Theory -> Practice -> Failure -> Recovery usado nos labs do Fernando.
    theory: str
    steps: list[str]
    validation: TaskValidation
    # Comando opcional para "quebrar de novo" o ambiente e forçar o usuário
    # a repetir a correção (etapa de Failure/Recovery)
    break_again_command: Optional[str] = None


class Recovery(BaseModel):
    # Comando para resetar o serviço/app dentro do container caso o
    # usuário quebre algo de forma irreversível durante o lab
    reset_command: str


class Lab(BaseModel):
    id: str
    title: str
    category: Literal["appsec", "devsecops", "devops"]
    difficulty: Literal["beginner", "intermediate", "advanced"]
    duration: str  # ex: "30m", "1h"
    description: str
    # Imagem Docker que já vem com a app/ambiente vulnerável pronto
    image: str
    tags: list[str] = Field(default_factory=list)
    maintainers: list[str] = Field(default_factory=list)
    tasks: list[Task]
    recovery: Recovery
    # Portas expostas pelo container que o frontend precisa mostrar/linkar
    # (ex: 5000 para uma API Flask vulnerável)
    exposed_ports: list[int] = Field(default_factory=list)

    @field_validator("id")
    @classmethod
    def id_must_be_slug(cls, v: str) -> str:
        import re
        if not re.match(r"^[a-z0-9]+(-[a-z0-9]+)*$", v):
            raise ValueError(
                "id deve ser um slug em minúsculas com hífens, ex: appsec-idor-api"
            )
        return v
