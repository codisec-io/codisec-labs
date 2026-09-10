#!/usr/bin/env python3
"""
Gera o catálogo estático de labs a partir de labs/*/lab.yaml.

Uso:
    pip install pyyaml jsonschema
    python3 scripts/build_catalog.py

Escreve:
    site/public/catalog.json       — índice leve de todos os labs válidos
    site/public/labs/<id>.json     — lab completo (equivalente ao lab.yaml,
                                      em JSON) para consumo pela CLI

Só escreve alguma coisa se TODOS os labs em /labs forem válidos — um
catálogo parcial/quebrado é pior do que nenhum catálogo. Se algum lab
falhar a validação, roda `python3 scripts/validate_lab_schema.py` para
ver o erro detalhado.

Exit code 0 em sucesso, 1 se algum lab for inválido.
"""
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from _lab_common import LABS_DIR, iter_lab_results  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
SITE_PUBLIC_DIR = ROOT / "site" / "public"
CATALOG_PATH = SITE_PUBLIC_DIR / "catalog.json"
LABS_JSON_DIR = SITE_PUBLIC_DIR / "labs"

SCHEMA_VERSION = 1

# Imagens ainda não construídas/publicadas pela equipe (ver
# docs/MAPA_DO_REPO.md e docs/CHECKLIST.md Fase 2). Heurística por padrão
# de nome: "SEU_USUARIO" é sempre placeholder; "ghcr.io/codisec/lab-*" é
# onde as imagens reais vão morar quando publicadas, mas nenhuma foi
# publicada ainda — quando isso mudar, revisar esta heurística (ex: manter
# uma lista explícita de ids já publicados em vez de inferir pela URL).
_PLACEHOLDER_MARKERS = ("SEU_USUARIO", "ghcr.io/codisec/lab-")


def is_image_published(image: str) -> bool:
    return not any(marker in image for marker in _PLACEHOLDER_MARKERS)


def catalog_entry(lab: dict) -> dict:
    return {
        "id": lab["id"],
        "title": lab["title"],
        "category": lab["category"],
        "difficulty": lab["difficulty"],
        "duration": lab["duration"],
        "description": lab["description"],
        "tags": lab.get("tags", []),
        "image": lab["image"],
        "image_published": is_image_published(lab["image"]),
        "task_count": len(lab["tasks"]),
        "maintainers": lab.get("maintainers", []),
    }


def main() -> int:
    results = list(iter_lab_results())
    invalid = [r for r in results if not r.valid and not r.skipped]
    skipped = [r for r in results if r.skipped]

    if invalid or skipped or not results:
        print("❌ Catálogo não gerado — nem todos os labs são válidos.")
        print("   Rode `python3 scripts/validate_lab_schema.py` para ver o detalhe.")
        return 1

    labs = [dict(r.data, _dir=r.dir_name) for r in results]
    labs.sort(key=lambda lab: lab["id"])

    SITE_PUBLIC_DIR.mkdir(parents=True, exist_ok=True)
    LABS_JSON_DIR.mkdir(parents=True, exist_ok=True)

    catalog = {
        "schema_version": SCHEMA_VERSION,
        "generated_at": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "total": len(labs),
        "labs": [catalog_entry(lab) for lab in labs],
    }
    CATALOG_PATH.write_text(
        json.dumps(catalog, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )

    for lab in labs:
        lab_out = {k: v for k, v in lab.items() if k != "_dir"}
        lab_out["image_published"] = is_image_published(lab["image"])
        (LABS_JSON_DIR / f"{lab['id']}.json").write_text(
            json.dumps(lab_out, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
        )

    print(f"✅ Catálogo gerado: {len(labs)} labs.")
    print(f"   {CATALOG_PATH.relative_to(ROOT)}")
    print(f"   {LABS_JSON_DIR.relative_to(ROOT)}/<id>.json ({len(labs)} arquivos)")
    unpublished = [lab["id"] for lab in labs if not is_image_published(lab["image"])]
    if unpublished:
        print(
            f"   ⚠️  {len(unpublished)} lab(s) com imagem Docker ainda não "
            f"publicada: {', '.join(unpublished)}"
        )
    return 0


if __name__ == "__main__":
    sys.exit(main())
