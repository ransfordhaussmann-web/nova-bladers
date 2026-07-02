#!/usr/bin/env node
/** Creates a tiny test GLB to verify simplify pipeline without Sketchfab download. */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { Document, NodeIO, Mesh, Material, Primitive, Accessor } from '@gltf-transform/core';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const out = path.join(__dirname, 'source', 'test-sphere.glb');

const doc = new Document();
const buffer = doc.createBuffer();
const mat = doc.createMaterial('M').setBaseColorFactor([0.2, 0.5, 1, 1]);
const pos = new Float32Array(3000 * 3);
const idx = new Uint16Array(3000);
for (let i = 0; i < 1000; i++) {
  const t = i / 1000 * Math.PI * 2;
  pos[i * 3] = Math.cos(t) * 2;
  pos[i * 3 + 1] = Math.sin(t) * 2;
  pos[i * 3 + 2] = (Math.random() - 0.5) * 0.5;
  idx[i] = i % 999;
}
const prim = doc.createPrimitive()
  .setMaterial(mat)
  .setAttribute('POSITION', doc.createAccessor().setType(Accessor.Type.VEC3).setArray(pos).setBuffer(buffer))
  .setIndices(doc.createAccessor().setType(Accessor.Type.SCALAR).setArray(idx).setBuffer(buffer));
const mesh = doc.createMesh('Test').addPrimitive(prim);
const node = doc.createNode('N').setMesh(mesh);
doc.createScene('S').addChild(node);

fs.mkdirSync(path.dirname(out), { recursive: true });
await new NodeIO().write(out, doc);
console.log('Test GLB:', out);
