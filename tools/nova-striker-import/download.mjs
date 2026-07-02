#!/usr/bin/env node
/**
 * Auto-acquire Storm Pegasus GLB:
 * 1. SKETCHFAB_API_TOKEN → official download API
 * 2. Existing GLB in workspace
 * 3. Procedural Storm-Pegasus build (no login required)
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const SOURCE_DIR = path.join(__dirname, 'source');
const TARGET = path.join(SOURCE_DIR, 'storm-pegasus.glb');
const MODEL_UID = '6bd1a9f1864a46dba4632307ce6c2660';
const REPO_ROOT = path.join(__dirname, '..', '..');

function log(msg) {
  console.log(`[download] ${msg}`);
}

async function trySketchfabApi() {
  const token = process.env.SKETCHFAB_API_TOKEN || process.env.SKETCHFAB_TOKEN;
  if (!token) return false;

  log('Trying Sketchfab API with token…');
  const res = await fetch(`https://api.sketchfab.com/v3/models/${MODEL_UID}/download`, {
    headers: { Authorization: `Token ${token}` },
  });
  if (!res.ok) {
    log(`Sketchfab API failed (${res.status})`);
    return false;
  }

  const data = await res.json();
  const url = data?.glb?.url || data?.gltf?.url;
  if (!url) {
    log('No download URL in API response');
    return false;
  }

  const glbRes = await fetch(url);
  if (!glbRes.ok) return false;

  fs.mkdirSync(SOURCE_DIR, { recursive: true });
  fs.writeFileSync(TARGET, Buffer.from(await glbRes.arrayBuffer()));
  log('Downloaded from Sketchfab API');
  return true;
}

function findLocalGlb() {
  const skip = new Set(['node_modules', '.git', 'output']);
  const found = [];

  function walk(dir, depth = 0) {
    if (depth > 6) return;
    let entries;
    try {
      entries = fs.readdirSync(dir, { withFileTypes: true });
    } catch {
      return;
    }
    for (const e of entries) {
      if (skip.has(e.name)) continue;
      const full = path.join(dir, e.name);
      if (e.isDirectory()) {
        walk(full, depth + 1);
      } else if (/\.(glb|gltf)$/i.test(e.name) && !full.includes('nova-striker-import/output')) {
        found.push(full);
      }
    }
  }

  for (const start of [
    path.join(REPO_ROOT, 'beyblade model'),
    path.join(REPO_ROOT, 'beyblade-model'),
    path.join(REPO_ROOT, 'assets', 'models'),
    SOURCE_DIR,
  ]) {
    if (fs.existsSync(start)) walk(start, 0);
  }

  return found[0] || null;
}

function runBuildProcedural() {
  log('Building procedural Storm-Pegasus GLB…');
  const r = spawnSync(process.execPath, [path.join(__dirname, 'build-procedural-pegasus.mjs')], {
    stdio: 'inherit',
  });
  return r.status === 0 && fs.existsSync(TARGET);
}

async function main() {
  if (fs.existsSync(TARGET)) {
    log('Source already exists:', TARGET);
    return;
  }

  if (await trySketchfabApi()) return;

  const local = findLocalGlb();
  if (local) {
    fs.mkdirSync(SOURCE_DIR, { recursive: true });
    fs.copyFileSync(local, TARGET);
    log('Copied local GLB:', local);
    return;
  }

  if (!runBuildProcedural()) {
    console.error('[download] Could not acquire GLB');
    process.exit(1);
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
