#!/usr/bin/env node
// Gera o catálogo estático de labs a partir de labs/*/lab.yaml.
//
// Substitui a versão antiga em Python (scripts/build_catalog.py):
// aquela dependia de `pip install pyyaml jsonschema` rodar no
// ambiente de build, o que funcionava localmente (instalado à mão)
// mas quebrou o deploy na Cloudflare Pages, que não tem Python
// configurado por padrão no pipeline do site. Esta versão é 100% Node
// — instalada junto com o resto via `npm ci`, sem dependência cruzada
// de runtime no build.
//
// labs/schema.json continua sendo a fonte de verdade única. Ela é
// validada aqui via ajv (JSON Schema Draft-07) e, separadamente, por
// scripts/validate_lab_schema.py em Python (usado só por
// .github/workflows/validate-labs.yml, fora do pipeline de deploy do
// site) — duas implementações independentes e maduras da MESMA spec
// declarativa, não duas cópias de lógica de validação escrita à mão.
//
// Uso: node scripts/build-catalog.mjs (chamado por `npm run catalog`,
// que por sua vez roda automaticamente antes de `npm run dev`/`build`)
//
// Escreve public/catalog.json e public/labs/<id>.json. Só escreve
// alguma coisa se TODOS os labs forem válidos — um catálogo
// parcial/quebrado é pior que nenhum catálogo.

import { mkdirSync, readdirSync, readFileSync, statSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import Ajv from 'ajv';
import { load as loadYaml } from 'js-yaml';

const __dirname = dirname(fileURLToPath(import.meta.url));
const SITE_DIR = join(__dirname, '..');
const ROOT = join(SITE_DIR, '..');
const LABS_DIR = join(ROOT, 'labs');
const SCHEMA_PATH = join(LABS_DIR, 'schema.json');
const PUBLIC_DIR = join(SITE_DIR, 'public');
const LABS_JSON_DIR = join(PUBLIC_DIR, 'labs');
const CATALOG_PATH = join(PUBLIC_DIR, 'catalog.json');

const SCHEMA_VERSION = 1;

// Imagens ainda não construídas/publicadas pela equipe (ver
// docs/MAPA_DO_REPO.md e docs/CHECKLIST.md Fase 2). Heurística por
// padrão de nome — se mudar aqui, mudar também no comentário
// equivalente em site/src/pages/labs/[id].astro.
const PLACEHOLDER_MARKERS = ['SEU_USUARIO', 'ghcr.io/codisec/lab-'];

function isImagePublished(image) {
  return !PLACEHOLDER_MARKERS.some((marker) => image.includes(marker));
}

function loadLabResults() {
  const schema = JSON.parse(readFileSync(SCHEMA_PATH, 'utf-8'));
  const ajv = new Ajv({ allErrors: true, strict: false });
  const validate = ajv.compile(schema);

  const dirNames = readdirSync(LABS_DIR)
    .filter((name) => statSync(join(LABS_DIR, name)).isDirectory())
    .sort();

  return dirNames.map((dirName) => {
    const labFile = join(LABS_DIR, dirName, 'lab.yaml');

    let raw;
    try {
      raw = readFileSync(labFile, 'utf-8');
    } catch (err) {
      if (err.code === 'ENOENT') return { dirName, skipped: true };
      throw err;
    }

    let data;
    try {
      data = loadYaml(raw);
    } catch (err) {
      return { dirName, yamlError: String(err.message ?? err) };
    }

    if (!validate(data)) {
      const messages = validate.errors.map(
        (e) => `[${e.instancePath || '(raiz)'}] ${e.message}`
      );
      return { dirName, data, schemaErrors: messages };
    }

    if (data.id !== dirName) {
      return {
        dirName,
        data,
        idMismatch: `campo 'id' (${data.id}) precisa ser igual ao nome da pasta (${dirName}).`,
      };
    }

    return { dirName, data };
  });
}

function isValidResult(r) {
  return !r.skipped && r.data != null && !r.yamlError && !r.schemaErrors && !r.idMismatch;
}

function catalogEntry(lab) {
  return {
    id: lab.id,
    title: lab.title,
    category: lab.category,
    difficulty: lab.difficulty,
    duration: lab.duration,
    description: lab.description,
    tags: lab.tags ?? [],
    image: lab.image,
    image_published: isImagePublished(lab.image),
    requires_privileged: lab.requires_privileged ?? false,
    required_capabilities: lab.required_capabilities ?? [],
    task_count: lab.tasks.length,
    maintainers: lab.maintainers ?? [],
  };
}

function main() {
  const results = loadLabResults();
  const invalid = results.filter((r) => !r.skipped && !isValidResult(r));
  const skipped = results.filter((r) => r.skipped);

  if (invalid.length > 0 || skipped.length > 0 || results.length === 0) {
    console.error('❌ Catálogo não gerado — nem todos os labs são válidos.');
    console.error('   Rode `python3 scripts/validate_lab_schema.py` para ver o detalhe.');
    process.exit(1);
  }

  const labs = results.map((r) => r.data).sort((a, b) => a.id.localeCompare(b.id));

  mkdirSync(PUBLIC_DIR, { recursive: true });
  mkdirSync(LABS_JSON_DIR, { recursive: true });

  const catalog = {
    schema_version: SCHEMA_VERSION,
    generated_at: new Date().toISOString(),
    total: labs.length,
    labs: labs.map(catalogEntry),
  };
  writeFileSync(CATALOG_PATH, JSON.stringify(catalog, null, 2) + '\n', 'utf-8');

  for (const lab of labs) {
    const labOut = {
      ...lab,
      image_published: isImagePublished(lab.image),
      requires_privileged: lab.requires_privileged ?? false,
      required_capabilities: lab.required_capabilities ?? [],
    };
    writeFileSync(
      join(LABS_JSON_DIR, `${lab.id}.json`),
      JSON.stringify(labOut, null, 2) + '\n',
      'utf-8'
    );
  }

  console.log(`✅ Catálogo gerado: ${labs.length} labs.`);
  console.log('   public/catalog.json');
  console.log(`   public/labs/<id>.json (${labs.length} arquivos)`);

  const unpublished = labs.filter((l) => !isImagePublished(l.image)).map((l) => l.id);
  if (unpublished.length > 0) {
    console.log(
      `   ⚠️  ${unpublished.length} lab(s) com imagem Docker ainda não publicada: ${unpublished.join(', ')}`
    );
  }
}

main();
