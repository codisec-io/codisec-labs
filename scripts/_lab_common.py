"""Carrega e valida labs/<id>/lab.yaml contra labs/schema.json.

Lógica compartilhada entre scripts/validate_lab_schema.py (relatório
legível, gate de CI) e scripts/build_catalog.py (gera catalog.json só
quando todos os labs são válidos). Não roda nada sozinho.
"""
import json
from dataclasses import dataclass, field
from pathlib import Path

import yaml
from jsonschema import Draft7Validator

ROOT = Path(__file__).resolve().parent.parent
LABS_DIR = ROOT / "labs"
SCHEMA_PATH = LABS_DIR / "schema.json"


@dataclass
class LabResult:
    dir_name: str
    data: dict | None = None
    skipped: bool = False
    yaml_error: str | None = None
    schema_errors: list[str] = field(default_factory=list)
    id_mismatch: str | None = None

    @property
    def valid(self) -> bool:
        return (
            not self.skipped
            and self.data is not None
            and self.yaml_error is None
            and not self.schema_errors
            and self.id_mismatch is None
        )


def iter_lab_results():
    """Gera um LabResult por pasta em /labs, na ordem alfabética."""
    schema = json.loads(SCHEMA_PATH.read_text(encoding="utf-8"))
    validator = Draft7Validator(schema)

    lab_dirs = sorted(d for d in LABS_DIR.iterdir() if d.is_dir())
    for lab_dir in lab_dirs:
        lab_file = lab_dir / "lab.yaml"
        if not lab_file.exists():
            yield LabResult(dir_name=lab_dir.name, skipped=True)
            continue

        try:
            data = yaml.safe_load(lab_file.read_text(encoding="utf-8"))
        except yaml.YAMLError as e:
            yield LabResult(dir_name=lab_dir.name, yaml_error=str(e))
            continue

        schema_errors = sorted(validator.iter_errors(data), key=lambda e: e.path)
        if schema_errors:
            messages = []
            for err in schema_errors:
                path = ".".join(str(p) for p in err.path) or "(raiz)"
                messages.append(f"[{path}] {err.message}")
            yield LabResult(dir_name=lab_dir.name, data=data, schema_errors=messages)
            continue

        if data["id"] != lab_dir.name:
            yield LabResult(
                dir_name=lab_dir.name,
                data=data,
                id_mismatch=(
                    f"campo 'id' ({data['id']}) precisa ser igual ao nome da "
                    f"pasta ({lab_dir.name})."
                ),
            )
            continue

        yield LabResult(dir_name=lab_dir.name, data=data)


def load_valid_labs() -> list[dict]:
    """Retorna só os labs válidos, cada dict com a chave extra '_dir'."""
    valid = []
    for r in iter_lab_results():
        if r.valid:
            lab = dict(r.data)
            lab["_dir"] = r.dir_name
            valid.append(lab)
    return valid
