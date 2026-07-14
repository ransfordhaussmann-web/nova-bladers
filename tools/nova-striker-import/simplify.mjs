#!/usr/bin/env node
/**
 * Simplify Storm Pegasus GLB for Roblox (~15k tris from ~763k).
 * Input:  source/storm-pegasus.glb (or any .glb/.gltf in source/)
 * Output: output/NovaStriker.glb
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { NodeIO } from '@gltf-transform/core';
import { dedup, flatten, join, weld, simplify, resample } from '@gltf-transform/functions';
import { MeshoptSimplifier } from 'meshoptimizer';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const SOURCE_DIR = path.join(__dirname, 'source');
const OUTPUT_DIR = path.join(__dirname, 'output');
const OUTPUT_FILE = path.join(OUTPUT_DIR, 'NovaStriker.glb');

const TARGET_RATIO = 0.02; // ~15k tris from 763k
const TARGET_TRIS = 18000;

function findSourceFile() {
  if (!fs.existsSync(SOURCE_DIR)) return null;
  const files = fs.readdirSync(SOURCE_DIR).filter((f) => /\.(glb|gltf)$/i.test(f));
  return files.length ? path.join(SOURCE_DIR, files[0]) : null;
}

function countTriangles(document) {
  let tris = 0;
  for (const mesh of document.getRoot().listMeshes()) {
    for (const prim of mesh.listPrimitives()) {
      const indices = prim.getIndices();
      if (indices) tris += indices.getCount() / 3;
      else {
        const pos = prim.getAttribute('POSITION');
        if (pos) tris += pos.getCount() / 3;
      }
    }
  }
  return Math.floor(tris);
}

async function main() {
  if (process.argv.includes('--info')) {
    const src = findSourceFile();
    if (!src) {
      console.log('No GLB in source/ — download from Sketchfab first.');
      process.exit(1);
    }
    const io = new NodeIO();
    const doc = await io.read(src);
    console.log('Source:', src);
    console.log('Triangles:', countTriangles(doc));
    return;
  }

  const source = findSourceFile();
  if (!source) {
    console.error('\n  No model found in tools/nova-striker-import/source/');
    console.error('  Download GLB from Sketchfab and save as:');
    console.error('    source/storm-pegasus.glb\n');
    process.exit(1);
  }

  fs.mkdirSync(OUTPUT_DIR, { recursive: true });

  console.log('Reading', path.basename(source), '…');
  const io = new NodeIO();
  const document = await io.read(source);
  const before = countTriangles(document);
  console.log('  Triangles before:', before.toLocaleString());

  const ratio = Math.min(TARGET_RATIO, TARGET_TRIS / Math.max(before, 1));
  console.log('  Simplifying (ratio', ratio.toFixed(4), ')…');

  await document.transform(
    dedup(),
    flatten(),
    join(),
    weld(),
    simplify({ simplifier: MeshoptSimplifier, ratio, error: 0.0005 }),
    resample()
  );

  const after = countTriangles(document);
  await io.write(OUTPUT_FILE, document);

  console.log('  Triangles after:', after.toLocaleString());
  console.log('\n  Saved:', OUTPUT_FILE);
  console.log('\n  Next: Roblox Studio → File → Import 3D → NovaStriker.glb');
  console.log('  Then run setup-in-studio.lua (see README)\n');
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
