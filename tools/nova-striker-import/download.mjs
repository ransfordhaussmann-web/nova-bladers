#!/usr/bin/env node
/**
 * Auto-acquire Storm Pegasus GLB:
 * 1. SKETCHFAB_API_TOKEN → official download API (exclusive model)
 * 2. Existing GLB in workspace (beyblade model/)
 * 3. Procedural Storm-Pegasus build (no login required)
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const SOURCE_DIR = path.join(__dirname, 'source');
const TARGET = path.join(SOURCE_DIR, 'storm-pegasus.glb');
const MODEL_ID_FILE = path.join(SOURCE_DIR, '.model-id');
const REPO_ROOT = path.join(__dirname, '..', '..');

// Exclusive downloadable version (logged-in Sketchfab download enabled)
const DEFAULT_MODEL_UID = '2093ae37cc624534902d7b92fee88f4e';
const DEFAULT_MODEL_URL =
  'https://sketchfab.com/3d-models/storm-pegasus-105-rf-versao-exclusiva-2093ae37cc624534902d7b92fee88f4e';

const force = process.argv.includes('--force');

function log(msg) {
  console.log(`[download] ${msg}`);
}

function loadEnvFile() {
  const envPath = path.join(__dirname, '.env');
  if (!fs.existsSync(envPath)) return;
  for (const line of fs.readFileSync(envPath, 'utf8').split('\n')) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) continue;
    const eq = trimmed.indexOf('=');
    if (eq <= 0) continue;
    const key = trimmed.slice(0, eq).trim();
    const val = trimmed.slice(eq + 1).trim().replace(/^["']|["']$/g, '');
    if (!process.env[key]) process.env[key] = val;
  }
}

function resolveModelUid() {
  const fromEnv = process.env.SKETCHFAB_MODEL_ID || process.env.SKETCHFAB_MODEL_UID;
  if (fromEnv) return fromEnv;

  const url = process.env.SKETCHFAB_MODEL_URL || '';
  const match = url.match(/([a-f0-9]{32})/i);
  if (match) return match[1];

  return DEFAULT_MODEL_UID;
}

function modelChanged(uid) {
  if (!fs.existsSync(MODEL_ID_FILE)) return true;
  return fs.readFileSync(MODEL_ID_FILE, 'utf8').trim() !== uid;
}

function writeModelId(uid) {
  fs.mkdirSync(SOURCE_DIR, { recursive: true });
  fs.writeFileSync(MODEL_ID_FILE, uid);
}

async function trySketchfabApi(uid) {
  const token = process.env.SKETCHFAB_API_TOKEN || process.env.SKETCHFAB_TOKEN;
  if (!token) {
    log('Kein SKETCHFAB_API_TOKEN — ueberspringe API-Download.');
    log('  Token holen: https://sketchfab.com/settings/password → "Generate Token"');
    log('  Dann in tools/nova-striker-import/.env eintragen (siehe .env.example)');
    return false;
  }

  log(`Sketchfab API Download (Modell ${uid})…`);
  const res = await fetch(`https://api.sketchfab.com/v3/models/${uid}/download`, {
    headers: { Authorization: `Token ${token}` },
  });
  if (!res.ok) {
    const body = await res.text();
    log(`Sketchfab API fehlgeschlagen (${res.status}): ${body.slice(0, 200)}`);
    return false;
  }

  const data = await res.json();
  const url = data?.glb?.url || data?.gltf?.url;
  if (!url) {
    log('Keine Download-URL in API-Antwort');
    return false;
  }

  const glbRes = await fetch(url);
  if (!glbRes.ok) {
    log(`GLB-Download fehlgeschlagen (${glbRes.status})`);
    return false;
  }

  fs.mkdirSync(SOURCE_DIR, { recursive: true });
  fs.writeFileSync(TARGET, Buffer.from(await glbRes.arrayBuffer()));
  writeModelId(uid);
  log('Sketchfab GLB heruntergeladen!');
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
      } else if (/\.(glb|gltf)$/i.test(e.name)) {
        if (full.includes('nova-striker-import/output')) continue;
        if (full.endsWith('assets/models/NovaStriker.glb')) continue;
        found.push(full);
      }
    }
  }

  for (const start of [
    path.join(REPO_ROOT, 'beyblade model'),
    path.join(REPO_ROOT, 'beyblade-model'),
    path.join(REPO_ROOT, 'Downloads'),
    SOURCE_DIR,
  ]) {
    if (fs.existsSync(start)) walk(start, 0);
  }

  return found[0] || null;
}

function runBuildProcedural() {
  log('Baue prozedurales Storm-Pegasus GLB…');
  const r = spawnSync(process.execPath, [path.join(__dirname, 'build-procedural-pegasus.mjs')], {
    stdio: 'inherit',
  });
  return r.status === 0 && fs.existsSync(TARGET);
}

async function main() {
  loadEnvFile();
  const uid = resolveModelUid();

  const needsRefresh = force || modelChanged(uid);
  if (fs.existsSync(TARGET) && !needsRefresh) {
    log('Quelle vorhanden:', TARGET);
    return;
  }

  if (needsRefresh && fs.existsSync(TARGET)) {
    log('Neues Modell / --force — lade neu…');
    fs.unlinkSync(TARGET);
  }

  if (await trySketchfabApi(uid)) return;

  const local = findLocalGlb();
  if (local && local !== TARGET) {
    fs.mkdirSync(SOURCE_DIR, { recursive: true });
    fs.copyFileSync(local, TARGET);
    writeModelId(uid);
    log('Lokale GLB kopiert:', local);
    return;
  }

  log('');
  log('Manueller Download (du bist eingeloggt):');
  log(`  ${DEFAULT_MODEL_URL}`);
  log('  → Download 3D Model → GLB');
  log('  → Speichern als: beyblade model/storm-pegasus.glb');
  log('  → Dann nochmal: npm run all');
  log('');

  if (!runBuildProcedural()) {
    console.error('[download] Konnte keine GLB beschaffen');
    process.exit(1);
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
