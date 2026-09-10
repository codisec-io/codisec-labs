#!/usr/bin/env python3
"""
Valida todos os labs/<lab-id>/lab.yaml contra labs/schema.json.

Uso local (antes de abrir o PR):
    pip install pyyaml jsonschema
    python3 scripts/validate_lab_schema.py

Retorna exit code 0 se tudo estiver válido, 1 caso contrário — é
exatamente isso que a GitHub Action em .github/workflows/validate-labs.yml
usa para aprovar ou barrar um Pull Request automaticamente.
"""
import json
import sys
from pathlib import Path

import yaml
from jsonschema import Draft7Validator

ROOT = Path(__file__).resolve().parent.parent
LABS_DIR = ROOT / "labs"
SCHEMA_PATH = LABS_DIR / "schema.json"


def main() -> int:
    schema = json.loads(SCHEMA_PATH.read_text(encoding="utf-8"))
    validator = Draft7Validator(schema)

    had_errors = False
    lab_dirs = [d for d in LABS_DIR.iterdir() if d.is_dir()]

    if not lab_dirs:
        print("Nenhuma pasta de lab encontrada em /labs.")
        return 1

    for lab_dir in sorted(lab_dirs):
        lab_file = lab_dir / "lab.yaml"
        if not lab_file.exists():
            print(f"⚠️  {lab_dir.name}: pasta sem lab.yaml, pulando.")
            continue

        try:
            data = yaml.safe_load(lab_file.read_text(encoding="utf-8"))
        except yaml.YAMLError as e:
            print(f"❌ {lab_dir.name}: YAML inválido — {e}")
            had_errors = True
            continue

        errors = sorted(validator.iter_errors(data), key=lambda e: e.path)
        if errors:
            had_errors = True
            print(f"❌ {lab_dir.name}: {len(errors)} erro(s) de schema:")
            for err in errors:
                path = ".".join(str(p) for p in err.path) or "(raiz)"
                print(f"   - [{path}] {err.message}")
            continue

        if data["id"] != lab_dir.name:
            had_errors = True
            print(
                f"❌ {lab_dir.name}: campo 'id' ({data['id']}) precisa ser "
                f"igual ao nome da pasta ({lab_dir.name})."
            )
            continue

        print(f"✅ {lab_dir.name}: válido.")

    if had_errors:
        print("\nValidação falhou — corrija os erros acima antes de abrir/mergear o PR.")
        return 1

    print("\nTodos os labs são válidos.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
