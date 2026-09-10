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
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from _lab_common import iter_lab_results  # noqa: E402


def main() -> int:
    results = list(iter_lab_results())

    if not results:
        print("Nenhuma pasta de lab encontrada em /labs.")
        return 1

    had_errors = False
    for r in results:
        if r.skipped:
            print(f"⚠️  {r.dir_name}: pasta sem lab.yaml, pulando.")
            continue

        if r.yaml_error is not None:
            had_errors = True
            print(f"❌ {r.dir_name}: YAML inválido — {r.yaml_error}")
            continue

        if r.schema_errors:
            had_errors = True
            print(f"❌ {r.dir_name}: {len(r.schema_errors)} erro(s) de schema:")
            for msg in r.schema_errors:
                print(f"   - {msg}")
            continue

        if r.id_mismatch is not None:
            had_errors = True
            print(f"❌ {r.dir_name}: {r.id_mismatch}")
            continue

        print(f"✅ {r.dir_name}: válido.")

    if had_errors:
        print("\nValidação falhou — corrija os erros acima antes de abrir/mergear o PR.")
        return 1

    print("\nTodos os labs são válidos.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
