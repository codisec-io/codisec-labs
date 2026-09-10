"""
Varre a pasta /labs (montada dentro do container do backend) procurando
por lab.yaml, valida cada um contra o schema Pydantic e mantém um índice
em memória. Rodar `reload_labs()` de novo é o suficiente para pegar labs
novos adicionados via Pull Request merged, sem precisar reiniciar o
processo inteiro (chame o endpoint POST /api/admin/reload).
"""
import os
import yaml
import logging
from pathlib import Path
from pydantic import ValidationError
from schema import Lab

logger = logging.getLogger("lab_loader")

LABS_DIR = Path(os.environ.get("LABS_DIR", "/labs"))

_labs_cache: dict[str, Lab] = {}


def reload_labs() -> dict[str, Lab]:
    global _labs_cache
    labs: dict[str, Lab] = {}
    if not LABS_DIR.exists():
        logger.warning(f"Pasta de labs não encontrada: {LABS_DIR}")
        _labs_cache = {}
        return _labs_cache

    for lab_dir in sorted(LABS_DIR.iterdir()):
        lab_file = lab_dir / "lab.yaml"
        if not lab_file.exists():
            continue
        try:
            raw = yaml.safe_load(lab_file.read_text(encoding="utf-8"))
            lab = Lab(**raw)
            if lab.id != lab_dir.name:
                logger.error(
                    f"[{lab_dir}] o campo 'id' ({lab.id}) precisa ser igual "
                    f"ao nome da pasta ({lab_dir.name}) — pulando."
                )
                continue
            labs[lab.id] = lab
        except ValidationError as e:
            logger.error(f"[{lab_dir}] lab.yaml inválido, pulando:\n{e}")
        except Exception as e:
            logger.error(f"[{lab_dir}] erro ao carregar lab.yaml: {e}")

    _labs_cache = labs
    logger.info(f"{len(labs)} labs carregados: {list(labs.keys())}")
    return _labs_cache


def get_labs() -> dict[str, Lab]:
    if not _labs_cache:
        reload_labs()
    return _labs_cache


def get_lab(lab_id: str) -> Lab | None:
    return get_labs().get(lab_id)
